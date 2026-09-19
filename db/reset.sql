-- =============================================================================
--  초기화 — 모든 테이블과 데이터를 지운다
--  광운대 기술과경영 2조 · 학업나침반
--
--  언제 쓰나
--    · schema.sql 실행 중 "relation ... already exists" 오류가 났을 때
--    · 스키마를 고쳐서 처음부터 다시 만들고 싶을 때
--
--  ⚠️ 쌓인 응답이 전부 사라진다. 선배 응답을 받기 시작한 뒤에는 쓰지 말 것.
--     (먼저 report 테이블을 CSV 로 내보내 두면 나중에 되돌릴 수 있다)
--
--  사용법 : Supabase → SQL Editor → 이 파일을 Run → 그다음 schema.sql 을 Run
-- =============================================================================

drop view     if exists v_week_load;
drop view     if exists v_course_confidence;

drop table    if exists load_event    cascade;
drop table    if exists report        cascade;
drop table    if exists track_course  cascade;
drop table    if exists track         cascade;
drop table    if exists prerequisite  cascade;
drop table    if exists course        cascade;
drop table    if exists department    cascade;

drop function if exists build_load_events() cascade;
drop function if exists week_of(text)       cascade;

-- 확인 : 아래가 0 줄이어야 깨끗이 지워진 것이다
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('department','course','prerequisite','track','track_course',
                     'report','load_event');
