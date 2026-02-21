---
name: gsd-sdlc-reorg
description: Run repository reorganization to SDLC v6.0 folder structure Use when the user asks for 'gsd:sdlc-reorg', 'gsd-sdlc-reorg', or equivalent trigger phrases.
---

# Purpose
Reorganize repository files to conform to the Technijian SDLC v6.0 canonical folder structure. Classifies all files, moves them to standardized locations, updates references, and validates builds.

Orchestrator role: Parse flags, confirm with user (destructive operation), verify clean git state, spawn sdlc-repo-organizer agent, present results.

# When to use
Use when the user requests the original gsd:sdlc-reorg flow (for example: $gsd-sdlc-reorg).
Also use on natural-language requests that match this behavior: Run repository reorganization to SDLC v6.0 folder structure

# Inputs
The user's text after invoking $gsd-sdlc-reorg is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--dry-run | --classify-only | --agent=name].
Context from source:
```text
Flags: <parsed-arguments>
- (no flags): Full reorganization with user confirmation
- --dry-run: Classify and plan only â€” no files moved (safe/read-only)
- --classify-only: Run classifier agent only â€” output classification report
- --agent=name: Run specific agent only (code, test, docs, database, design, scripts)
```

# Workflow
Load and follow these referenced artifacts first:
- @docs/sdlc/phase.g.reporeorg/01-orchestrator-agent.md
- @docs/sdlc/phase.g.reporeorg/README.md
- @.planning/STATE.md
Then execute this process:
```text
## 1. Parse Flags

Determine execution scope from <parsed-arguments>.

## 2. Safety Confirmation (skip for --dry-run and --classify-only)

Use AskUserQuestion:
"Repository reorganization will move files to the SDLC v6.0 folder structure. A backup will be created at .reorg-backup/ and all work will happen on a dedicated branch. Do you want to proceed?"

Options: "Yes, proceed" / "No, cancel"

If not confirmed: exit with message "Reorganization cancelled."

## 3. Verify Clean Working Tree (skip for --dry-run and --classify-only)

Check git status. If uncommitted changes exist:
> **Cannot proceed:** You have uncommitted changes. Please commit or stash your changes first, then re-run this command.

Exit without proceeding.

## 4. Spawn sdlc-repo-organizer Agent

Spawn via Task tool:
- description: "SDLC Repo Reorganization ({mode})"
- prompt: Include mode, and references to reorganization agent docs

The agent will:
1. Create backup and reorganization branch (unless dry-run)
2. Classify all files with target paths
3. Execute reorganization agents in dependency order
4. Validate builds after moves
5. Produce move manifest and validation report

## 5. Present Results

If --dry-run:
> **Dry Run Complete**
> {N} files classified. {M} would be moved.
> Classification report at: {path}
> Re-run without --dry-run to execute moves.

If --classify-only:
> **Classification Complete**
> {N} files classified across {types}.
> Report at: {path}

If full reorganization:
> **Reorganization Complete**
> - Files moved: {N}
> - Build status: {pass/fail}
> - Test status: {pass/fail}
> - Branch: reorg/sdlc-v6-structure
>
> Review changes and merge when ready.

If build failed:
> **Reorganization completed with build failures.**
> {error details}
> Check validation report at: {path}
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\sdlc-reorg.md
