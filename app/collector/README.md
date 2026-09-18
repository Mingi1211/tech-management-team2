# collector — 수강 경험 입력 폼 (프로토타입)

게시 주소: <https://claude.ai/artifact/5KFsa4EYePQ8SfDqjf8bJW>
소스: `form.html` (이 파일 하나가 전부. 빌드 과정 없음)

## 구조

```
form.html            ← 정본 소스 (여기)
     │ Artifact 도구로 publish
     ▼
claude.ai 아티팩트     ← 실행되는 페이지. 링크/QR로 접속
     │ 페이지 안에서 claude.use("db")
     ▼
아티팩트 전용 문서 저장소   ← 파일이 아니라 관리형 DB. collection "reports"
```

- **단일 HTML 파일.** 프레임워크·번들러 없음. `<style>`/`<script>` 내장, 폰트만 Google Fonts
- **DB는 파일이 아니다.** 아티팩트에 붙은 관리형 JSON 문서 저장소이며, 레포에는 데이터가 없다
- **CSV는 저장돼 있지 않다.** 「저장된 원본」 탭에서 그 순간 브라우저가 만들어 내려받는다

## 저장 형식 — `reports/<자동생성 id>`

```json
{
  "createdAt": "2026-09-18T07:48:19.601Z",
  "courseKey": "로봇학부|1|자동제어1|백주훈",
  "dept": "로봇학부", "term": 1, "course": "자동제어1", "professor": "백주훈",
  "project":    { "has": true, "type": "individual", "weekRaw": "15" },
  "quiz":       { "has": true, "count": 2, "weeksRaw": ["5","12"] },
  "assignment": { "has": false, "pattern": null, "count": 0,
                  "weeksRaw": [], "weeks": [] },
  "exam":       { "mid": 1, "final": 1 },
  "loadEvents": [ {"week":15,"kind":"project_due"}, {"week":5,"kind":"quiz"},
                  {"week":12,"kind":"quiz"}, {"week":8,"kind":"exam"},
                  {"week":15,"kind":"exam"} ]
}
```

- `*Raw` 는 **사용자가 고른 그대로** (`"mid"`, `"unknown"` 포함)
- `loadEvents` 는 **계산용 정규화 결과.** 중간=8주차, 기말=15주차로 변환하고
  `"unknown"` 은 제외한다. 부담 계산은 이 배열만 본다
- `courseKey` 는 같은 과목을 묶는 키 (`학부|학기|과목명|교수`)

## 제약 (실서비스로 쓸 수 없는 이유)

- `db` 를 선언한 아티팩트는 **조직 내부 전용** — 외부 공개 링크 불가, 열람자는 로그인 필요
- 문서 수 상한 5,000건 / 문서당 256 KiB
- 따라서 이것은 **팀 내부 문항 검증용**이다. 실배포는 Next.js + Supabase
  (`docs/plan/학업나침반-설계계획.pdf` §3·§4)

## 이식할 때

`form.html` 의 폼 로직·주차 정규화(`toWeek`, `assignmentWeeks`, `buildPayload`)는
그대로 옮기고, `db.collection("reports").add(payload)` 만
`POST /api/reports` 로 바꾸면 된다. 저장 형식은 동일하게 유지할 것.
