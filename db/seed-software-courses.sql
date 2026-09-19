-- =============================================================================
--  소프트웨어학부 교과과정 시드
--  광운대 기술과경영 2조 · 학업나침반
--
--  출처 : 수강신청 자료집 개설과목 목록 (2026학년도) — 사용자 제공 화면
--  기준 : 2026-09-19 · 학수번호 접두사 I030
--
--  🚧 **작성 중.** 지금은 1학기 앞부분(운영체제까지)만 들어 있다.
--     나머지 화면을 받는 대로 아래 표에 이어 붙인다. 같은 과목이면 덮어쓰므로
--     여러 번 Run 해도 안전하고, 중간에 한 번 Run 해 둬도 문제없다.
--
--  ⚠️ 화면에 **전공선택만** 있었다. 전공필수는 목록 윗부분이 잘려 보이지 않았다.
-- =============================================================================

alter table course add column if not exists professors text[] not null default '{}';

insert into course (dept_code, code, name, credits, course_type, typical_year, typical_term, professors, note) values

-- ── 1학기 ────────────────────────────────────────────────────────────────────
  ('software','I030-1-8998','소프트웨어입문세미나',     1,'전공선택',1,1, '{문승현}', null),
  ('software','I030-2-0448','디지털논리',               3,'전공선택',2,1, '{정승권,송원선}', '2개 분반 · 분반별 교수 다름'),
  ('software','I030-2-3403','고급프로그래밍',           3,'전공선택',2,1, '{최영근}', '2개 분반'),
  ('software','I030-2-5409','웹프로그래밍',             3,'전공선택',2,1, '{김우생}', null),
  ('software','I030-2-5952','파이썬기반인공지능기초',   3,'전공선택',2,1, '{김종국}', null),
  ('software','I030-2-8484','리눅스활용실습',           2,'전공선택',2,1, '{김용혁,전원호}', '2학점 3시간 · 3개 분반'),
  ('software','I030-3-0969','알고리즘',                 3,'전공선택',3,1, '{박병준,김용혁}', '2개 분반 · 분반별 교수 다름'),
  ('software','I030-3-1110','운영체제',                 3,'전공선택',3,1, '{안우현}', '2개 분반')

-- ── 여기서부터 이어 붙일 것 ──────────────────────────────────────────────────
-- 1학기 나머지 · 2학기 전체.  위 줄 끝의 쉼표를 살리고 같은 형식으로 추가한다.
--   ('software','I030-?-????','과목명', 학점,'전공선택', 학년, 학기, '{교수}', 비고),

on conflict (dept_code, name) do update set
  code         = excluded.code,
  credits      = excluded.credits,
  course_type  = excluded.course_type,
  typical_year = excluded.typical_year,
  typical_term = excluded.typical_term,
  professors   = excluded.professors,
  note         = excluded.note;


-- 확인
select typical_term as 학기, count(*) as 과목수
from course where dept_code = 'software' group by 1 order by 1;
