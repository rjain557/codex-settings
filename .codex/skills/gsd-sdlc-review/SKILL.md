---
name: gsd-sdlc-review
description: Codex-only SDLC code review. Generate review reports with a parseable health score, prioritized findings, and required remediation phases when findings exist.
---

# Purpose
Run SDLC review and produce remediation-grade reports used by auto-dev loops.

# When to use
Use when asked for `$gsd-sdlc-review`, or when a remediation loop needs a fresh health score and findings.

# Inputs
Optional argument:
- `--layer=frontend|backend|database|auth|agent`

# Model policy
- Use Codex `extra-high` reasoning when available.
- If `extra-high` is unsupported for the account/workspace, automatically use the highest supported Codex model/reasoning level and continue.

# Workflow
1. Determine scope from `--layer`; default is full-project review.
2. Resolve canonical app root (mandatory, deterministic):
- Evaluate candidate roots: `.` then `tech-web-chatai.2`.
- Score each candidate by presence of: `src/Server/Technijian.Api`, `src/Client/technijian-spa`, `db`, `design/figma`, `docs/spec`.
- Select the highest-score root; tie-break on newest `docs/spec` modification timestamp.
- Record both selected and rejected roots in review artifacts.
- If both roots contain `docs/review/EXECUTIVE-SUMMARY.md` and parseable health values differ, create HIGH finding `REVIEW-H01` (conflicting review roots).
3. Resolve latest design/spec sources under selected app root:
- Discover Figma folders matching `design/figma/vXX` (or `design\\figma\\vXX`) and use largest numeric `XX`.
- Resolve spec source from `<appRoot>/docs/spec`; if versioned subfolders `vXX` exist, use highest `XX`, else use directory root.
- Record selected paths plus last-modified timestamps in review artifacts.
4. Read project context:
- `.planning/STATE.md` (if present)
- `.planning/ROADMAP.md` (if present)
- `docs/sdlc/phase.g.codedebugger/code-debugger.md` (if present)
5. Run mandatory deterministic parity checks before scoring:
- Web/Figma route parity:
  - Compare routes from `design/figma/vXX/src/_analysis/01-screen-inventory.md`, `04-navigation-routing.md`, and `src/BACKEND_INTEGRATION_GUIDE.md` (when present) against `src/Client/technijian-spa/src/router.tsx`.
  - Any missing primary/admin route in code is HIGH.
- Remote-agent contract parity:
  - Compare endpoint sets across:
    - `<specSource>/remote-agent.md`
    - `<specSource>/openclaw-remote-agent-spec.md`
    - `<specSource>/openapi.yaml`
    - `src/Server/Technijian.Api/Controllers/AgentsController.cs`
  - Missing `openclaw-remote-agent-spec.md` is HIGH `AGENT-H01`.
  - Cross-doc endpoint drift is HIGH `AGENT-H02+`.
- OpenAPI/controller coverage:
  - Ensure `CouncilController` and `AgentsController` public HTTP routes are represented in `openapi.yaml`.
  - Missing coverage is HIGH `SPEC-H01+`.
- API-SP map/database parity:
  - Parse `usp_*` tokens from `<specSource>/apitospmap.md`; each must exist as a procedure definition in `db/**/*.sql`.
  - Missing definitions are HIGH `DB-H01+`.
- Backend procedure-call/database parity:
  - Parse `usp_*` references from `src/Server/Technijian.Api/**/*.cs`; each must exist in `db/**/*.sql`.
  - Missing definitions are HIGH `DB-H50+`.
- Roadmap consistency sanity:
  - If phase summary table and phase checklist blocks contradict completion state for same phase IDs, create MEDIUM `PLAN-M01`.
6. Inspect repository and assess additional findings by severity (BLOCKER/HIGH/MEDIUM/LOW).
7. Run relevant build/typecheck checks for reviewed scope when feasible.
8. Generate/update review artifacts in canonical root:
- `<appRoot>/docs/review/EXECUTIVE-SUMMARY.md`
- `<appRoot>/docs/review/FULL-REPORT.md`
- `<appRoot>/docs/review/DEVELOPER-HANDOFF.md`
- `<appRoot>/docs/review/PRIORITIZED-TASKS.md`
- `<appRoot>/docs/review/TRACEABILITY-MATRIX.md`
- If `<appRoot>` is not `.`, also sync these files to `docs/review/*` at workspace root to prevent health-source drift.
9. Ensure executive summary includes parseable health line in `X/100` form and deterministic-check summary counts.
10. Health gating rule:
- Never report `100/100` if any deterministic parity check has unresolved mismatches.
- Build/test passing alone is not sufficient for `100/100`.
11. Remediation-phase requirement:
- If health is below `100/100` OR findings count is non-zero, create/update remediation phases in `.planning/ROADMAP.md` and `.planning/phases/*` so every finding is mapped to a phase/plan.
- Blocker/High findings must map to near-term phases.
- Medium/Low findings must be explicitly mapped to follow-on phases.
- Update `.planning/STATE.md` with created/updated phase IDs and current focus.
12. Return concise summary with top risks, deterministic-check deltas, and exact phase IDs created/updated.

# Guardrails
- Codex-only execution: use Codex-only execution; do not run non-Codex CLI wrappers.
- Do not skip artifact generation.
- Do not report clean status without writing updated evidence.
- Keep severity mapping and findings IDs stable across iterations when possible.
- Do not end review as successful if remediation is required but phases were not created/updated.
- Do not mark design/spec checks complete unless the latest `vXX` Figma revision and latest spec source are explicitly named in the artifacts.
- Do not mark review successful when review roots disagree on health.
- Do not claim remote-agent parity without explicit endpoint-set comparison across spec/docs/openapi/controller.
- Do not claim database parity without explicit `apitospmap.md` and backend `usp_*` cross-checks against `db/**/*.sql`.


