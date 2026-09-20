-- =============================================================================
--  응답 점검 — 잘못 들어간 것 찾기
--  광운대 기술과경영 2조 · 학업나침반
--
--  입력 폼은 과목명을 자유 입력으로 받는다. 팀원이 Supabase 의 course 목록을 보고
--  직접 적는 방식이라, 막는 대신 **들어온 뒤에 찾아서 고친다.**
--
--  사용법 : Supabase → SQL Editor → 필요한 블록만 골라 Run
--  권장   : 주 1회, 그리고 발표 전 한 번
--
--  0번은 "아직 안 채운 과목" 을 뽑는다 — 입력 진행률을 볼 때 이것만 돌리면 된다.
--  1~4번은 "잘못 들어온 응답" 을 뽑는다.
-- =============================================================================


-- ── 0. 수집 현황 — 아직 안 채운 과목 찾기 ───────────────────────────────────

-- (a) 학부·학기별 커버리지
select d.name as 학부, c.typical_term as 학기,
       count(*) as 과목,
       count(*) filter (where x.건수 > 0) as 응답있음,
       count(*) filter (where x.건수 = 0) as 응답없음,
       round(100.0 * count(*) filter (where x.건수 > 0) / count(*)) as 퍼센트
from course c
join department d on d.code = c.dept_code
cross join lateral (
  select count(*) as 건수 from report r
   where r.dept_code = c.dept_code and r.course_name = c.name
) x
group by 1, 2 order by 1, 2;

-- (b) **아직 응답이 0건인 과목** — 이게 "정량 정보 남은 목록"이다.
--     전공필수부터, 저학년부터 채우는 순서로 나온다.
select d.name as 학부, c.course_type as 구분,
       c.typical_year as 학년, c.typical_term as 학기,
       c.name as 과목, array_to_string(c.professors, ', ') as 담당교수
from course c
join department d on d.code = c.dept_code
where not exists (
  select 1 from report r
   where r.dept_code = c.dept_code and r.course_name = c.name
)
order by (c.course_type = '전공필수') desc, c.typical_year, c.typical_term, d.name, c.name;

-- (c) 응답은 있는데 부족한 과목 — 3건 이상이어야 신뢰도 A
select d.name as 학부, c.name as 과목, x.건수,
       case when x.건수 >= 3 then 'A' else 'B' end as 신뢰도
from course c
join department d on d.code = c.dept_code
cross join lateral (
  select count(*) as 건수 from report r
   where r.dept_code = c.dept_code and r.course_name = c.name
) x
where x.건수 between 1 and 2
order by x.건수, d.name, c.name;


-- ── 1. 마스터에 없는 과목명 ──────────────────────────────────────────────────
--  오타이거나, 마스터에 아직 없는 과목(전공필수 등)이다. 제일 먼저 볼 것.

select r.dept_code, r.term, r.course_name, r.professor, count(*) as 건수
from report r
where not exists (
  select 1 from course c
  where c.dept_code = r.dept_code and c.name = r.course_name
)
group by 1,2,3,4
order by 건수 desc, r.course_name;


-- ── 2. 표기만 다른 같은 과목 ────────────────────────────────────────────────
--  공백·로마숫자·대소문자를 지우고 비교한다. '자동제어1' 과 '자동제어 I' 를 잡는다.

--  로마숫자는 **끝자리에서만** 바꾼다. 'AI수학' 의 I 까지 건드리면 안 되기 때문이다.
with norm as (
  select id, dept_code, course_name,
         case
           when s ~ '(ⅳ|iv)$'  then regexp_replace(s, '(ⅳ|iv)$',  '4')
           when s ~ '(ⅲ|iii)$' then regexp_replace(s, '(ⅲ|iii)$', '3')
           when s ~ '(ⅱ|ii)$'  then regexp_replace(s, '(ⅱ|ii)$',  '2')
           when s ~ '(ⅰ|i)$'   then regexp_replace(s, '(ⅰ|i)$',   '1')
           else s
         end as key
  from (select id, dept_code, course_name,
               lower(replace(course_name, ' ', '')) as s
        from report) x
)
select dept_code, key as 정규화, array_agg(distinct course_name) as 실제표기, count(*) as 건수
from norm
group by 1,2
having count(distinct course_name) > 1
order by 건수 desc;


-- ── 3. 중복 제출 의심 ───────────────────────────────────────────────────────
--  같은 과목·교수에 여러 건은 정상이다(여러 선배가 답한 것).
--  단 **내용까지 똑같고 시간 간격이 짧으면** 같은 사람이 두 번 낸 것일 수 있다.

select course_name, professor, count(*) as 건수,
       min(created_at) as 처음, max(created_at) as 마지막,
       max(created_at) - min(created_at) as 간격
from report
group by course_name, professor, project_has, project_week, quiz_count,
         assignment_pattern, assignment_count, exam_mid, exam_final
having count(*) > 1
order by 간격;


-- ── 4. 이상치 ───────────────────────────────────────────────────────────────

-- (a) 과제가 있다는데 주차가 하나도 안 잡힌 응답
select id, course_name, professor, assignment_pattern, assignment_count, assignment_weeks
from report
where assignment_has and cardinality(assignment_weeks) = 0;

-- (b) 신고한 횟수와 실제 주차 수가 다른 응답
select id, course_name, assignment_count as 신고, cardinality(assignment_weeks) as 실제
from report
where assignment_has and assignment_count <> cardinality(assignment_weeks);

-- (c) 과제 주차가 한 주에 몰린 응답 (10회인데 서로 다른 주차가 2개 이하)
select id, course_name, assignment_count, assignment_weeks
from report
where assignment_has and assignment_count >= 5
  and cardinality(array(select distinct unnest(assignment_weeks))) <= 2;

-- (d) 프로젝트가 있다는데 시점을 모른다고 답한 응답 → load_event 가 안 생긴다
select id, course_name, professor, project_type, project_week
from report
where project_has and (project_week is null or project_week = 'unknown');

-- (e) 마스터와 학기가 다른 응답 → 과목명이나 학기 중 하나가 틀렸다
select r.id, r.course_name, r.term as 입력학기, c.typical_term as 마스터학기
from report r
join course c on c.dept_code = r.dept_code and c.name = r.course_name
where c.typical_term in (1, 2) and c.typical_term <> r.term;

-- (f) 부담 이벤트가 하나도 안 생긴 응답 → 사실상 빈 응답
select r.id, r.course_name, r.professor, r.created_at
from report r
where not exists (select 1 from load_event e where e.report_id = r.id)
order by r.created_at desc;


-- ── 5. 마스터 연결 상태 ─────────────────────────────────────────────────────

select count(*) filter (where course_id is not null) as 연결됨,
       count(*) filter (where course_id is null)     as 미연결,
       count(*) as 전체
from report;


-- =============================================================================
--  고치기
-- =============================================================================

-- (A) 오타 하나 고치기 — 고치면 트리거가 load_event 를 다시 만든다
-- update report set course_name = '자동제어1'
--  where dept_code = 'robot' and course_name = '자동제어 I';

-- (B) 잘못 들어간 응답 하나 지우기 — load_event 도 함께 지워진다
-- delete from report where id = '여기에-UUID';

-- (C) 마스터와 연결하기 — 1·2번을 고친 뒤에 돌린다
update report r
   set course_id = c.id
  from course c
 where c.dept_code = r.dept_code
   and c.name      = r.course_name
   and r.course_id is distinct from c.id;
