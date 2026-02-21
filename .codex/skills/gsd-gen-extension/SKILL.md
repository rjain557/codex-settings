---
name: gsd-gen-extension
description: Generate cross-browser extension (Chrome/Edge/Safari) with Manifest V3 Use when the user asks for 'gsd:gen-extension', 'gsd-gen-extension', or equivalent trigger phrases.
---

# Purpose
Generate a cross-browser extension that runs on Chrome, Edge, and Safari. Uses Manifest V3 with a shared TypeScript codebase and browser-specific build targets.

The user chooses the extension type:
- **Popup**: Toolbar icon with popup panel (like 1Password)
- **Side panel**: Full-height sidebar alongside pages (like Claude sidebar)
- **Content script only**: Injects into pages with no visible UI (like Dark Reader)
- **Full extension**: All components (popup, side panel, content scripts, options)

Default: generates for all three browsers. Pass a browser name to target one.

# When to use
Use when the user requests the original gsd:gen-extension flow (for example: $gsd-gen-extension).
Also use on natural-language requests that match this behavior: Generate cross-browser extension (Chrome/Edge/Safari) with Manifest V3

# Inputs
The user's text after invoking $gsd-gen-extension is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [chrome|edge|safari] [--name <extension-name>] [--api-url <url>].
Context from source:
```text
Target: <parsed-arguments> (optional: chrome, edge, safari, or blank for all)

@.planning/STATE.md
@docs/spec/openapi.yaml
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/gen-extension.md
Then execute this process:
```text
Execute the gen-extension workflow from @C:/Users/rjain/.claude/get-shit-done/workflows/gen-extension.md end-to-end.
Ask the extension type and UI framework questions before generating. Generate shared core + browser-specific manifests and build targets.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\gen-extension.md
