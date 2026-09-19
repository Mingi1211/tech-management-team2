-- =============================================================================
--  학업나침반 — Supabase(PostgreSQL) 스키마
--  광운대 기술과경영 2조
--
--  사용법 : Supabase 대시보드 → SQL Editor → 이 파일 전체를 붙여넣고 Run (1회)
--
--  "relation ... already exists" 오류가 나면 이미 한 번 실행된 것이다.
--  db/reset.sql 을 먼저 Run 해서 전부 지운 뒤, 이 파일을 다시 Run 한다.
--  (쌓인 응답도 함께 사라지므로, 수집을 시작한 뒤에는 reset 을 쓰지 말 것)
--
--  테이블은 두 종류다. 채우는 방법이 다르니 구분해 둘 것.
--    [참조]  department · course · prerequisite · track · track_course
--            → 우리가 교과과정표를 보고 CSV 로 import 한다
--    [수집]  report · load_event
--            → 선배가 입력 폼에서 제출하면 자동으로 쌓인다. 손으로 넣지 않는다
-- =============================================================================


-- =============================================================================
--  0. 학기 기준 상수
--     "중간고사 무렵" / "기말고사 무렵" 을 몇 주차로 볼 것인가.
--     학사일정이 바뀌면 week_of() 함수 한 곳만 고치면 된다.
-- =============================================================================
--    중간고사 = 8주차,  기말고사 = 15주차,  학기 = 16주


-- =============================================================================
--  1. 참조 테이블 — 우리가 채운다
-- =============================================================================

create table department (
  code        text primary key,          -- 'robot' | 'infoconv' | 'software'
  name        text not null unique
);

insert into department (code, name) values
  ('robot',    '로봇학부'),
  ('infoconv', '정보융합학부'),
  ('software', '소프트웨어학부')
on conflict (code) do nothing;


create table course (
  id            bigserial primary key,
  dept_code     text    not null references department(code),
  code          text,                    -- 학수번호. 참고용이라 비워도 된다
  name          text    not null,
  credits       smallint,
  course_type   text    check (course_type in ('전공필수','전공선택','기초','교양')),
  typical_year  smallint check (typical_year between 1 and 4),
  typical_term  smallint check (typical_term in (0, 1, 2)),   -- 0 = 매학기 개설
  professors    text[]  not null default '{}',   -- 담당 교수. 분반이 여럿이면 여럿
  note          text,
  unique (dept_code, name)
);

comment on column course.typical_term is '0=매학기, 1=1학기, 2=2학기. 로드맵이 학기를 배치할 때 쓴다';
comment on column course.professors  is
  '입력 폼이 "과목 → 교수" 선택지를 만들 때 쓴다. 자유 입력을 없애는 것이 목적이므로 '
  '교수명 표기도 여기 있는 값이 정본이다. 분반이 여럿이면 배열에 모두 넣는다';
comment on column course.code is
  '학수번호 I050-학년-과목번호. 두 번째 자리가 개설학년이라 typical_year 를 여기서 얻는다. 검색에는 쓰지 않는다';


-- 선수과목 관계. hard = true 면 반드시 먼저 들어야 하는 과목
create table prerequisite (
  course_id   bigint not null references course(id) on delete cascade,
  requires_id bigint not null references course(id) on delete cascade,
  hard        boolean not null default true,
  primary key (course_id, requires_id),
  check (course_id <> requires_id)
);


-- 관심분야 트랙 (로봇학부 = 제어 · 비전 · 인지/AI · 임베디드 …)
create table track (
  id          bigserial primary key,
  dept_code   text not null references department(code),
  name        text not null,
  description text,
  unique (dept_code, name)
);

-- 트랙에 속한 과목과 비중. weight 3 = 핵심, 2 = 권장, 1 = 보조
create table track_course (
  track_id  bigint   not null references track(id) on delete cascade,
  course_id bigint   not null references course(id) on delete cascade,
  weight    smallint not null default 1 check (weight between 1 and 3),
  primary key (track_id, course_id)
);


-- =============================================================================
--  2. 수집 테이블 — 입력 폼이 채운다
-- =============================================================================

create table report (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),

  -- 과목 정보 (선배가 직접 입력하므로 마스터와 철자가 다를 수 있다.
  --            나중에 매칭해 course_id 를 채우되, 비어 있어도 데이터는 유효하다)
  dept_code     text     not null references department(code),
  term          smallint not null check (term in (1, 2)),
  course_name   text     not null,
  professor     text     not null,
  course_id     bigint   references course(id),

  -- 프로젝트
  project_has   boolean  not null default false,
  project_type  text     check (project_type in ('team','individual')),
  project_week  text,            -- '1'~'15' | 'mid' | 'final' | 'unknown'

  -- 퀴즈
  quiz_has      boolean  not null default false,
  quiz_count    smallint not null default 0,
  quiz_weeks    text[]   not null default '{}',   -- 회차 순서대로. 폼의 선택 원본

  -- 과제
  assignment_has        boolean  not null default false,
  assignment_pattern    text     check (assignment_pattern in
                                  ('weekly','biweekly','exam_only','custom')),
  assignment_count      smallint not null default 0,
  assignment_weeks_raw  text[]   not null default '{}',  -- '직접 고르기' 일 때의 원본
  assignment_weeks      smallint[] not null default '{}',-- 주기에서 계산된 실제 주차

  -- 시험 (같은 시험을 코딩테스트 + 필기로 나눠 두 번 보는 과목이 있어 0~2 를 받는다)
  exam_mid      smallint not null default 0 check (exam_mid   between 0 and 2),
  exam_final    smallint not null default 0 check (exam_final between 0 and 2),

  -- 출처. 'form' = 선배 제출, 'prototype' = 아티팩트 프로토타입에서 이사, 'seed' = 팀원 시드
  source        text     not null default 'form'
                         check (source in ('form','prototype','seed')),

  course_key    text generated always as
                  (dept_code || '|' || term::text || '|' || course_name || '|' || professor)
                  stored
);

comment on column report.quiz_weeks is
  '"mid" · "final" · "unknown" 같은 원본 토큰을 그대로 보관한다. '
  '"unknown" 이 몇 건인지 세어 응답 품질을 평가하기 위해서다. 계산에는 load_event 를 쓴다';

create index report_course_key_idx on report (course_key);
create index report_dept_idx       on report (dept_code, term);
create index report_created_idx    on report (created_at desc);


-- 주차 단위로 펼친 부담 이벤트. 이 테이블이 부담 계산의 전부다.
-- report 가 들어오면 트리거가 자동으로 만든다 — 직접 INSERT 하지 말 것.
create table load_event (
  id         bigserial primary key,
  report_id  uuid     not null references report(id) on delete cascade,
  week       smallint not null check (week between 1 and 16),
  kind       text     not null check (kind in
               ('exam','project_due','quiz','assignment','presentation'))
);

create index load_event_report_idx on load_event (report_id);
create index load_event_week_idx    on load_event (week, kind);


-- =============================================================================
--  3. 주차 변환 + 자동 정규화
-- =============================================================================

-- 폼이 저장한 토큰을 주차 숫자로 바꾼다. 'unknown' 과 빈 값은 NULL → 이벤트를 만들지 않는다.
create or replace function week_of(token text)
returns smallint
language sql
immutable
as $$
  select case
           when token is null            then null
           when token = 'mid'            then 8::smallint    -- 중간고사
           when token = 'final'          then 15::smallint   -- 기말고사
           when token ~ '^[0-9]{1,2}$'   then token::smallint
           else null                                          -- 'unknown' 등
         end;
$$;


-- report 한 줄 → load_event 여러 줄.
-- security definer 로 두어 RLS 가 걸린 load_event 에도 쓸 수 있게 한다.
create or replace function build_load_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  w   smallint;
  tok text;
  i   smallint;
begin
  delete from load_event where report_id = new.id;   -- 수정 시 다시 만든다

  if new.project_has then
    w := week_of(new.project_week);
    if w is not null then
      insert into load_event (report_id, week, kind) values (new.id, w, 'project_due');
    end if;
  end if;

  if new.quiz_has then
    foreach tok in array new.quiz_weeks loop
      w := week_of(tok);
      if w is not null then
        insert into load_event (report_id, week, kind) values (new.id, w, 'quiz');
      end if;
    end loop;
  end if;

  if new.assignment_has then
    foreach w in array new.assignment_weeks loop
      if w between 1 and 16 then
        insert into load_event (report_id, week, kind) values (new.id, w, 'assignment');
      end if;
    end loop;
  end if;

  for i in 1 .. new.exam_mid loop
    insert into load_event (report_id, week, kind) values (new.id, 8, 'exam');
  end loop;

  for i in 1 .. new.exam_final loop
    insert into load_event (report_id, week, kind) values (new.id, 15, 'exam');
  end loop;

  return new;
end;
$$;

create trigger report_build_load_events
  after insert or update on report
  for each row execute function build_load_events();


-- =============================================================================
--  4. 집계 뷰 — 진단 기능이 읽는다
--     원본 응답(report)은 감추고 이 뷰만 공개한다.
-- =============================================================================

create or replace view v_week_load as
select
  r.course_key,
  r.dept_code,
  r.term,
  r.course_name,
  r.professor,
  e.week,
  count(distinct r.id)                                   as report_count,
  -- 아래 값은 모두 "응답 1건당 평균" 이다. load_score 와 단위를 맞춘다.
  round(count(*) filter (where e.kind = 'exam')::numeric
        / count(distinct r.id), 2)                       as exams,
  round(count(*) filter (where e.kind = 'project_due')::numeric
        / count(distinct r.id), 2)                       as projects,
  round(count(*) filter (where e.kind = 'quiz')::numeric
        / count(distinct r.id), 2)                       as quizzes,
  round(count(*) filter (where e.kind = 'assignment')::numeric
        / count(distinct r.id), 2)                       as assignments,
  round(
    sum(case e.kind
          when 'exam'         then 3.0
          when 'project_due'  then 2.5
          when 'presentation' then 2.0
          when 'quiz'         then 1.2
          else 1.0
        end)::numeric / count(distinct r.id), 2)         as load_score
from report r
join load_event e on e.report_id = r.id
group by r.course_key, r.dept_code, r.term, r.course_name, r.professor, e.week;

comment on view v_week_load is
  '과목별 · 주차별 평균 부담. 모든 수치는 응답 1건당 평균이다. load_score 가중치는 설계 계획서 §5.1 초안이며 검증 후 보정한다';


-- 응답이 몇 건 모였는지와 신뢰도 등급
create or replace view v_course_confidence as
select
  course_key, dept_code, term, course_name, professor,
  count(*) as report_count,
  case when count(*) >= 3 then 'A'
       when count(*) >= 1 then 'B'
       else 'C' end as confidence
from report
group by course_key, dept_code, term, course_name, professor;


-- =============================================================================
--  5. 접근 권한 (RLS) — 반드시 켠 채로 둘 것
--
--  Supabase 는 anon key 를 브라우저에 노출한 채 동작한다. RLS 를 끄면
--  그 키만으로 누구나 전체 테이블을 읽고 고칠 수 있다.
--
--  원칙 : 선배는 "넣을 수만" 있고, 남의 응답을 읽지 못한다.
--         팀은 Supabase Studio / DBeaver 로 (service_role) 전부 본다.
-- =============================================================================

alter table report      enable row level security;
alter table load_event  enable row level security;
alter table course      enable row level security;
alter table prerequisite enable row level security;
alter table track       enable row level security;
alter table track_course enable row level security;
alter table department  enable row level security;

-- 응답 제출은 누구나. 읽기 정책은 만들지 않는다 → anon 은 select 불가.
create policy report_insert_anyone on report
  for insert to anon, authenticated with check (true);

-- 참조 데이터는 누구나 읽기만. 수정은 service_role(Studio/DBeaver)만.
create policy department_read   on department   for select to anon, authenticated using (true);
create policy course_read       on course       for select to anon, authenticated using (true);
create policy prerequisite_read on prerequisite for select to anon, authenticated using (true);
create policy track_read        on track        for select to anon, authenticated using (true);
create policy track_course_read on track_course for select to anon, authenticated using (true);

-- load_event 에는 정책을 두지 않는다 → anon 접근 불가.
-- 트리거는 security definer 라 그대로 쓴다.

-- 테이블 권한. Supabase 는 public 스키마에 기본 권한이 걸려 있어 대개 이미 적용돼 있지만,
-- 명시해 두면 이 파일만으로 어디서든 같은 상태가 된다. 실제 접근은 위 RLS 정책이 결정한다.
grant usage on schema public to anon, authenticated;
grant insert on report to anon, authenticated;
grant select on department, course, prerequisite, track, track_course
  to anon, authenticated;

-- 뷰는 소유자 권한으로 실행되므로 아래 grant 만으로 집계가 공개된다.
grant select on v_week_load, v_course_confidence to anon, authenticated;

-- ⚠️ report 에 SELECT 정책을 만들지 않는 이유 (의도된 것이다)
--    선배가 남의 응답을 읽을 이유가 없기 때문이다. 다만 그 결과로
--    INSERT ... RETURNING 이 거부된다 — PostgreSQL 은 RETURNING 에 SELECT 를 요구한다.
--    그래서 앱은 id 를 직접 만들어 보내고 Prefer: return=minimal 로 저장한다.
--    (app/api/reports/route.ts 참고)


-- =============================================================================
--  6. 트랙 예시 — 로봇학부
--     과목 매핑(track_course)은 교과과정표를 확인한 뒤 DB 담당이 채운다.
-- =============================================================================

insert into track (dept_code, name, description) values
  ('robot', '제어',      '제어 이론과 로봇 동역학 중심'),
  ('robot', '비전',      '영상 처리와 인식 중심'),
  ('robot', '인지 · AI', '학습 기반 판단과 지능 시스템 중심'),
  ('robot', '임베디드',  '마이크로프로세서와 실시간 시스템 중심')
on conflict (dept_code, name) do nothing;


-- =============================================================================
--  7. 동작 확인 — 실행 후 아래를 돌려 보면 파이프라인 전체가 검증된다
-- =============================================================================
/*
-- (1) 응답 한 건을 넣는다  — 아티팩트 프로토타입에 실제로 들어갔던 형태
insert into report (dept_code, term, course_name, professor,
                    project_has, project_type, project_week,
                    quiz_has, quiz_count, quiz_weeks,
                    exam_mid, exam_final, source)
values ('robot', 1, '자동제어1', '백주훈',
        true, 'individual', '15',
        true, 2, array['5','12'],
        1, 1, 'seed');

-- (2) load_event 가 자동으로 5건 생겼는지 본다
--     15:project_due · 5:quiz · 12:quiz · 8:exam · 15:exam
select week, kind from load_event order by week, kind;

-- (3) 집계 뷰를 본다
select * from v_week_load order by week;

-- (4) 확인이 끝나면 지운다 (load_event 도 cascade 로 함께 지워진다)
delete from report where source = 'seed';
*/


-- =============================================================================
--  전부 지우고 다시 만들려면 db/reset.sql 을 먼저 실행한다
-- =============================================================================
