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

  // 클라이언트가 보낸 값 중 우리가 아는 컬럼만 추린다. source 는 서버가 정한다.
  const r = body as ReportRow;
  const row = {
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
      // 저장된 id 를 돌려받아 확인 화면에 보여 준다.
      Prefer: "return=representation",
    },
    body: JSON.stringify(row),
    cache: "no-store",
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error("Supabase insert 실패", res.status, detail);
    return NextResponse.json(
      { error: "저장하지 못했습니다. 잠시 후 다시 시도해 주세요." },
      { status: 502 },
    );
  }

  const saved = (await res.json()) as Array<{ id: string }>;
  return NextResponse.json({ id: saved[0]?.id ?? null }, { status: 201 });
}
