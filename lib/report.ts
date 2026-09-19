// 입력 폼과 API 가 공유하는 타입 · 상수 · 주차 정규화 로직.
// 주차 기준은 db/schema.sql 의 week_of() 와 반드시 일치해야 한다.

export const MID_WEEK = 8;
export const FINAL_WEEK = 15;
export const TOTAL_WEEKS = 15;

export const DEPARTMENTS = [
  { code: "robot", name: "로봇학부" },
  { code: "infoconv", name: "정보융합학부" },
  { code: "software", name: "소프트웨어학부" },
] as const;

export type DeptCode = (typeof DEPARTMENTS)[number]["code"];

export type ProjectType = "team" | "individual";
export type AssignmentPattern = "weekly" | "biweekly" | "exam_only" | "custom";

/** 폼이 고르게 하는 주차 토큰. 숫자 문자열이거나 아래 셋 중 하나. */
export type WeekToken = string; // "1".."15" | "mid" | "final" | "unknown"

export const WEEK_LABEL: Record<string, string> = {
  mid: "중간고사 무렵",
  final: "기말고사 무렵",
  unknown: "기억나지 않음",
};

export function weekLabel(token: WeekToken | null | undefined): string {
  if (!token) return "—";
  return WEEK_LABEL[token] ?? `${token}주차`;
}

/** 토큰 → 주차 숫자. "unknown" 과 빈 값은 null (부담 이벤트를 만들지 않는다). */
export function weekOf(token: WeekToken | null | undefined): number | null {
  if (!token) return null;
  if (token === "mid") return MID_WEEK;
  if (token === "final") return FINAL_WEEK;
  if (/^\d{1,2}$/.test(token)) {
    const n = Number(token);
    return n >= 1 && n <= 16 ? n : null;
  }
  return null; // "unknown" 포함
}

/** 주기에서 실제 제출 주차를 계산한다. custom 은 사용자가 고른 것을 그대로 쓴다. */
export function assignmentWeeksOf(
  pattern: AssignmentPattern | "",
  rawWeeks: WeekToken[],
): number[] {
  if (pattern === "weekly") {
    return Array.from({ length: TOTAL_WEEKS - 1 }, (_, i) => i + 2);
  }
  if (pattern === "biweekly") {
    const out: number[] = [];
    for (let w = 3; w <= TOTAL_WEEKS; w += 2) out.push(w);
    return out;
  }
  if (pattern === "exam_only") return [MID_WEEK, FINAL_WEEK];
  if (pattern === "custom") {
    return rawWeeks.map(weekOf).filter((w): w is number => w !== null);
  }
  return [];
}

/** 폼 상태. 화면이 들고 있는 값 그대로. */
export type FormState = {
  dept: DeptCode | "";
  term: "1" | "2" | "";
  course: string;
  professor: string;

  projectHas: "yes" | "no" | "";
  projectType: ProjectType | "";
  projectWeek: WeekToken;

  quizHas: "yes" | "no" | "";
  quizCount: string;
  quizWeeks: WeekToken[];

  assignmentHas: "yes" | "no" | "";
  assignmentPattern: AssignmentPattern | "";
  assignmentCount: string;
  assignmentWeeks: WeekToken[];

  examMid: string;
  examFinal: string;
};

export const EMPTY_FORM: FormState = {
  dept: "",
  term: "",
  course: "",
  professor: "",
  projectHas: "",
  projectType: "",
  projectWeek: "",
  quizHas: "",
  quizCount: "",
  quizWeeks: [],
  assignmentHas: "",
  assignmentPattern: "",
  assignmentCount: "",
  assignmentWeeks: [],
  examMid: "",
  examFinal: "",
};

/** DB 의 report 테이블 한 줄. 컬럼명은 db/schema.sql 과 같다. */
export type ReportRow = {
  dept_code: DeptCode;
  term: number;
  course_name: string;
  professor: string;
  project_has: boolean;
  project_type: ProjectType | null;
  project_week: string | null;
  quiz_has: boolean;
  quiz_count: number;
  quiz_weeks: string[];
  assignment_has: boolean;
  assignment_pattern: AssignmentPattern | null;
  assignment_count: number;
  assignment_weeks_raw: string[];
  assignment_weeks: number[];
  exam_mid: number;
  exam_final: number;
  source: "form";
};

export function toRow(f: FormState): ReportRow {
  const hasProject = f.projectHas === "yes";
  const hasQuiz = f.quizHas === "yes";
  const hasAssignment = f.assignmentHas === "yes";

  return {
    dept_code: f.dept as DeptCode,
    term: Number(f.term),
    course_name: f.course.trim(),
    professor: f.professor.trim(),

    project_has: hasProject,
    project_type: hasProject ? (f.projectType as ProjectType) : null,
    project_week: hasProject ? f.projectWeek : null,

    quiz_has: hasQuiz,
    quiz_count: hasQuiz ? Number(f.quizCount || 0) : 0,
    quiz_weeks: hasQuiz ? f.quizWeeks : [],

    assignment_has: hasAssignment,
    assignment_pattern: hasAssignment
      ? (f.assignmentPattern as AssignmentPattern)
      : null,
    assignment_count: hasAssignment ? Number(f.assignmentCount || 0) : 0,
    assignment_weeks_raw:
      hasAssignment && f.assignmentPattern === "custom" ? f.assignmentWeeks : [],
    assignment_weeks: hasAssignment
      ? assignmentWeeksOf(f.assignmentPattern, f.assignmentWeeks)
      : [],

    exam_mid: Number(f.examMid || 0),
    exam_final: Number(f.examFinal || 0),
    source: "form",
  };
}

/** 미리보기용. DB 트리거가 만드는 load_event 와 같은 결과여야 한다. */
export type LoadEvent = { week: number; kind: string };

export function loadEventsOf(row: ReportRow): LoadEvent[] {
  const out: LoadEvent[] = [];
  const push = (w: number | null, kind: string) => {
    if (w !== null) out.push({ week: w, kind });
  };

  if (row.project_has) push(weekOf(row.project_week), "project_due");
  if (row.quiz_has) row.quiz_weeks.forEach((t) => push(weekOf(t), "quiz"));
  row.assignment_weeks.forEach((w) => push(w, "assignment"));
  for (let i = 0; i < row.exam_mid; i++) push(MID_WEEK, "exam");
  for (let i = 0; i < row.exam_final; i++) push(FINAL_WEEK, "exam");

  return out;
}

/** 서버가 신뢰하지 않고 다시 검증한다. 문제가 없으면 빈 배열. */
export function validateRow(row: unknown): string[] {
  const errors: string[] = [];
  const r = row as Partial<ReportRow>;
  const isStr = (v: unknown) => typeof v === "string" && v.trim().length > 0;
  const inRange = (v: unknown, lo: number, hi: number) =>
    typeof v === "number" && Number.isInteger(v) && v >= lo && v <= hi;

  if (!DEPARTMENTS.some((d) => d.code === r.dept_code)) errors.push("학부를 고르세요.");
  if (r.term !== 1 && r.term !== 2) errors.push("개설 학기를 고르세요.");
  if (!isStr(r.course_name)) errors.push("과목명을 입력하세요.");
  if (!isStr(r.professor)) errors.push("담당 교수를 입력하세요.");
  if (typeof r.course_name === "string" && r.course_name.length > 100)
    errors.push("과목명이 너무 깁니다.");
  if (typeof r.professor === "string" && r.professor.length > 50)
    errors.push("교수명이 너무 깁니다.");

  if (r.project_has) {
    if (r.project_type !== "team" && r.project_type !== "individual")
      errors.push("프로젝트 형태를 고르세요.");
    if (!isStr(r.project_week)) errors.push("프로젝트 시기를 고르세요.");
  }

  if (r.quiz_has) {
    if (!inRange(r.quiz_count, 1, 4)) errors.push("퀴즈 횟수를 고르세요.");
    if (!Array.isArray(r.quiz_weeks) || r.quiz_weeks.some((w) => !isStr(w)))
      errors.push("퀴즈 시기를 모두 고르세요.");
  }

  if (r.assignment_has) {
    const patterns: AssignmentPattern[] = ["weekly", "biweekly", "exam_only", "custom"];
    if (!patterns.includes(r.assignment_pattern as AssignmentPattern))
      errors.push("과제 주기를 고르세요.");
    if (r.assignment_pattern === "custom") {
      if (!inRange(r.assignment_count, 1, 15)) errors.push("과제 횟수를 고르세요.");
      if (
        !Array.isArray(r.assignment_weeks_raw) ||
        r.assignment_weeks_raw.some((w) => !isStr(w))
      )
        errors.push("과제 시기를 모두 고르세요.");
    }
  }

  if (!inRange(r.exam_mid, 0, 2)) errors.push("중간고사 횟수를 고르세요.");
  if (!inRange(r.exam_final, 0, 2)) errors.push("기말고사 횟수를 고르세요.");

  return errors;
}
