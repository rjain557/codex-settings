---
name: gsd-sdlc-finalreview
description: Final SDLC code-completeness review. Deterministically map executable lines in generated and source code to latest Figma v8 and Phase A-E/spec contracts, then require a confirmation rerun on unchanged code.
---

# Purpose
Run a deterministic final SDLC gate that proves code completeness by line-level mapping to authoritative design and specification sources.

# When to use
Use for `$gsd-sdlc-finalreview`, for final release/code-complete checks, and as the terminal gate in `$gsd-auto-dev`.

# Inputs
Optional arguments:
- `--code-scope=generated+src` (default)
- `--figma-version=v8` (default)
- `--spec-mode=phase-ae+spec` (default)
- `--confirm-only` (revalidate on unchanged commit/hash)
- `--skip-build` (accepted for compatibility; mapping/parity gates still apply)
- `--repo-root <path>` (optional root override)

# Workflow
1. Resolve canonical root deterministically
- Use the same candidate model as review flow: `.` and `./tech-web-chatai.2` when `--repo-root` is not provided.
- Score candidates by required assets (`.planning`, `docs/spec`, `docs/review`, `design/figma`, code trees).
- Select highest score; tie-break by stable lexical path.

2. Resolve authoritative baselines
- Figma baseline: `design/figma/v8/src/**` only.
- Spec baseline:
  - `docs/sdlc/docs/Phase_A..E` (phase intent),
  - `docs/spec/**` (contracts),
  - `docs/phases/phase-c|d|e/**` (detailed deliverables).
- Missing required inputs are hard failures.

3. Build executable line inventory
- Scope: `generated/** + src/**`.
- Include extensions: `.cs`, `.ts`, `.tsx`, `.js`, `.sql`, `.ps1`, `.sh`.
- Exclude: `node_modules`, `dist`, `build`, `bin`, `obj`, `.git`.
- Count only executable lines (non-empty, non-comment).

4. Deterministic line mapping
- For each executable line, emit mapping evidence with:
  - `figma_refs[]` (>=1 required),
  - `spec_refs[]` (>=1 required),
  - `category`, `mapping_path`.
- Deterministic ordering is required for reproducible hashes.

5. Emit required artifacts
- `docs/review/layers/finalreview-line-map.jsonl`
- `docs/review/layers/finalreview-summary.json`
- `docs/review/FINAL-SDLC-LINE-TRACEABILITY.md`

6. Enforce hard gates
- `coverage_percent == 100`
- `unmapped_lines == 0`
- `drift_total == 0`
- `pending_remediation == 0`

7. Confirmation mode
- With `--confirm-only`, rerun analysis and compare against prior summary:
  - commit SHA unchanged,
  - summary hash identical.
- Mismatch fails with `FINALREVIEW_CONFIRMATION_MISMATCH`.

8. Return parseable result lines
- Print `FINALREVIEW_*` lines for automation parsing.
- Exit non-zero on failure.

# Script
Run:
- `node /mnt/c/Users/rjain/.codex/skills/gsd-sdlc-finalreview/scripts/finalreview.mjs [args]`
- If Linux `node` is unavailable in WSL, use Windows Node:
  - `"/mnt/c/Program Files/nodejs/node.exe" "<script-win-path>" [args]`

# Output contract
`finalreview-summary.json` must contain parseable top-level fields:
- `health`
- `drift_total`
- `unmapped_lines`
- `coverage_percent`
- `pending_remediation`
- `commit_sha`
- `summary_hash`
- `status`
- `stop_reason`

# Guardrails
- Do not treat legacy Figma versions (`v6`, `v7`) as authoritative for this gate.
- Do not mark success while any hard gate fails.
- Do not claim confirmation pass if commit or summary hash changed.
- Keep evidence deterministic and machine-parseable.
