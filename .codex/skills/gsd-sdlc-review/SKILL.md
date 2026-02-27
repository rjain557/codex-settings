---
name: gsd-sdlc-review
description: Codex-native deterministic SDLC review. Always compare latest Figma and latest spec artifacts against code, run Claude-equivalent /gsd:code-review layer analysis, detect contract drift, and map all findings to remediation phases.
---

# Purpose
Run deterministic, evidence-based SDLC review that enforces design/spec/code parity and guarantees every finding has a remediation phase path to 100/100.

# When to use
Use when asked for `$gsd-sdlc-review`, or whenever a remediation loop requires current health and drift findings.

# Inputs
Optional arguments:
- `--layer=frontend|backend|database|auth`
- `--review-parallelism <n>`: Max concurrent review agents for parity/layer/runtime fan-out (default `6`)
- `--skip-build` (allowed, but deterministic parity checks are still mandatory)
- `--review-root <path>`: Optional artifact root override (equivalent to env `GSD_REVIEW_ROOT`).

Artifact root selection:
- Default artifact root is `docs/review`.
- If env `GSD_REVIEW_ROOT` is set (or `--review-root` provided), treat that as the canonical review root for all reads/writes in this run.

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

8. Run layer review and quality/build checks (parallel multi-agent)
- Run the `gsd-code-review` workflow semantics as a mandatory sub-flow for current-run evidence:
  - Load `C:/Users/rjain/.claude/get-shit-done/workflows/code-review.md` and `C:/Users/rjain/.claude/agents/gsd-code-reviewer.md`.
  - Apply the same layer/wave model used by Claude `/gsd:code-review` with explicit agent fan-out:
    - Wave 1: launch one reviewer agent per detected component in parallel (`frontend`, `backend`, `database`, `auth`, plus `mcp`, `mobile`, `extension`, `agent` when present).
    - Wave 2: launch cross-cutting analyzers in parallel (`TRACEABILITY-MATRIX`, `CONTRACT-ALIGNMENT`, `DEAD-CODE`).
    - Wave 3: run build verification unless `--skip-build` is set.
  - Bound parallel fan-out by `--review-parallelism` and keep deterministic artifact naming/merge order.
  - Single-layer mode (`--layer=...`) must run the corresponding reviewer and still include severity outputs for that layer.
- Require/update layer outputs under `docs/review/layers/` for each detected in-scope component.
- Consolidate code-review severity counts into one artifact `docs/review/layers/code-review-summary.json`.
- Deep review must be computed from current-run code/layer analysis outputs, not by ingesting prior summary artifacts.
- Deep-review ingestion must parse both summary formats:
  - `Findings: <b> Critical/Blocker | <h> High | <m> Medium | <l> Low`
  - `Findings: <b> Blocker | <h> High | <m> Medium | <l> Low`
- Deep-review ingestion must also capture dead-code and traceability-gap totals from current-run artifacts when reported.
- `deepReview.status` in `docs/review/layers/code-review-summary.json` must be parseable and not `UNPARSABLE`/`INGESTED`; otherwise emit blocker `DEEPREVIEW-BLOCKER-MISSING-001` and force remediation phase creation in the same run.
- Emit one parseable line in executive/full report:
  - `Code Review Totals: AUTH=<b>/<h>/<m>/<l> BACKEND=<b>/<h>/<m>/<l> DATABASE=<b>/<h>/<m>/<l> FRONTEND=<b>/<h>/<m>/<l> OTHER=<b>/<h>/<m>/<l> TOTAL_FINDINGS=<n>`
- Treat build/typecheck failure as BLOCKER.
- If no runnable build surfaces exist, emit BLOCKER (`ROOT-BLOCKER-NO-BUILD-SURFACE`).

9. Run mandatory runtime verification gates (parallel multi-agent hard gate)
- Runtime gates are mandatory for every full SDLC review run and every auto-dev cycle rerun.
- `--skip-build` does not skip runtime gates.
- For each gate, capture concrete evidence (command, endpoint, status code/output) and write a parseable status to review artifacts.
- Execute runtime gates using parallel groups where safe:
  - backend API/runtime gates in parallel with frontend dependency/build gates,
  - preserve deterministic merge/report order when aggregating results.
- Required runtime gates:
  - API Swagger generation gate:
    - Start API in local dev profile.
    - Verify `GET /swagger/v1/swagger.json` returns `200`.
    - Any `500`/generation exception is BLOCKER (`API-BLOCKER-SWAGGER-GENERATION`).
  - API route ambiguity gate:
    - Probe representative authenticated admin endpoints (including `/api/admin/connectors` when present).
    - `401/403` when unauthenticated is acceptable; `500`/`AmbiguousMatchException` is BLOCKER (`API-BLOCKER-ROUTE-AMBIGUITY`).
  - Launch profile/runtime alignment gate:
    - Compare `launchSettings.json` URLs and launch target to effective runtime bind addresses.
    - Port/profile drift or missing Swagger launch target is HIGH (`API-HIGH-LAUNCH-PROFILE-DRIFT`).
  - Frontend dependency integrity gate:
    - Run clean dependency resolution in SPA (`npm ci` when lockfile exists, otherwise clean `npm install`).
    - Peer dependency resolver failures (`ERESOLVE`) are BLOCKER (`FE-BLOCKER-DEPENDENCY-CONFLICT`).
  - Frontend build gate:
    - Run production build (`npm run build`) after dependency install.
    - Build failure is BLOCKER (`FE-BLOCKER-BUILD`).
  - Frontend local API target gate:
    - Validate configured local API base URL and fallback configuration point to active local backend target.
    - Drift/mismatch is HIGH (`FE-HIGH-API-BASEURL-DRIFT`).
  - Browser asset gate:
    - Verify favicon declaration exists and target asset exists (no startup `/favicon.ico` 404 noise).
    - Missing favicon is LOW (`FE-LOW-FAVICON-MISSING`).
  - CORS unauthorized-response gate:
    - For auth/me (or canonical auth endpoint), verify both:
      - preflight `OPTIONS` has expected CORS headers,
      - unauthorized `GET`/`POST` response still includes CORS allow-origin header.
    - Missing CORS headers on non-preflight unauthorized responses is HIGH (`API-HIGH-CORS-UNAUTHORIZED-MISSING`).
  - Health endpoint gate:
    - Check `/health` response and status.
    - If unhealthy due missing local prerequisites (e.g., DB connection string/model files), emit explicit environment finding (`ENV-HIGH-HEALTH-PREREQ-MISSING`) with prerequisite details.
- Runtime gates must emit one parseable line in executive/full report:
  - `Runtime Gate Totals: SWAGGER=<PASS|FAIL|UNVERIFIED> ROUTE_AMBIGUITY=<PASS|FAIL|UNVERIFIED> LAUNCH_PROFILE=<PASS|FAIL|UNVERIFIED> FE_INSTALL=<PASS|FAIL|UNVERIFIED> FE_BUILD=<PASS|FAIL|UNVERIFIED> FE_API_BASEURL=<PASS|FAIL|UNVERIFIED> FAVICON=<PASS|FAIL|UNVERIFIED> CORS_401=<PASS|FAIL|UNVERIFIED> HEALTH=<PASS|FAIL|UNVERIFIED> FAILURES=<n> UNVERIFIED=<n>`
- Any runtime gate marked `FAIL` or `UNVERIFIED` prevents clean-state status.

10. Enforce line-level evidence quality
- Each finding must include at least one concrete evidence pointer:
  - file path + line, or
  - deterministic command output summary with artifact path.
- Avoid generic claims without evidence.

11. Generate/update review artifacts (required)
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`
- `docs/review/layers/runtime-gates.json`

12. Mandatory remediation phase mapping and generation
- Every finding must map to a remediation phase.
- Load existing roadmap/state and pending phases first.
- If missing, bootstrap:
  - `.planning/PROJECT.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
- Create remediation phases immediately for unmapped findings.
- Final artifact must include `Unmapped findings: 0`.

13. Health scoring and clean-state gate
- Executive summary must include parseable health line `X/100`.
- Never report `100/100` unless all are true:
  - deterministic totals `TOTAL=0`,
  - all parity counters are `0`,
  - deterministic parity command exits clean,
  - implementation census is non-zero for required layers,
  - build/typecheck pass,
  - runtime gate failures are `0`,
  - runtime gate unverified count is `0`,
  - code-review layers were rerun in current execution (no reused/stale layer findings),
  - all detected in-scope code-review layers are verified (no missing layer artifact),
  - code-review BLOCKER/HIGH/MEDIUM/LOW totals are all `0`,
  - no unmapped findings,
  - no root ambiguity,
  - no stale-report contradictions remaining.
- If implementation census is zero, health must remain <=20.
- If any required runtime gate is `UNVERIFIED`, cap health at <=80.
- If any required runtime gate is `FAIL`, cap health at <=60.
- If deep review status is `INGESTED`, `UNPARSABLE`, empty, or sourced from summary artifacts instead of current-run layer analysis, cap health at <=60.

14. Mandatory post-review publication commit to GitHub
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
- If publish fails, run automatic remediation loop before stopping (max 3 retries):
  - If commit returns "nothing to commit", treat as commit success and continue to push HEAD.
  - If push rejects with non-fast-forward/diverged:
    - `git fetch origin`
    - `git pull --rebase origin <current-branch>`
    - retry push.
  - If push fails due missing upstream:
    - `git push -u origin <current-branch>`
  - If push fails due protected/default branch restrictions:
    - create fallback branch `review/<yyyyMMdd>-<shortsha>`
    - `git push -u origin <fallback-branch>`
    - continue only after successful push to fallback branch.
  - If push fails due transient artifacts (known large/generated paths):
    - unstage/remove known transient artifacts from commit (e.g. `node_modules`, build outputs, temp logs),
    - recommit with same executive-summary subject,
    - retry push.
- Do not proceed to success reporting until commit+push succeeds on either primary or fallback branch.
- If all remediation retries fail, emit `ROOT-BLOCKER-PUSH-FAILED` and stop.
- Record commit message, SHA, target branch, retry count, remediation actions, and final push result in review artifacts.

15. Return concise run summary
- Report health, severity totals, deterministic drift totals, code-review totals by layer, runtime gate totals, stale-report mismatch count, publication commit SHA/branch/message, push-retry outcome, and remediation phases created/updated.

# Outputs / artifacts
Always produce or refresh:
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`
- `docs/review/layers/runtime-gates.json`
- `docs/review/layers/code-review-summary.json`
- `docs/review/layers/*-findings.md` (for each detected in-scope component)

# Guardrails
- Do not skip deterministic parity checks.
- Do not run layer/runtime review as a single-agent serial pass when parallel fan-out is available.
- Do not skip current-run code-review layer analysis for detected in-scope components.
- Do not set or keep `Deep Review Totals: STATUS=INGESTED` based on `docs/review/EXECUTIVE-SUMMARY.md` artifact ingestion.
- Do not accept `Deep Review Totals: STATUS=UNPARSABLE`; treat it as a blocker that requires new remediation phase generation.
- Do not manually patch `Health`, `Code Review Totals`, or `Deep Review Totals` in executive/full report to force clean metrics.
- Regenerate `docs/review/layers/code-review-summary.json` every run with current-run timestamp and `lineTraceability.status=PASSED`.
- Do not skip required runtime gates in full SDLC review or auto-dev re-review cycles.
- Do not mark runtime gates as PASS without direct command/runtime evidence from the current run.
- Do not treat `UNVERIFIED` runtime gates as passing.
- Do not reuse stale `docs/review/layers/*-findings.md` from previous runs; regenerate each run.
- Do not write review artifacts outside the selected review root (`GSD_REVIEW_ROOT` when set, otherwise `docs/review`).
- Do not use stale or non-latest Figma/spec sources.
- Do not claim clean status without deterministic evidence and explicit source timestamps.
- Do not leave findings without remediation phase mapping.
- Do not emit `100/100` while any deterministic drift counter is non-zero.
