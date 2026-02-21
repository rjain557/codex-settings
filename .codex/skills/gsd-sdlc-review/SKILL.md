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
1. Resolve canonical project root deterministically
- Evaluate candidate roots: `.` and `./tech-web-chatai.2`.
- Score each root by presence of required assets:
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
  - `docs/spec/`
  - `docs/review/`
  - `design/figma/` (or versioned equivalents)
  - source trees (`src/Client`, `src/Server`, `db`)
- Select highest-scoring root. If tie, select lexicographically stable path.
- Record selected root and candidate scores in review artifacts.

2. Resolve latest design/spec sources (mandatory every run)
- Identify latest Figma deliverable version by highest version folder and latest modified timestamp.
- Identify latest specification artifacts from `docs/spec/`:
  - `ui-contract.md`
  - `openapi.yaml` (or `.json`)
  - `apitospmap.md` (or canonical API-SP map)
  - `db-plan.md`
  - `remote-agent.md`
  - `openclaw-remote-agent-spec.md`
- Record exact source file paths and timestamps in artifacts.
- If required design/spec artifacts are missing, emit BLOCKER findings.

3. Run deterministic parity gates (mandatory)
- Design route parity:
  - Compare latest Figma route/screen deliverables to router definitions and screen imports.
  - Report missing routes, missing screens, partial implementations, alias drift.
- OpenAPI controller coverage:
  - Compare controller/action route surface to `openapi.yaml`.
  - Must explicitly cover `CouncilController` and `AgentsController` when present.
- Remote-agent contract parity:
  - Compare endpoint sets across `openclaw-remote-agent-spec.md`, `remote-agent.md`, `openapi.yaml`, and `AgentsController`.
- API-SP parity:
  - Compare `apitospmap` action and procedure references to controller methods and SQL definitions in `db/**/*.sql`.
  - Compare backend `usp_*` references to SQL procedure existence.
- DB-plan parity:
  - Compare planned table/procedure inventory in `db-plan.md` to SQL artifacts.

4. Run layer review and quality/build checks
- Perform severity-based findings review (BLOCKER/HIGH/MEDIUM/LOW).
- Run build/typecheck checks for in-scope layers unless explicitly skipped.
- Build failures are BLOCKER findings.

5. Generate/update review artifacts (required)
- `docs/review/EXECUTIVE-SUMMARY.md`
- `docs/review/FULL-REPORT.md`
- `docs/review/DEVELOPER-HANDOFF.md`
- `docs/review/PRIORITIZED-TASKS.md`
- `docs/review/TRACEABILITY-MATRIX.md`

6. Enforce deterministic evidence sections
- Include a deterministic evidence section in summary/full report with:
  - canonical root path
  - candidate root scores
  - selected latest Figma source + timestamp
  - selected latest spec sources + timestamps
  - parity check totals and mismatches by category
- Include stable finding IDs per category (`DESIGN-*`, `SPEC-*`, `OPENAPI-*`, `AGENT-*`, `DB-*`, `ROOT-*`, `PHASE-*`).

7. Mandatory remediation phase mapping and generation
- Every finding must map to a remediation phase.
- Load existing roadmap/state and existing pending phases first.
- If findings are unmapped, create remediation phases immediately (do not wait for user prompt), then map findings to those phases.
- Update roadmap/state and prioritized tasks so mapping is explicit and auditable.
- Final artifact must include `Unmapped findings: 0`.

8. Health scoring and clean-state gate
- Executive summary must include parseable health line in `X/100` format.
- Never report `100/100` unless all are true:
  - deterministic parity mismatches are zero,
  - build/type checks pass (or are explicitly out-of-scope with no blocker evidence),
  - no unmapped findings,
  - no root-conflict ambiguity.
- If any deterministic drift remains, health must stay below 100 and remediation phases must exist.

9. Return concise run summary
- Report health, severity totals, deterministic mismatch totals, and remediation phases created/updated.

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
- Do not emit `100/100` while any parity drift remains.
