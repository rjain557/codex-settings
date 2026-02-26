---
name: tj-sdlc-phase-d-deliverables
description: Generate Technijian SDLC v6.0 Phase D Business and Design Approval deliverables. Use when asked for Phase D artifacts, frozen blueprint, route inventory, alignment report, environment identity plan, acceptance criteria, or decision log and open questions.
---

# Objective
Freeze the UI and UX baseline and produce all Phase D approval artifacts for handoff to Phase E.

# Source Priority
1. Read `docs/sdlc/Phase_D_Business_Design_Approval.md`.
2. Use `docs/sdlc/Phase_D_Acceptance_Criteria.md` and other `Phase_D_*` examples for output style.
3. Cross-check `docs/sdlc/01_Technijian_SDLC_v6_0.md` for phase gates.
4. If local docs are missing, use `technijian-usa/tech-sdlc/docs/sdlc/Phase_D_Business_Design_Approval.md`.

# Required Inputs
- Phase C generated outputs and storyboard.
- Phase A requirements and Phase B architecture.
- AI critique and Phase C validation reports.
- Stakeholder list for approvals (Product Lead, UX Owner, TArch).

# Deliverables To Generate
- `docs/spec/phase-d/phase-d-alignment-report.md`
- `docs/spec/ui-contract-draft.csv`
- `docs/spec/phase-d/phase-d-blueprint.md`
- `docs/spec/phase-d/phase-d-environment-identity-plan.md`
- `docs/spec/phase-d/phase-d-acceptance-criteria.md`
- `docs/spec/phase-d/phase-d-decisions-questions.md`
- `docs/spec/phase-d/phase-d-signoff.md`

# Route Inventory Schema
`ui-contract-draft.csv` must include these columns:
- `route_id`
- `url`
- `screen_name`
- `roles_scopes_planned`
- `states_planned`
- `layout_shell`
- `notes`

# Workflow
1. Verify entrance criteria: Phase C complete, generated code exists, critique passed, owners assigned.
2. Generate alignment report comparing requirements and architecture to generated frontend, backend, and SQL artifacts.
3. Extract full route inventory from storyboard and generated routes/endpoints.
4. Build frozen blueprint with navigation hierarchy, screen inventory, component inventory, theming, and accessibility constraints.
5. Draft environment and identity plan (DEV/ALPHA/BETA/PROD, seeded users, SSO requirements, promotion path).
6. Generate Gherkin acceptance criteria per major route covering happy, empty, error, and forbidden behavior.
7. Capture decision log (`D-xxx`) and open questions (`Q-xxx`) with owners and due phases.
8. Produce sign-off record for Product Lead, UX Owner, and TArch.

# Exit Gate Checks
- Frozen blueprint exists and is approval-ready.
- Route inventory covers all Figma screens/routes.
- Alignment report findings are reviewed and dispositioned.
- Environment and identity plan is complete.
- Acceptance criteria exist for major routes/features.
- Approval signatures or pending owners/dates are recorded.

# Guardrails
- Do not modify generated implementation code in this phase.
- Do not freeze OpenAPI or stored procedure signatures here (that is Phase E).
- Do not skip alignment validation.
