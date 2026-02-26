---
name: gsd-batch-research
description: Codex-native sequential phase research. Ensure each target phase has research artifacts before planning and execution.
---

# Purpose
Create missing research artifacts for a phase in a deterministic, sequential way.

# When to use
Use when a phase is pending and missing research, or when asked to run `$gsd-batch-research`.

# Inputs
Expected argument: `<phase-number>`.
Optional flags:
- `--force`: Regenerate research even when research files already exist.

# Workflow
1. Parse and validate phase number.
2. Resolve phase directory under `.planning/phases/<NN>-*`.
3. Detect existing research files (`*RESEARCH.md`).
- If present and `--force` is not set, report skip.
4. Read context:
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `docs/review/PRIORITIZED-TASKS.md` when present
5. Create/update phase research artifact (`<NN>-RESEARCH.md`) with:
- Scope and findings covered
- Target files/systems
- Risks and assumptions
- Dependencies and validation notes
6. Report created/updated files and next step (`$gsd-batch-plan <phase>`).

# Guardrails
- Keep operation phase-scoped.
- Do not execute code changes in this skill.
- Do not skip file-based evidence; research must be written to disk.

