---
name: gsd-sdlc-review
description: Codex-native deterministic SDLC review. Always compare latest Figma and latest spec artifacts against code, detect contract drift, and map all findings to remediation phases.
---

# Purpose
Run deterministic, evidence-based SDLC review that enforces design/spec/code parity and guarantees every finding has a remediation phase path to 100/100.

# When to use
Use when asked for `$gsd-sdlc-review`, or whenever a remediation loop requires current health and drift findings.

# Inputs
Optional arguments:
- `--layer=frontend|backend|database|auth`
- `--skip-build` (allowed, but deterministic parity checks are still mandatory)

# Workflow
1. Mandatory milestone rotation before review
- Close previous milestone and open the next milestone before review:
  - run `gsd:complete-milestone` non-interactively (assume yes)
  - run `gsd:new-milestone` non-interactively (assume yes)
- Record previous milestone id, new milestone id, and branch in review artifacts.

2. Resolve canonical project root deterministically
- Evaluate candidate roots: `.` and `./tech-web-chatai.2`.
- Score each root by required asset groups:
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
  - `docs/spec/`
  - `docs/review/`
  - `design/figma/` (or versioned equivalents)
  - source trees (`src/Client`, `src/Server`, `db`)
- Select highest-scoring root. If tie, choose lexicographically stable path.
- Record root and candidate scores in artifacts.

3. Run mandatory implementation evidence census (new hard gate)
- Count files by executable/schematic types in selected root:
  - `*.cs`, `*.csproj`, `*.sln`
  - `*.ts`, `*.tsx`, `*.js`
  - `*.sql`
- Record exact counts in executive/full report.
- If all core implementation counts are zero, emit `ROOT-BLOCKER-NO-IMPLEMENTATION` and cap health at <=20.

4. Resolve latest design/spec sources (mandatory every run)
- Identify latest **Figma deliverable** by version folder and timestamp.
- Exclude prompt/templates from being treated as design deliverables (e.g., files under `docs/**/templates/**`).
- Identify latest canonical spec artifacts from `docs/spec/`:
  - `ui-contract.md` (or canonical equivalent)
  - `openapi.yaml`/`openapi.json`
  - `apitospmap.csv`/`apitospmap.md` (or canonical API-SP map)
  - `db-plan.md`
  - `remote-agent.md`
  - `openclaw-remote-agent-spec.md`
- Record exact file paths + timestamps for all selected sources.
- Missing required design/spec artifacts are BLOCKER findings.

5. Run deterministic parity gates (mandatory)
- Design route parity:
  - Compare latest Figma routes/screens against router definitions and screen imports.
  - Compute `DESIGN_ROUTE_MISSING`, `DESIGN_SCREEN_MISSING`.
- OpenAPI controller coverage:
  - Compare controller/action surface to `openapi`.
  - Explicitly include `CouncilController` and `AgentsController` when present.
- Remote-agent contract parity:
  - Compare endpoint sets across `openclaw-remote-agent-spec.md`, `remote-agent.md`, `openapi`, and `AgentsController`.
  - Compute `OPENCLAW_ENDPOINT_GAP`.
- API-SP and backend SP parity:
  - Compare API-SP map operations to controller methods and SQL SP definitions in `db/**/*.sql`.
  - Compare backend `usp_*` references to SQL procedure existence.
  - Compute `BACKEND_USP_UNRESOLVED`.
- DB-plan parity:
  - Compare planned table/procedure inventory in `db-plan.md` to SQL artifacts.
  - Compute `DBPLAN_TABLE_DRIFT`.
- Deterministic parity command:
  - Run `scripts/sdlc/deterministic-parity.ps1` if present.
  - If missing, emit `SPEC-BLOCKER-DETERMINISTIC-GATE-MISSING`.
  - If present but unrunnable, emit `SPEC-BLOCKER-DETERMINISTIC-GATE`.

6. Run stale-report contradiction checks (new hard gate)
- Scan existing report artifacts (`docs/**/validation*.md`, `docs/**/report*.md`, JSON validation outputs).
- For each concrete "EXISTS/Complete" claim with a file path, verify path existence now.
- Emit `EVIDENCE-HIGH-STALEREPORT` for mismatches with path-level evidence.
- Never inherit health from historical reports.

7. Normalize deterministic totals (required)
- Output one parseable line:
  - `Deterministic Drift Totals: DESIGN_ROUTE_MISSING=<n> DESIGN_SCREEN_MISSING=<n> OPENCLAW_ENDPOINT_GAP=<n> DBPLAN_TABLE_DRIFT=<n> BACKEND_USP_UNRESOLVED=<n> TOTAL=<n>`
- Any non-zero counter must create findings and remediation mapping.

8. Run layer review and quality/build checks
- Perform severity review (BLOCKER/HIGH/MEDIUM/LOW).
- Run build/typecheck checks for in-scope layers unless explicitly skipped.
- Build/typecheck failure is BLOCKER.
- If no runnable build surfaces exist, emit BLOCKER (`ROOT-BLOCKER-NO-BUILD-SURFACE`).

9. Enforce line-level evidence quality
- Each finding must include at least one concrete evidence pointer:
  - file path + line, or
  - deterministic command output summary with artifact path.
- Avoid generic claims without evidence.

10. Generate/update review artifacts (required)
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`

11. Mandatory remediation phase mapping and generation
- Every finding must map to a remediation phase.
- Load existing roadmap/state and pending phases first.
- If missing, bootstrap:
  - `.planning/PROJECT.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
- Create remediation phases immediately for unmapped findings.
- Final artifact must include `Unmapped findings: 0`.

12. Health scoring and clean-state gate
- Executive summary must include parseable health line `X/100`.
- Never report `100/100` unless all are true:
  - deterministic totals `TOTAL=0`,
  - all parity counters are `0`,
  - deterministic parity command exits clean,
  - implementation census is non-zero for required layers,
  - build/typecheck pass,
  - no unmapped findings,
  - no root ambiguity,
  - no stale-report contradictions remaining.
- If implementation census is zero, health must remain <=20.

13. Mandatory post-review publication commit to GitHub
- After artifacts are generated, build commit message from `docs/review/EXECUTIVE-SUMMARY.md`:
  - Use a concise one-line executive summary derived from the report.
  - Preferred source order:
    1) explicit one-line summary line if present,
    2) `Health: X/100` + top finding id,
    3) first meaningful sentence in executive summary body.
  - Normalize commit subject to a single line and keep <= 120 chars.
- Commit and push review outputs:
  - `git add -A`
  - `git commit -m "<executive-summary-line>"`
  - `git push origin <current-branch>`
- If commit/push fails, emit `ROOT-BLOCKER-PUSH-FAILED`.
- Record commit message, SHA, branch, and push result in review artifacts.

14. Return concise run summary
- Report health, severity totals, deterministic drift totals, stale-report mismatch count, publication commit SHA/branch/message, and remediation phases created/updated.

# Outputs / artifacts
Always produce or refresh:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`

# Guardrails
- Do not skip deterministic parity checks.
- Do not use stale or non-latest Figma/spec sources.
- Do not claim clean status without deterministic evidence and explicit source timestamps.
- Do not leave findings without remediation phase mapping.
- Do not emit `100/100` while any deterministic drift counter is non-zero.
