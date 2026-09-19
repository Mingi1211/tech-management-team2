-- =============================================================================
--  확인 — 제출이 제대로 저장됐는지 본다
--  Supabase → SQL Editor 에 붙여넣고 Run
--
--  왜 SQL Editor 인가
--    report 에는 SELECT 정책이 없다 (선배가 남의 응답을 읽지 못하게 한 것).
--    그래서 앱이나 anon key 로는 조회되지 않는다. 팀은 여기서 본다.
-- =============================================================================

-- 1. 얼마나 쌓였나
select count(*) as 응답수,
       count(*) filter (where source = 'form')      as 폼제출,
       count(*) filter (where source = 'seed')      as 시드,
       max(created_at)                              as 마지막제출
from report;


-- 2. 최근 응답 5건
select created_at, dept_code, term, course_name, professor,
       project_has, project_type, project_week,
       quiz_has, quiz_count, quiz_weeks,
       assignment_has, assignment_pattern, assignment_weeks,
       exam_mid, exam_final, source
from report
order by created_at desc
limit 5;


-- 3. ★ 가장 중요 — 트리거가 주차 이벤트를 만들었는가
--    여기가 비어 있으면 저장은 됐지만 부담 계산이 안 된다는 뜻이다.
select r.course_name, r.professor, e.week, e.kind
from report r
join load_event e on e.report_id = r.id
order by r.created_at desc, e.week, e.kind;


-- 4. 응답이 하나도 이벤트를 못 만든 경우 (있으면 확인 필요)
--    단, 프로젝트·퀴즈·과제·시험이 전부 '없음' 인 과목이면 정상이다.
select id, course_name, professor, created_at
from report r
where not exists (select 1 from load_event e where e.report_id = r.id);


-- 5. 집계 뷰 — 진단 기능이 실제로 읽게 될 모양
select course_name, professor, week, report_count,
       exams, quizzes, assignments, projects, load_score
from v_week_load
order by course_name, week;


-- 6. 확인용으로 넣은 줄 지우기 (load_event 도 함께 지워진다)
--    course_name 을 실제로 넣은 값으로 바꿔서 실행할 것
-- delete from report where course_name = '테스트';
