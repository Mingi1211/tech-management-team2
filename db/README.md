# db — Supabase 스키마

## 적용 방법 (1회)

1. <https://supabase.com> 에서 프로젝트 생성 (무료 티어)
2. 대시보드 → **SQL Editor** → `schema.sql` 전체를 붙여넣고 **Run**
3. **Table Editor** 에서 테이블 7개가 생겼는지 확인

다시 만들려면 `schema.sql` 맨 아래 "초기화" 블록의 주석을 풀어 먼저 실행한다.

## 테이블은 두 종류

| | 테이블 | 채우는 방법 |
|---|---|---|
| **참조** | `department` `course` `prerequisite` `track` `track_course` | 교과과정표를 보고 **우리가 CSV import** |
| **수집** | `report` `load_event` | 선배가 폼에서 제출 → **자동으로 쌓임.** 손으로 넣지 않는다 |

`department` 3건과 로봇학부 트랙 4건은 스키마 실행 시 함께 들어간다.

## 핵심 — `load_event` 는 손대지 않는다

`report` 가 한 줄 들어오면 트리거가 **주차 단위로 펼쳐** `load_event` 를 자동 생성한다.
`"mid"` → 8주차, `"final"` → 15주차로 바꾸고, `"unknown"` 은 이벤트를 만들지 않는다.

```
report 1건                          →   load_event 5건
  프로젝트 15주차                        15 project_due
  퀴즈 2회 (5주차, 12주차)                 5 quiz · 12 quiz
  중간 1회 · 기말 1회                      8 exam · 15 exam
```

CSV import 로 `report` 를 밀어넣어도 트리거가 똑같이 돈다. 그래서 아티팩트 프로토타입
데이터를 옮길 때 `report` 만 넣으면 `load_event` 는 알아서 생긴다.

## 권한 (RLS) — 끄지 말 것

Supabase 는 `anon key` 를 브라우저에 노출한 채 동작한다. RLS 를 끄면 그 키만으로
누구나 전체 테이블을 읽고 고칠 수 있다.

| 대상 | anon (브라우저) | 팀 (Studio · DBeaver) |
|---|---|---|
| `report` | **넣기만 가능.** 읽기 불가 | 전부 |
| `load_event` | 접근 불가 | 전부 |
| 참조 테이블 | 읽기만 | 전부 |
| `v_week_load` `v_course_confidence` | 읽기 가능 (집계만 공개) | 전부 |

`service_role key` 는 **절대** 레포·단톡방·클라이언트 코드에 올리지 않는다.

## 검증 결과 (2026-09-18)

PostgreSQL 16 에서 실제로 실행해 확인했다.

- 스키마 전체 실행 성공 (Supabase 롤 `anon` · `authenticated` 생성 후)
- `mid` → 8주차, `final` → 15주차 변환 확인
- `unknown` 은 이벤트를 만들지 않음 (퀴즈 3회 중 2건만 생성)
- `exam_final = 2` → 15주차 exam 2건 (코딩테스트 + 필기 분리 케이스)
- 집계 뷰 `load_score` 계산 확인 — 15주차 5.50 = exam 3.0 + project_due 2.5

## 다음

- **DB 담당 2명** — 3개 학부 교과과정표 → `course` CSV import (150과목 목표),
  이어서 `prerequisite` · `track_course` 매핑
- **개발** — `app/collector/form.html` 의 저장 호출을 `POST /api/reports` 로 교체해
  Next.js 페이지로 이식 (아티팩트는 외부 fetch 가 막혀 Supabase 에 붙지 못한다)
