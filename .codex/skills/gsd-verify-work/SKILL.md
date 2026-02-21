---
name: gsd-verify-work
description: Validate built features through conversational UAT Use when the user asks for 'gsd:verify-work', 'gsd-verify-work', or equivalent trigger phrases.
---

# Purpose
Validate built features through conversational testing with persistent state.

Purpose: Confirm what Claude built actually works from user's perspective. One test at a time, plain text responses, no interrogation. When issues are found, automatically diagnose, plan fixes, and prepare for execution.

Output: {phase}-UAT.md tracking all test results. If issues found: diagnosed gaps, verified fix plans ready for $gsd-execute-phase

# When to use
Use when the user requests the original gsd:verify-work flow (for example: $gsd-verify-work).
Also use on natural-language requests that match this behavior: Validate built features through conversational UAT

# Inputs
The user's text after invoking $gsd-verify-work is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [phase number, e.g., '4'].
Context from source:
```text
Phase: <parsed-arguments> (optional)
- If provided: Test specific phase (e.g., "4")
- If not provided: Check for active sessions or prompt for phase

@.planning/STATE.md
@.planning/ROADMAP.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/verify-work.md
- @C:/Users/rjain/.claude/get-shit-done/templates/UAT.md
Then execute this process:
```text
Execute the verify-work workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/verify-work.md end-to-end.
Preserve all workflow gates (session management, test presentation, diagnosis, fix planning, routing).
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\verify-work.md
