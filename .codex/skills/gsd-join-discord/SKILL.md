---
name: gsd-join-discord
description: Join the GSD Discord community Use when the user asks for 'gsd:join-discord', 'gsd-join-discord', or equivalent trigger phrases.
---

# Purpose
Display the Discord invite link for the GSD community server.

# When to use
Use when the user requests the original gsd:join-discord flow (for example: $gsd-join-discord).
Also use on natural-language requests that match this behavior: Join the GSD Discord community

# Inputs
No required positional arguments. If the request lacks needed context, ask concise targeted questions before proceeding.

# Workflow
Execute the original command behavior end-to-end, preserving validation, routing, and update gates.

# Outputs / artifacts
Primary output format from source:
```text
# Join the GSD Discord

Connect with other GSD users, get help, share what you're building, and stay updated.

**Invite link:** https://discord.gg/5JJgD5svVS

Click the link or paste it into your browser to join.
```

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\join-discord.md
