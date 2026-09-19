"use client";

import { useMemo, useState } from "react";
import {
  DEPARTMENTS,
  EMPTY_FORM,
  TOTAL_WEEKS,
  assignmentWeeksOf,
  loadEventsOf,
  toRow,
  weekLabel,
  type AssignmentPattern,
  type DeptCode,
  type FormState,
  type ProjectType,
  type WeekToken,
} from "@/lib/report";

/* ---------- 작은 부품 ---------- */

function Choices<T extends string>({
  label,
  options,
  value,
  onChange,
  grow = true,
}: {
  label: string;
  options: { v: T; t: string }[];
  value: string;
  onChange: (v: T) => void;
  grow?: boolean;
}) {
  return (
    <div className={grow ? "choices grow" : "choices"} role="group" aria-label={label}>
      {options.map((o) => (
        <button
          key={o.v}
          type="button"
          className="ch"
          aria-pressed={value === o.v}
          onClick={() => onChange(o.v)}
        >
          {o.t}
        </button>
      ))}
    </div>
  );
}

/** 주차 선택. 모바일에서 네이티브 스크롤 피커로 뜬다. */
function WeekSelect({
  id,
  placeholder,
  value,
  onChange,
}: {
  id: string;
  placeholder: string;
  value: WeekToken;
  onChange: (v: WeekToken) => void;
}) {
  return (
    <select id={id} value={value} onChange={(e) => onChange(e.target.value)}>
      <option value="">{placeholder}</option>
      {Array.from({ length: TOTAL_WEEKS }, (_, i) => i + 1).map((w) => (
        <option key={w} value={String(w)}>
          {w}주차
        </option>
      ))}
      <optgroup label="정확히 기억나지 않을 때">
        <option value="mid">중간고사 무렵</option>
        <option value="final">기말고사 무렵</option>
        <option value="unknown">기억나지 않음</option>
      </optgroup>
    </select>
  );
}

function WeekRows({
  idPrefix,
  count,
  word,
  weeks,
  onChange,
}: {
  idPrefix: string;
  count: number;
  word: string;
  weeks: WeekToken[];
  onChange: (i: number, v: WeekToken) => void;
}) {
  if (!count) return null;
  return (
    <div className="weeks">
      {Array.from({ length: count }, (_, i) => (
        <div className="wrow" key={i}>
          <span className="idx">{i + 1}회차</span>
          <WeekSelect
            id={`${idPrefix}-${i}`}
            placeholder={`${word} 시기`}
            value={weeks[i] ?? ""}
            onChange={(v) => onChange(i, v)}
          />
        </div>
      ))}
    </div>
  );
}

const MISSING_NOTE = (
  <div className="note">
    정확한 주차가 기억나지 않으면 <b>중간고사 무렵</b>이나 <b>기말고사 무렵</b>을 골라
    주세요. 비워 두는 것보다 대략적인 시기라도 남기는 편이 훨씬 쓸모 있습니다.
  </div>
);

/* ---------- 페이지 ---------- */

type Saved = { id: string | null; form: FormState };

export default function Page() {
  const [f, setF] = useState<FormState>(EMPTY_FORM);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [saved, setSaved] = useState<Saved | null>(null);

  const set = <K extends keyof FormState>(k: K, v: FormState[K]) =>
    setF((prev) => ({ ...prev, [k]: v }));

  const setWeek = (key: "quizWeeks" | "assignmentWeeks", i: number, v: WeekToken) =>
    setF((prev) => {
      const next = [...prev[key]];
      next[i] = v;
      return { ...prev, [key]: next };
    });

  const progress = useMemo(() => {
    const need: boolean[] = [
      !!f.dept,
      !!f.term,
      !!f.course.trim(),
      !!f.professor.trim(),
      !!f.projectHas,
      !!f.quizHas,
      !!f.assignmentHas,
      f.examMid !== "",
      f.examFinal !== "",
    ];
    if (f.projectHas === "yes") need.push(!!f.projectType, !!f.projectWeek);
    if (f.quizHas === "yes") {
      const n = Number(f.quizCount || 0);
      need.push(
        !!f.quizCount,
        n > 0 && Array.from({ length: n }, (_, i) => f.quizWeeks[i]).every(Boolean),
      );
    }
    if (f.assignmentHas === "yes") {
      need.push(!!f.assignmentPattern);
      if (f.assignmentPattern === "custom") {
        const n = Number(f.assignmentCount || 0);
        need.push(
          !!f.assignmentCount,
          n > 0 &&
            Array.from({ length: n }, (_, i) => f.assignmentWeeks[i]).every(Boolean),
        );
      }
    }
    const ok = need.filter(Boolean).length;
    return { ok, total: need.length, ready: ok === need.length };
  }, [f]);

  async function submit() {
    if (busy || !progress.ready) return;
    setBusy(true);
    setMsg("");
    try {
      const res = await fetch("/api/reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(toRow(f)),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        setMsg(data?.error ?? "저장하지 못했습니다. 다시 눌러 주세요.");
        setBusy(false);
        return;
      }
      setSaved({ id: data.id ?? null, form: f });
      window.scrollTo(0, 0);
    } catch {
      setMsg("연결에 실패했습니다. 네트워크를 확인하고 다시 눌러 주세요.");
      setBusy(false);
    }
  }

  if (saved) return <SavedView saved={saved} onAgain={() => location.reload()} />;

  const deptName = (c: DeptCode | "") =>
    DEPARTMENTS.find((d) => d.code === c)?.name ?? "";

  return (
    <div className="wrap">
      <header>
        <div className="brand">
          <h1>수강 경험 입력</h1>
          <span>학업나침반 · 약 3분</span>
        </div>
        <div className="bar">
          <i style={{ width: `${Math.round((progress.ok / progress.total) * 100)}%` }} />
        </div>
      </header>

      <div className="intro">
        <p>
          들었던 과목이 <b>언제 바쁘게 만들었는지</b>를 남겨 주세요. 후배들이 수강신청 전에
          학기 부담을 미리 계산하는 데 쓰입니다. 교수님이나 강의에 대한 평가는 받지
          않습니다.
        </p>
      </div>

      {/* 01 과목 */}
      <section>
        <div className="sh">
          <span className="n">01</span>
          <h2>과목 정보</h2>
        </div>
        <p className="hint">본인이 실제로 수강한 과목 기준으로 적어 주세요.</p>

        <div className="field">
          <label className="lb">개설 학부</label>
          <Choices
            label="개설 학부"
            value={f.dept}
            onChange={(v) => set("dept", v)}
            options={DEPARTMENTS.map((d) => ({ v: d.code as DeptCode, t: d.name }))}
          />
        </div>

        <div className="field">
          <label className="lb">개설 학기</label>
          <Choices
            label="개설 학기"
            value={f.term}
            onChange={(v) => set("term", v)}
            options={[
              { v: "1" as const, t: "1학기" },
              { v: "2" as const, t: "2학기" },
            ]}
          />
        </div>

        <div className="field">
          <label className="lb" htmlFor="course">
            과목명
          </label>
          <input
            type="text"
            id="course"
            placeholder="예) 디지털시스템설계"
            autoComplete="off"
            value={f.course}
            onChange={(e) => set("course", e.target.value)}
          />
        </div>

        <div className="field">
          <label className="lb" htmlFor="prof">
            담당 교수
          </label>
          <input
            type="text"
            id="prof"
            placeholder="예) 홍길동"
            autoComplete="off"
            value={f.professor}
            onChange={(e) => set("professor", e.target.value)}
          />
        </div>
      </section>

      {/* 02 프로젝트 */}
      <section>
        <div className="sh">
          <span className="n">02</span>
          <h2>프로젝트</h2>
        </div>
        <p className="hint">학기 중 진행한 프로젝트가 있었나요?</p>
        <Choices
          label="프로젝트 유무"
          value={f.projectHas}
          onChange={(v) => {
            set("projectHas", v);
            if (v !== "yes") setF((p) => ({ ...p, projectType: "", projectWeek: "" }));
          }}
          options={[
            { v: "yes" as const, t: "있었음" },
            { v: "no" as const, t: "없었음" },
          ]}
        />

        {f.projectHas === "yes" && (
          <div className="sub">
            <div className="field">
              <label className="lb">형태</label>
              <Choices
                label="프로젝트 형태"
                value={f.projectType}
                onChange={(v) => set("projectType", v as ProjectType)}
                options={[
                  { v: "team" as const, t: "팀 프로젝트" },
                  { v: "individual" as const, t: "개인 프로젝트" },
                ]}
              />
            </div>
            <div className="field">
              <label className="lb" htmlFor="projWeek">
                발표 · 제출이 있었던 시기
              </label>
              <WeekSelect
                id="projWeek"
                placeholder="시기를 고르세요"
                value={f.projectWeek}
                onChange={(v) => set("projectWeek", v)}
              />
            </div>
          </div>
        )}
      </section>

      {/* 03 퀴즈 */}
      <section>
        <div className="sh">
          <span className="n">03</span>
          <h2>퀴즈</h2>
        </div>
        <p className="hint">
          수업 중 본 쪽지시험·퀴즈를 말합니다. 중간·기말고사는 05번에서 따로 받습니다.
        </p>
        <Choices
          label="퀴즈 유무"
          value={f.quizHas}
          onChange={(v) => {
            set("quizHas", v);
            if (v !== "yes") setF((p) => ({ ...p, quizCount: "", quizWeeks: [] }));
          }}
          options={[
            { v: "yes" as const, t: "있었음" },
            { v: "no" as const, t: "없었음" },
          ]}
        />

        {f.quizHas === "yes" && (
          <div className="sub">
            <div className="field">
              <label className="lb">횟수</label>
              <Choices
                label="퀴즈 횟수"
                value={f.quizCount}
                onChange={(v) => setF((p) => ({ ...p, quizCount: v, quizWeeks: [] }))}
                options={[
                  { v: "1", t: "1회" },
                  { v: "2", t: "2회" },
                  { v: "3", t: "3회" },
                  { v: "4", t: "4회 이상" },
                ]}
              />
            </div>
            <WeekRows
              idPrefix="quizWeek"
              count={Number(f.quizCount || 0)}
              word="퀴즈"
              weeks={f.quizWeeks}
              onChange={(i, v) => setWeek("quizWeeks", i, v)}
            />
            {!!f.quizCount && MISSING_NOTE}
          </div>
        )}
      </section>

      {/* 04 과제 */}
      <section>
        <div className="sh">
          <span className="n">04</span>
          <h2>과제</h2>
        </div>
        <p className="hint">제출 과제·보고서·실습 리포트를 말합니다.</p>
        <Choices
          label="과제 유무"
          value={f.assignmentHas}
          onChange={(v) => {
            set("assignmentHas", v);
            if (v !== "yes")
              setF((p) => ({
                ...p,
                assignmentPattern: "",
                assignmentCount: "",
                assignmentWeeks: [],
              }));
          }}
          options={[
            { v: "yes" as const, t: "있었음" },
            { v: "no" as const, t: "없었음" },
          ]}
        />

        {f.assignmentHas === "yes" && (
          <div className="sub">
            <div className="field">
              <label className="lb">제출 주기</label>
              <Choices
                grow={false}
                label="과제 주기"
                value={f.assignmentPattern}
                onChange={(v) =>
                  setF((p) => ({
                    ...p,
                    assignmentPattern: v as AssignmentPattern,
                    assignmentCount: "",
                    assignmentWeeks: [],
                  }))
                }
                options={[
                  { v: "weekly" as const, t: "매주" },
                  { v: "biweekly" as const, t: "격주" },
                  { v: "exam_only" as const, t: "중간 · 기말 각 1회" },
                  { v: "custom" as const, t: "직접 고르기" },
                ]}
              />
            </div>

            {f.assignmentPattern === "custom" && (
              <>
                <div className="field">
                  <label className="lb" htmlFor="asgCount">
                    총 몇 회였나요?
                  </label>
                  <select
                    id="asgCount"
                    value={f.assignmentCount}
                    onChange={(e) =>
                      setF((p) => ({
                        ...p,
                        assignmentCount: e.target.value,
                        assignmentWeeks: [],
                      }))
                    }
                  >
                    <option value="">횟수를 고르세요</option>
                    {Array.from({ length: 15 }, (_, i) => i + 1).map((n) => (
                      <option key={n} value={String(n)}>
                        {n}회
                      </option>
                    ))}
                  </select>
                </div>
                <WeekRows
                  idPrefix="asgWeek"
                  count={Number(f.assignmentCount || 0)}
                  word="과제"
                  weeks={f.assignmentWeeks}
                  onChange={(i, v) => setWeek("assignmentWeeks", i, v)}
                />
                {!!f.assignmentCount && MISSING_NOTE}
              </>
            )}

            {f.assignmentPattern && f.assignmentPattern !== "custom" && (
              <div className="note">
                선택한 주기로 <b>
                  {assignmentWeeksOf(f.assignmentPattern, []).length}회
                </b>
                로 계산됩니다 ({assignmentWeeksOf(f.assignmentPattern, []).join(", ")}주차).
              </div>
            )}
          </div>
        )}
      </section>

      {/* 05 시험 */}
      <section>
        <div className="sh">
          <span className="n">05</span>
          <h2>중간 · 기말고사</h2>
        </div>
        <p className="hint">각각 몇 번 치렀는지만 고르면 됩니다.</p>
        <div className="exam">
          <div>
            <label className="lb">중간고사</label>
            <Choices
              label="중간고사 횟수"
              value={f.examMid}
              onChange={(v) => set("examMid", v)}
              options={[
                { v: "0", t: "없음" },
                { v: "1", t: "1회" },
                { v: "2", t: "2회" },
              ]}
            />
          </div>
          <div>
            <label className="lb">기말고사</label>
            <Choices
              label="기말고사 횟수"
              value={f.examFinal}
              onChange={(v) => set("examFinal", v)}
              options={[
                { v: "0", t: "없음" },
                { v: "1", t: "1회" },
                { v: "2", t: "2회" },
              ]}
            />
          </div>
        </div>
        <div className="note warn">
          <b>2회를 고르는 경우</b> — 같은 중간고사를{" "}
          <b>코딩테스트와 필기시험으로 나누어 다른 날 두 번</b> 치르는 과목이 있습니다.
          시험 주간에 준비할 것이 두 배가 되므로, 이때는 1회가 아니라 2회로 골라 주세요.
          <br />
          <br />
          시험 유형(온라인·오프라인, 서술형·객관식)은 사람마다 체감이 크게 갈리고
          에브리타임에서도 확인할 수 있어 수집하지 않습니다. 저희가 재는 것은{" "}
          <b>난도가 아니라 언제 얼마나 몰리는가</b>입니다.
        </div>
      </section>

      <div className="actions">
        <button
          type="button"
          className="submit"
          disabled={!progress.ready || busy}
          onClick={submit}
        >
          {busy
            ? "저장하는 중…"
            : progress.ready
              ? "제출하기"
              : `제출하기 (${progress.ok}/${progress.total})`}
        </button>
        <div className="msg">{msg}</div>
      </div>

      <footer>
        익명으로 저장되며 로그인·개인정보를 받지 않습니다.
        <br />
        교수 개인에 대한 평가·순위는 수집하지도, 제공하지도 않습니다.
        {f.dept && ` · ${deptName(f.dept)}`}
      </footer>
    </div>
  );
}

/* ---------- 제출 확인 ---------- */

function SavedView({ saved, onAgain }: { saved: Saved; onAgain: () => void }) {
  const row = toRow(saved.form);
  const events = loadEventsOf(row);
  const dept = DEPARTMENTS.find((d) => d.code === row.dept_code)?.name ?? "";

  const patternLabel: Record<string, string> = {
    weekly: "매주",
    biweekly: "격주",
    exam_only: "중간 · 기말 각 1회",
    custom: "직접 고름",
  };
  const weekList = (arr: string[]) =>
    arr.length ? arr.map((v, i) => `${i + 1}회차 ${weekLabel(v)}`).join(" · ") : "—";

  const rows: [string, string][] = [
    [
      "프로젝트",
      row.project_has
        ? `${row.project_type === "team" ? "팀" : "개인"} · ${weekLabel(row.project_week)}`
        : "없음",
    ],
    ["퀴즈", row.quiz_has ? `${row.quiz_count}회 · ${weekList(row.quiz_weeks)}` : "없음"],
    [
      "과제",
      row.assignment_has
        ? row.assignment_pattern === "custom"
          ? `직접 고름 · ${row.assignment_count}회 · ${weekList(row.assignment_weeks_raw)}`
          : `${patternLabel[row.assignment_pattern ?? ""]} · ${row.assignment_weeks.length}회 (${row.assignment_weeks.join(", ")}주차)`
        : "없음",
    ],
    ["중간 · 기말", `${row.exam_mid}회 · ${row.exam_final}회`],
    [
      "저장된 부담 이벤트",
      `${events.length}건 — ${events.map((e) => `${e.week}주차 ${e.kind}`).join(", ")}`,
    ],
  ];

  return (
    <div className="wrap">
      <header>
        <div className="brand">
          <h1>수강 경험 입력</h1>
          <span>학업나침반</span>
        </div>
        <div className="bar">
          <i style={{ width: "100%" }} />
        </div>
      </header>

      <div className="saved">
        <span className="flag">저장 완료</span>
        <h2>{row.course_name}</h2>
        <p className="who">
          {row.professor} 교수 · {dept} · {row.term}학기
        </p>
        <dl className="rec">
          {rows.map(([k, v]) => (
            <div key={k} style={{ display: "contents" }}>
              <dt>{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
        </dl>
        <p className="docid">문서 ID · {saved.id ?? "(확인 불가)"}</p>
        <button type="button" className="again" onClick={onAgain}>
          다른 과목도 입력하기
        </button>
      </div>

      <footer>저장된 그대로 표시한 것입니다. 빠진 항목이 있으면 다시 입력해 주세요.</footer>
    </div>
  );
}
