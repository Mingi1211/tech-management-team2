-- =============================================================================
--  로봇학실험 1~4 부담 데이터 시드
--  광운대 기술과경영 2조 · 학업나침반
--
--  출처 : 사용자 진술 (2026-09-19) — 로봇학부 재학생 직접 확인
--  기준 : 네 과목 모두 운영 방식이 같고, 분반이 달라도 같다
--
--         · 프로젝트  15주차 팀 프로젝트, 기말고사를 대체한다
--         · 중간고사  필기 1회
--         · 과제      중간·기말 주차를 뺀 매주
--         · 퀴즈      없음
--
--  왜 폼을 안 쓰고 여기 넣나
--    전공필수라 전원이 듣고, 운영이 고정돼 있다. 선배 응답을 기다릴 이유가 없다.
--    폼으로 받으면 오히려 분반 수만큼 같은 내용이 중복으로 쌓인다.
--
--  사용법 : schema.sql → seed-robot-courses.sql → 이 파일 순서로 Run
--           여러 번 Run 해도 안전하다 (id 가 고정이라 덮어쓴다)
--
--  load_event 는 손대지 않는다. 트리거가 알아서 만든다.
-- =============================================================================

-- 과제 주차 = 2~14 중 중간고사(8주차)를 뺀 12주.
--   1주차는 OT 라 빼고(폼의 '매주'도 2주차부터다), 15주차는 프로젝트 마감이라 뺀다.
--   실험이 15·16주차에도 보고서를 받는다면 아래 배열에 주차를 더하면 된다.

insert into report (
  id, dept_code, term, course_name, professor,
  project_has, project_type, project_week,
  quiz_has, quiz_count, quiz_weeks,
  assignment_has, assignment_pattern, assignment_count, assignment_weeks_raw, assignment_weeks,
  exam_mid, exam_final, source
) values
  ('a5b00001-0000-4000-8000-000000000001', 'robot', 1, '로봇학실험1', '분반 공통',
   true, 'team', '15',
   false, 0, '{}',
   true, 'custom', 12, '{}', '{2,3,4,5,6,7,9,10,11,12,13,14}',
   1, 0, 'seed'),

  ('a5b00002-0000-4000-8000-000000000002', 'robot', 2, '로봇학실험2', '분반 공통',
   true, 'team', '15',
   false, 0, '{}',
   true, 'custom', 12, '{}', '{2,3,4,5,6,7,9,10,11,12,13,14}',
   1, 0, 'seed'),

  ('a5b00003-0000-4000-8000-000000000003', 'robot', 1, '로봇학실험3', '분반 공통',
   true, 'team', '15',
   false, 0, '{}',
   true, 'custom', 12, '{}', '{2,3,4,5,6,7,9,10,11,12,13,14}',
   1, 0, 'seed'),

  ('a5b00004-0000-4000-8000-000000000004', 'robot', 2, '로봇학실험4', '분반 공통',
   true, 'team', '15',
   false, 0, '{}',
   true, 'custom', 12, '{}', '{2,3,4,5,6,7,9,10,11,12,13,14}',
   1, 0, 'seed')

on conflict (id) do update set
  project_has          = excluded.project_has,
  project_type         = excluded.project_type,
  project_week         = excluded.project_week,
  quiz_has             = excluded.quiz_has,
  quiz_count           = excluded.quiz_count,
  quiz_weeks           = excluded.quiz_weeks,
  assignment_has       = excluded.assignment_has,
  assignment_pattern   = excluded.assignment_pattern,
  assignment_count     = excluded.assignment_count,
  assignment_weeks_raw = excluded.assignment_weeks_raw,
  assignment_weeks     = excluded.assignment_weeks,
  exam_mid             = excluded.exam_mid,
  exam_final           = excluded.exam_final,
  source               = excluded.source;


-- 마스터 과목과 연결해 둔다. 나중에 손으로 매칭할 일을 없앤다.
update report r
   set course_id = c.id
  from course c
 where c.dept_code = r.dept_code
   and c.name      = r.course_name
   and r.source    = 'seed'
   and r.course_id is distinct from c.id;


-- =============================================================================
--  확인
-- =============================================================================

-- 1) 한 과목이 만든 부담 이벤트  → 과제 12 + 중간 1 + 프로젝트 1 = 14건
select r.course_name, count(*) as 이벤트, count(*) filter (where e.kind='assignment') as 과제,
       count(*) filter (where e.kind='exam') as 시험,
       count(*) filter (where e.kind='project_due') as 프로젝트
from report r join load_event e on e.report_id = r.id
where r.source = 'seed'
group by r.course_name order by r.course_name;

-- 2) 주차별로 어떻게 보이나 (로봇학실험4)
--    8주차 = 시험 3.0,  15주차 = 프로젝트 2.5,  나머지 = 과제 1.0
select week, assignments as 과제, exams as 시험, projects as 프로젝트, load_score as 부담
from v_week_load
where course_name = '로봇학실험4'
order by week;

-- 3) 마스터와 연결됐나  → course_id 가 4건 모두 채워져 있어야 한다
select course_name, term, course_id from report where source = 'seed' order by course_name;
