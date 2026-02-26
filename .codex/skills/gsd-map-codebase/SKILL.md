---
name: gsd-map-codebase
description: Analyze codebase with parallel mapper agents to produce .planning/codebase/ documents Use when the user asks for 'gsd:map-codebase', 'gsd-map-codebase', or equivalent trigger phrases.
---

# Purpose
Analyze existing codebase using parallel gsd-codebase-mapper agents to produce structured codebase documents.

Each mapper agent explores a focus area and **writes documents directly** to `.planning/codebase/`. The orchestrator only receives confirmations, keeping context usage minimal.

Output: .planning/codebase/ folder with 7 structured documents about the codebase state.

# When to use
Use when the user requests the original gsd:map-codebase flow (for example: $gsd-map-codebase).
Also use on natural-language requests that match this behavior: Analyze codebase with parallel mapper agents to produce .planning/codebase/ documents

# Inputs
The user's text after invoking $gsd-map-codebase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [optional: specific area to map, e.g., 'api' or 'auth'].
Context from source:
```text
Focus area: <parsed-arguments> (optional - if provided, tells agents to focus on specific subsystem)

**Load project state if exists:**
Check for .planning/STATE.md - loads context if project already initialized

**This command can run:**
- Before $gsd-new-project (brownfield codebases) - creates codebase map first
- After $gsd-new-project (greenfield codebases) - updates codebase map as code evolves
- Anytime to refresh codebase understanding
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.codex/get-shit-done/workflows/map-codebase.md
Then execute this process:
```text
1. Check if .planning/codebase/ already exists (offer to refresh or skip)
2. Create .planning/codebase/ directory structure
3. Spawn 4 parallel gsd-codebase-mapper agents:
   - Agent 1: tech focus â†’ writes STACK.md, INTEGRATIONS.md
   - Agent 2: arch focus â†’ writes ARCHITECTURE.md, STRUCTURE.md
   - Agent 3: quality focus â†’ writes CONVENTIONS.md, TESTING.md
   - Agent 4: concerns focus â†’ writes CONCERNS.md
4. Wait for agents to complete, collect confirmations (NOT document contents)
5. Verify all 7 documents exist with line counts
6. Commit codebase map
7. Offer next steps (typically: $gsd-new-project or $gsd-plan-phase)
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\map-codebase.md

