-- =============================================================================
--  관심분야 트랙 · 과목 매핑
--  광운대 기술과경영 2조 · 학업나침반
--
--  ⚠️ **[초안]** 이 분류는 학과 공식 이수체계가 아니다.
--     과목명과 교과과정 배치를 보고 만든 1차안이며, 학과 자료·교수·선배 검토로
--     확정해야 한다. 아래 표만 고치면 되고 코드는 건드릴 일이 없다.
--
--  사용법 : schema.sql → seed-*-courses.sql 3개 → 이 파일 순서로 Run
--           여러 번 Run 해도 안전하다.
--
--  weight  3 = 핵심 (이 트랙이면 반드시)
--          2 = 권장
--          1 = 보조 (있으면 좋음)
--
--  한 과목이 여러 트랙에 들어가도 된다. 컴퓨터비전은 비전이면서 인지·AI 다.
--  트랙에 안 들어가는 과목도 있다 — 캡스톤·세미나·진로 과목·전공필수 실험.
--  로드맵은 "트랙 점수 높은 순 + 선수과목 위상정렬" 로 학기를 채운다.
-- =============================================================================

-- ── 트랙 정의 ────────────────────────────────────────────────────────────────
-- 로봇학부 4트랙은 schema.sql 에 이미 있다. 나머지 두 학부를 여기서 만든다.

insert into track (dept_code, name, description) values
  ('infoconv', '데이터 · AI',    '학습 모델과 데이터 분석 중심'),
  ('infoconv', '비주얼 · XR',    '그래픽스 · 영상 · 확장현실 중심'),
  ('infoconv', 'HCI · UX',       '사용자 경험 설계와 평가 중심'),
  ('infoconv', '소프트웨어 기반','프로그래밍 · 자료구조 · 응용 개발 중심'),
  ('software', 'AI · 데이터',    '인공지능과 대용량 데이터 처리 중심'),
  ('software', '시스템 · 네트워크','운영체제 · 통신 · 하드웨어 계층 중심'),
  ('software', '소프트웨어 공학','언어 · 설계 · 구현 방법론 중심'),
  ('software', '그래픽스 · XR',  '렌더링 · 애니메이션 · 혼합현실 중심')
on conflict (dept_code, name) do nothing;


-- ── 과목 매핑 ────────────────────────────────────────────────────────────────
-- 고칠 때는 아래 (학부, 트랙, 과목명, 비중) 네 칸만 손대면 된다.
-- 과목명이 course 에 없으면 그 줄은 조용히 무시된다 → 맨 아래 확인 쿼리 2번으로 잡는다.

insert into track_course (track_id, course_id, weight)
select t.id, c.id, m.weight
from (values

  -- ═══ 로봇학부 ═══════════════════════════════════════════════════════════
  ('robot','제어','자동제어1',3),        ('robot','제어','자동제어2',3),
  ('robot','제어','로봇제어',3),         ('robot','제어','로봇운동학',3),
  ('robot','제어','모터제어',3),         ('robot','제어','메카니즘해석',2),
  ('robot','제어','기초역학',2),         ('robot','제어','신호및시스템',2),
  ('robot','제어','로봇응용시스템',2),   ('robot','제어','강화학습',1),

  ('robot','비전','컴퓨터비전',3),       ('robot','비전','로봇내비게이션',2),
  ('robot','비전','피지컬AI',1),         ('robot','비전','기계학습',1),

  ('robot','인지 · AI','기계학습',3),    ('robot','인지 · AI','강화학습',3),
  ('robot','인지 · AI','피지컬AI',3),    ('robot','인지 · AI','온디바이스인공지능',2),
  ('robot','인지 · AI','컴퓨터비전',2),  ('robot','인지 · AI','로봇내비게이션',2),
  ('robot','인지 · AI','알고리즘',1),

  ('robot','임베디드','마이크로프로세서',3), ('robot','임베디드','임베디드시스템',3),
  ('robot','임베디드','디지털공학',3),       ('robot','임베디드','회로이론1',2),
  ('robot','임베디드','회로이론2',2),        ('robot','임베디드','전자회로',2),
  ('robot','임베디드','컴퓨터구조',2),       ('robot','임베디드','온디바이스인공지능',2),
  ('robot','임베디드','전자기학',1),         ('robot','임베디드','모터제어',1),

  -- ═══ 정보융합학부 ═══════════════════════════════════════════════════════
  ('infoconv','데이터 · AI','기계학습',3),        ('infoconv','데이터 · AI','딥러닝프로그래밍',3),
  ('infoconv','데이터 · AI','데이터마이닝',3),    ('infoconv','데이터 · AI','인공지능응용',3),
  ('infoconv','데이터 · AI','MLOps엔지니어링',3), ('infoconv','데이터 · AI','텍스트마이닝',2),
  ('infoconv','데이터 · AI','네트워크데이터분석',2), ('infoconv','데이터 · AI','빅데이터프로그래밍',2),
  ('infoconv','데이터 · AI','AI수학',2),          ('infoconv','데이터 · AI','선형대수',2),
  ('infoconv','데이터 · AI','데이터시각화',2),    ('infoconv','데이터 · AI','Physical AI 실습',2),
  ('infoconv','데이터 · AI','데이터베이스',1),

  ('infoconv','비주얼 · XR','컴퓨터그래픽스',3),  ('infoconv','비주얼 · XR','비주얼컴퓨팅',3),
  ('infoconv','비주얼 · XR','확장현실',3),        ('infoconv','비주얼 · XR','영상AI생성모델',3),
  ('infoconv','비주얼 · XR','컴퓨터비전',2),      ('infoconv','비주얼 · XR','그래픽디자인',2),

  ('infoconv','HCI · UX','UX/UI디자인',3),        ('infoconv','HCI · UX','HCI와UX평가',3),
  ('infoconv','HCI · UX','인터랙티브심리학',3),   ('infoconv','HCI · UX','그래픽디자인',2),
  ('infoconv','HCI · UX','모바일프로그래밍',1),

  ('infoconv','소프트웨어 기반','객체지향프로그래밍',3), ('infoconv','소프트웨어 기반','자료구조',3),
  ('infoconv','소프트웨어 기반','오픈소스소프트웨어실습',2), ('infoconv','소프트웨어 기반','모바일프로그래밍',2),
  ('infoconv','소프트웨어 기반','데이터베이스',2),  ('infoconv','소프트웨어 기반','빅데이터프로그래밍',1),

  -- ═══ 소프트웨어학부 ═════════════════════════════════════════════════════
  ('software','AI · 데이터','인공지능',3),        ('software','AI · 데이터','기계학습',3),
  ('software','AI · 데이터','딥러닝실습',3),      ('software','AI · 데이터','빅데이터처리및응용',3),
  ('software','AI · 데이터','파이썬기반인공지능기초',2), ('software','AI · 데이터','데이터베이스',2),
  ('software','AI · 데이터','알고리즘',2),        ('software','AI · 데이터','정보시스템응용',1),

  ('software','시스템 · 네트워크','운영체제',3),  ('software','시스템 · 네트워크','시스템소프트웨어',3),
  ('software','시스템 · 네트워크','컴퓨터네트워크',3), ('software','시스템 · 네트워크','데이터통신',3),
  ('software','시스템 · 네트워크','무선네트워크',3),   ('software','시스템 · 네트워크','컴퓨터구조',2),
  ('software','시스템 · 네트워크','디지털논리',2),     ('software','시스템 · 네트워크','리눅스활용실습',2),

  ('software','소프트웨어 공학','소프트웨어공학',3),   ('software','소프트웨어 공학','프로그래밍언어론',3),
  ('software','소프트웨어 공학','객체지향프로그래밍',3),('software','소프트웨어 공학','자료구조',3),
  ('software','소프트웨어 공학','알고리즘',3),         ('software','소프트웨어 공학','자료구조실습',2),
  ('software','소프트웨어 공학','고급프로그래밍',2),   ('software','소프트웨어 공학','고급C프로그래밍및설계',2),
  ('software','소프트웨어 공학','웹프로그래밍',2),     ('software','소프트웨어 공학','오픈소스소프트웨어개발',2),
  ('software','소프트웨어 공학','응용소프트웨어실습',2),('software','소프트웨어 공학','심화전공실습',2),

  ('software','그래픽스 · XR','컴퓨터그래픽스',3),     ('software','그래픽스 · XR','컴퓨터애니메이션',3),
  ('software','그래픽스 · XR','컴퓨터애니메이션실습',3),('software','그래픽스 · XR','혼합현실',3)

) as m(dept, track, course, weight)
join track  t on t.dept_code = m.dept and t.name = m.track
join course c on c.dept_code = m.dept and c.name = m.course
on conflict (track_id, course_id) do update set weight = excluded.weight;


-- =============================================================================
--  확인
-- =============================================================================

-- 1) 트랙별 과목 수
select d.name as 학부, t.name as 트랙,
       count(*) filter (where tc.weight = 3) as 핵심,
       count(*) filter (where tc.weight = 2) as 권장,
       count(*) filter (where tc.weight = 1) as 보조
from track t
join department d on d.code = t.dept_code
left join track_course tc on tc.track_id = t.id
group by d.name, t.name order by d.name, t.name;

-- 2) 어느 트랙에도 안 들어간 과목  → 캡스톤·세미나·진로·실험이면 정상
select d.name as 학부, c.name as 과목, c.course_type as 구분
from course c
join department d on d.code = c.dept_code
where not exists (select 1 from track_course tc where tc.course_id = c.id)
order by d.name, c.name;
