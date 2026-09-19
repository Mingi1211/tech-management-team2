import { NextResponse } from "next/server";
import { validateRow, type ReportRow } from "@/lib/report";

// 브라우저는 Supabase 에 직접 붙지 않는다. 이 라우트만 거친다.
// 덕분에 키가 서버에만 있고, 검증·차단을 한곳에서 할 수 있다.
export const runtime = "nodejs";

export async function POST(request: Request) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;

  if (!url || !key) {
    console.error("SUPABASE_URL / SUPABASE_ANON_KEY 가 설정되지 않았습니다.");
    return NextResponse.json(
      { error: "서버 설정이 아직 끝나지 않았습니다. 팀에 알려 주세요." },
      { status: 500 },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "요청을 읽지 못했습니다." }, { status: 400 });
  }

  const errors = validateRow(body);
  if (errors.length > 0) {
    return NextResponse.json({ error: errors[0], errors }, { status: 400 });
  }

  // id 를 서버에서 만들어 둔다.
  //   RLS 가 report 에 SELECT 정책을 두지 않으므로 (선배는 넣기만 하고 읽지 못한다),
  //   INSERT ... RETURNING 이 거부된다 — PostgreSQL 은 RETURNING 에 SELECT 를 요구한다.
  //   따라서 저장된 줄을 돌려받지 않고, 우리가 정한 id 를 그대로 확인 화면에 쓴다.
  const id = crypto.randomUUID();

  // 클라이언트가 보낸 값 중 우리가 아는 컬럼만 추린다. source 는 서버가 정한다.
  const r = body as ReportRow;
  const row = {
    id,
    dept_code: r.dept_code,
    term: r.term,
    course_name: r.course_name.trim(),
    professor: r.professor.trim(),
    project_has: !!r.project_has,
    project_type: r.project_has ? r.project_type : null,
    project_week: r.project_has ? r.project_week : null,
    quiz_has: !!r.quiz_has,
    quiz_count: r.quiz_has ? r.quiz_count : 0,
    quiz_weeks: r.quiz_has ? r.quiz_weeks : [],
    assignment_has: !!r.assignment_has,
    assignment_pattern: r.assignment_has ? r.assignment_pattern : null,
    assignment_count: r.assignment_has ? r.assignment_count : 0,
    assignment_weeks_raw: r.assignment_has ? r.assignment_weeks_raw : [],
    assignment_weeks: r.assignment_has ? r.assignment_weeks : [],
    exam_mid: r.exam_mid,
    exam_final: r.exam_final,
    source: "form" as const,
  };

  const res = await fetch(`${url}/rest/v1/report`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      // 돌려받지 않는다. 위 주석 참고.
      Prefer: "return=minimal",
    },
    body: JSON.stringify(row),
    cache: "no-store",
  });

  if (!res.ok) {
    const detail = await res.text();
    // Vercel → Logs 에서 이 줄을 보면 원인을 바로 알 수 있다.
    //   404 / PGRST205  → 테이블이 없다. db/schema.sql 을 실행했는지 확인
    //   401 / 403       → anon key 가 잘못됐거나 RLS 정책이 막고 있다
    console.error("Supabase insert 실패", res.status, detail);

    const hint =
      res.status === 404
        ? "데이터베이스 준비가 끝나지 않았습니다. 팀에 알려 주세요."
        : "저장하지 못했습니다. 잠시 후 다시 시도해 주세요.";
    return NextResponse.json({ error: hint }, { status: 502 });
  }

  return NextResponse.json({ id }, { status: 201 });
}
