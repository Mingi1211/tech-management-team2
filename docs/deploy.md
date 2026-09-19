# 배포 가이드 — Supabase + Vercel

## 1단계 · Supabase 스키마 적용

### 처음 실행할 때

Supabase 대시보드 → 왼쪽 **SQL Editor** → **New query** →
`db/schema.sql` 전체를 붙여넣고 **Run**.

### `relation "department" already exists` 오류가 났을 때

이미 한 번 실행되어 테이블이 만들어져 있다는 뜻이다. 순서대로 한다.

1. SQL Editor 에서 **`db/reset.sql`** 을 붙여넣고 Run
   → 맨 아래 결과가 **0 rows** 면 깨끗이 지워진 것이다
2. 다시 **`db/schema.sql`** 을 붙여넣고 Run
3. **Table Editor** 에서 테이블 7개를 확인한다
   `department` `course` `prerequisite` `track` `track_course` `report` `load_event`

> ⚠️ `reset.sql` 은 **쌓인 응답까지 전부 지운다.** 선배 응답을 받기 시작한 뒤에는
> 쓰지 말 것. 꼭 필요하면 먼저 `report` 를 CSV 로 내보내 둔다.

### 제대로 들어갔는지 확인

SQL Editor 에서:

```sql
select (select count(*) from department) as 학부,   -- 3 이어야 한다
       (select count(*) from track)      as 트랙;   -- 4 이어야 한다
```

---

## 2단계 · Vercel 배포

### 2-1. 프로젝트 만들기

1. <https://vercel.com> → **Continue with GitHub** 로 로그인
2. 대시보드에서 **Add New… → Project**
3. **Import Git Repository** 목록에서 `Mingi1211/tech-management-team2` 선택
   - 목록에 안 보이면 **Adjust GitHub App Permissions** 를 눌러
     이 레포에 접근 권한을 준다 (private 이라 기본으로는 안 보인다)

### 2-2. 빌드 설정

기본값 그대로 두면 된다. Next.js 는 자동 인식된다.

| 항목 | 값 |
|---|---|
| Framework Preset | **Next.js** (자동) |
| Root Directory | `./` (그대로) |
| Build Command | 자동 (`next build`) |
| Output Directory | 자동 |

### 2-3. 환경변수 — 여기가 핵심

**Deploy 를 누르기 전에** Environment Variables 를 펼쳐 두 개를 넣는다.

| Name | Value |
|---|---|
| `SUPABASE_URL` | `https://xxxxxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhbGciOi...` 로 시작하는 긴 문자열 |

**값을 어디서 찾나** — Supabase 대시보드 →
**Project Settings → API** (톱니바퀴 아이콘)

- `SUPABASE_URL` ← **Project URL**
- `SUPABASE_ANON_KEY` ← **Project API keys** 의 **`anon` `public`**

> **`service_role` 키를 넣으면 안 된다.** 그 키는 RLS 를 무시하고 모든 데이터를
> 읽고 지울 수 있다. 반드시 `anon` 쪽을 쓴다.

**환경(Environment) 선택** — 드롭다운에서 **`Production and Preview`** 를 고른다
(기본값이므로 대개 그대로 두면 된다).

| 선택지 | 쓰임 |
|---|---|
| **Production and Preview** | 실제 배포 주소 + 브랜치 미리보기 배포. **우리가 쓰는 건 전부 여기** |
| Production | 실배포만 |
| Preview | 미리보기만 |
| Development | `vercel dev` 로 로컬 실행할 때만 |

`Development` 는 필요 없다. 로컬에서는 `vercel dev` 가 아니라 `npm run dev` 를 쓰고,
그쪽은 `.env.local` 파일에서 값을 읽는다.

### 2-4. 배포

**Deploy** 를 누르고 1~2분 기다린다.
끝나면 `https://tech-management-team2-xxxx.vercel.app` 같은 주소가 나온다.

---

## 3단계 · 배포 확인

1. 배포 주소를 열어 폼이 뜨는지 본다
2. 아무 과목이나 하나 넣고 **제출**한다
3. Supabase → **Table Editor → report** 에 한 줄이 들어왔는지 본다
4. **load_event** 에 그 줄에서 펼쳐진 이벤트들이 있는지 본다
   → 여기까지 보이면 전 구간이 연결된 것이다
5. 확인용으로 넣은 줄은 지운다 (`load_event` 도 함께 지워진다)

```sql
delete from report where course_name = '테스트';
```

### 실제 원인 보는 법

Vercel → 프로젝트 → **Logs** 탭 → 제출을 한 번 더 해 본다.
`Supabase insert 실패 <상태코드> <본문>` 줄이 뜨고, 상태 코드가 원인을 가른다.

| 코드 | 뜻 | 대처 |
|---|---|---|
| `404` (`PGRST205`) | 테이블이 없다 | `db/schema.sql` 실행 |
| `401` · `403` | anon key 가 틀렸거나 RLS 차단 | 키를 다시 복사, 재배포 |
| `400` | 컬럼 불일치 | 스키마가 최신인지 확인 (`reset.sql` → `schema.sql`) |

### 제출이 안 될 때

| 화면 메시지 | 원인 | 대처 |
|---|---|---|
| "서버 설정이 아직 끝나지 않았습니다" | 환경변수 미설정 | 2-3 을 다시 확인하고 **재배포** |
| "데이터베이스 준비가 끝나지 않았습니다" | 테이블이 없다 | 1단계(schema.sql 실행)를 다시 |
| "저장하지 못했습니다" | anon key 오류 또는 RLS 차단 | Vercel → **Logs** 에서 `Supabase insert 실패` 줄의 상태 코드를 본다 |
| 페이지가 아예 안 뜸 | 빌드 실패 | Vercel → Deployments → 실패한 배포의 로그 확인 |

> **환경변수를 추가하거나 고친 뒤에는 반드시 재배포해야 적용된다.**
> Vercel → Deployments → 맨 위 배포의 `⋯` → **Redeploy**

---

## 4단계 · QR 만들기

배포 주소로 QR 코드를 만들어 포스터·단톡방에 배포한다.
QR 생성기는 아무거나 써도 되지만, **주소가 바뀌지 않는 것이 중요하다** —
한번 뿌린 QR 은 회수할 수 없다.

Vercel 기본 주소(`...vercel.app`)는 계속 유지되므로 그대로 써도 된다.

---

## 앞으로 코드를 고치면

`main` 에 푸시하면 Vercel 이 **자동으로 다시 배포한다.** 따로 할 일이 없다.
다른 브랜치에 푸시하면 미리보기(Preview) 배포가 따로 생긴다.

## 로컬에서 돌려 보려면

```bash
npm install
cp .env.example .env.local     # SUPABASE_URL, SUPABASE_ANON_KEY 를 채운다
npm run dev                    # http://localhost:3000
```

`.env.local` 은 `.gitignore` 에 있어 커밋되지 않는다.
