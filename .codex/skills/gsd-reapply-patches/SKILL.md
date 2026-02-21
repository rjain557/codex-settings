---
name: gsd-reapply-patches
description: Reapply local modifications after a GSD update Use when the user asks for 'gsd:reapply-patches', 'gsd-reapply-patches', or equivalent trigger phrases.
---

# Purpose
After a GSD update wipes and reinstalls files, this command merges user's previously saved local modifications back into the new version. Uses intelligent comparison to handle cases where the upstream file also changed.

# When to use
Use when the user requests the original gsd:reapply-patches flow (for example: $gsd-reapply-patches).
Also use on natural-language requests that match this behavior: Reapply local modifications after a GSD update

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Then execute this process:
```text
## Step 1: Detect backed-up patches

Check for local patches directory:

```bash
# Global install
PATCHES_DIR="${HOME}/.claude/gsd-local-patches"
# Local install fallback
if [ ! -d "$PATCHES_DIR" ]; then
  PATCHES_DIR="./.claude/gsd-local-patches"
fi
```

Read `backup-meta.json` from the patches directory.

**If no patches found:**
```
No local patches found. Nothing to reapply.

Local patches are automatically saved when you run $gsd-update
after modifying any GSD workflow, command, or agent files.
```
Exit.

## Step 2: Show patch summary

```
## Local Patches to Reapply

**Backed up from:** v{from_version}
**Current version:** {read VERSION file}
**Files modified:** {count}

| # | File | Status |
|---|------|--------|
| 1 | {file_path} | Pending |
| 2 | {file_path} | Pending |
```

## Step 3: Merge each file

For each file in `backup-meta.json`:

1. **Read the backed-up version** (user's modified copy from `gsd-local-patches/`)
2. **Read the newly installed version** (current file after update)
3. **Compare and merge:**

   - If the new file is identical to the backed-up file: skip (modification was incorporated upstream)
   - If the new file differs: identify the user's modifications and apply them to the new version

   **Merge strategy:**
   - Read both versions fully
   - Identify sections the user added or modified (look for additions, not just differences from path replacement)
   - Apply user's additions/modifications to the new version
   - If a section the user modified was also changed upstream: flag as conflict, show both versions, ask user which to keep

4. **Write merged result** to the installed location
5. **Report status:**
   - `Merged` â€” user modifications applied cleanly
   - `Skipped` â€” modification already in upstream
   - `Conflict` â€” user chose resolution

## Step 4: Update manifest

After reapplying, regenerate the file manifest so future updates correctly detect these as user modifications:

```bash
# The manifest will be regenerated on next $gsd-update
# For now, just note which files were modified
```

## Step 5: Cleanup option

Ask user:
- "Keep patch backups for reference?" â†’ preserve `gsd-local-patches/`
- "Clean up patch backups?" â†’ remove `gsd-local-patches/` directory

## Step 6: Report

```
## Patches Reapplied

| # | File | Status |
|---|------|--------|
| 1 | {file_path} | âœ“ Merged |
| 2 | {file_path} | â—‹ Skipped (already upstream) |
| 3 | {file_path} | âš  Conflict resolved |

{count} file(s) updated. Your local modifications are active again.
```
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\reapply-patches.md
