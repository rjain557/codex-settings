---
name: gsd:code-review
description: Run comprehensive multi-agent code review with auto-detection for web apps, APIs, databases, MCP servers, mobile apps, browser extensions, and remote agents
argument-hint: "[--layer=frontend|backend|database|auth|mcp|mobile|extension|agent] [--skip-build]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - Task
---

<objective>
Run a comprehensive, dev-handoff-quality code review by auto-detecting project components and spawning parallel review agents with component-specific checklists.

Covers all project types: Web Frontend, Backend API (.NET/Node/Python/Go), Database (SQL/Mongo), Auth/SSO, MCP Server, Mobile App (React Native), Browser Extension (Manifest V3), Remote Agent.

Output: docs/review/ folder with executive summary, full report, developer handoff, and prioritized tasks.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/code-review.md
@C:/Users/rjain/.codex/agents/gsd-code-reviewer.md
@C:/Users/rjain/.codex/get-shit-done/references/ui-brand.md
</execution_context>

<context>
Options: $ARGUMENTS
- (no flags): Full review â€” auto-detect all components, full traceability + contract analysis
- --layer=frontend: Frontend layer only
- --layer=backend: Backend layer only
- --layer=database: Database layer only
- --layer=auth: Auth/SSO layer only
- --layer=mcp: MCP Server only
- --layer=mobile: Mobile app only
- --layer=extension: Browser extension only
- --layer=agent: Remote agent only
- --skip-build: Skip build verification step (faster, but misses build blockers)

@.planning/STATE.md (if exists â€” project context)
@.planning/ROADMAP.md (if exists â€” phase context)
</context>

<process>

## 1. Parse Options

Determine review scope from $ARGUMENTS:
- Default: full review (auto-detect all components + cross-layer analysis)
- --layer=X: single component review only (skip cross-layer analysis)
- --skip-build: skip build verification step

## 2. Load Context

Read the workflow file for detailed execution steps:
@C:/Users/rjain/.codex/get-shit-done/workflows/code-review.md

Read the agent definition for orchestration role and finding format:
@C:/Users/rjain/.codex/agents/gsd-code-reviewer.md

If .planning/STATE.md exists, read for project context (current phase, recent work).

## 3. Execute Review

Follow the workflow steps in order:

### Phase 0: Repository Inventory (orchestrator does this)
- Detect project components using marker patterns
- Map each component (files, entry points, API surface)
- Quick red flag scan (TODOs, any casts, empty catches, secrets)
- Present detected components to user

### Wave 1: Layer Reviews (parallel agents)
- Spawn one `general-purpose` agent per detected component
- Each agent receives its component-specific checklist from the workflow
- Each agent writes findings to `docs/review/layers/{component}-findings.md`
- Wait for all to complete, collect summary counts

### Wave 2: Cross-Cutting Analysis (parallel agents, full review only)
- Traceability Matrix Builder â†’ `docs/review/TRACEABILITY-MATRIX.md`
- Contract Alignment Checker â†’ `docs/review/CONTRACT-ALIGNMENT.md`
- Dead Code Analyzer â†’ `docs/review/DEAD-CODE.md`
- Wait for all to complete

### Wave 3: Build Verification (mandatory unless --skip-build)
- Run build commands for each detected component
- Record pass/fail with error details
- Build failures become BLOCKER findings

### Consolidation
- Read all findings from sub-agent output files
- Calculate health score (100 - penalties per severity)
- Generate 4 reports:
  1. `docs/review/EXECUTIVE-SUMMARY.md` â€” Health score, top risks
  2. `docs/review/FULL-REPORT.md` â€” All findings by severity
  3. `docs/review/DEVELOPER-HANDOFF.md` â€” Actionable tasks
  4. `docs/review/PRIORITIZED-TASKS.md` â€” Ordered list for /gsd:plan-phase

## 4. Present Results

Display executive summary:

```
Code Review Complete â€” Health: {score}/100 (Grade: {grade})

Components: {N} reviewed
Findings: {B} Blocker | {H} High | {M} Medium | {L} Low
Build: {backend_status} backend | {frontend_status} frontend
Est. effort: {hours}h total

Top 3 Risks:
1. {risk}
2. {risk}
3. {risk}

Reports:
- docs/review/EXECUTIVE-SUMMARY.md
- docs/review/FULL-REPORT.md
- docs/review/DEVELOPER-HANDOFF.md
- docs/review/PRIORITIZED-TASKS.md
```

## 5. Offer Next Steps

Based on findings severity:

**If blockers found:**
> Blockers should be fixed before any other work.
> Run `/gsd:add-phase` to create a fix phase from PRIORITIZED-TASKS.md

**If high findings but no blockers:**
> Consider creating a fix phase before your next milestone.
> Run `/gsd:add-phase` to add a remediation phase

**If only medium/low:**
> Code is in good shape. Address medium/low findings during regular development.

**Always offer:**
- "Re-run review after fixes: `/gsd:code-review`"
- "Validate API contracts: `/gsd:sdlc-validate`" (if available)
- "View full report: `cat docs/review/FULL-REPORT.md`"

</process>

