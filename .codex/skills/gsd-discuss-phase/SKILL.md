---
name: gsd-discuss-phase
description: Gather phase context through adaptive questioning before planning Use when the user asks for 'gsd:discuss-phase', 'gsd-discuss-phase', or equivalent trigger phrases.
---

# Purpose
Extract implementation decisions that downstream agents need â€” researcher and planner will use CONTEXT.md to know what to investigate and what choices are locked.

**How it works:**
1. Analyze the phase to identify gray areas (UI, UX, behavior, etc.)
2. Present gray areas â€” user selects which to discuss
3. Deep-dive each selected area until satisfied
4. Create CONTEXT.md with decisions that guide research and planning

**Output:** `{phase}-CONTEXT.md` â€” decisions clear enough that downstream agents can act without asking the user again

# When to use
Use when the user requests the original gsd:discuss-phase flow (for example: $gsd-discuss-phase).
Also use on natural-language requests that match this behavior: Gather phase context through adaptive questioning before planning

# Inputs
The user's text after invoking $gsd-discuss-phase is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: <phase>.
Context from source:
```text
Phase number: <parsed-arguments> (required)

**Load project state:**
@.planning/STATE.md

**Load roadmap:**
@.planning/ROADMAP.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.claude/get-shit-done/workflows/discuss-phase.md
- @C:/Users/rjain/.claude/get-shit-done/templates/context.md
Then execute this process:
```text
1. Validate phase number (error if missing or not in roadmap)
2. Check if CONTEXT.md exists (offer update/view/skip if yes)
3. **Analyze phase** â€” Identify domain and generate phase-specific gray areas
4. **Present gray areas** â€” Multi-select: which to discuss? (NO skip option)
5. **Deep-dive each area** â€” 4 questions per area, then offer more/next
6. **Write CONTEXT.md** â€” Sections match areas discussed
7. Offer next steps (research or plan)

**CRITICAL: Scope guardrail**
- Phase boundary from ROADMAP.md is FIXED
- Discussion clarifies HOW to implement, not WHETHER to add more
- If user suggests new capabilities: "That's its own phase. I'll note it for later."
- Capture deferred ideas â€” don't lose them, don't act on them

**Domain-aware gray areas:**
Gray areas depend on what's being built. Analyze the phase goal:
- Something users SEE â†’ layout, density, interactions, states
- Something users CALL â†’ responses, errors, auth, versioning
- Something users RUN â†’ output format, flags, modes, error handling
- Something users READ â†’ structure, tone, depth, flow
- Something being ORGANIZED â†’ criteria, grouping, naming, exceptions

Generate 3-4 **phase-specific** gray areas, not generic categories.

**Probing depth:**
- Ask 4 questions per area before checking
- "More questions about [area], or move to next?"
- If more â†’ ask 4 more, check again
- After all areas â†’ "Ready to create context?"

**Do NOT ask about (Claude handles these):**
- Technical implementation
- Architecture choices
- Performance concerns
- Scope expansion
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Claude command file)
- C:\Users\rjain\.claude\commands\gsd\discuss-phase.md
