---
name: tj-sdlc-phase-b-deliverables
description: Generate Technijian SDLC v6.0 Phase B Specification and Architecture Pack deliverables. Use when asked for Phase B artifacts, architecture pack, context and sequence and data-flow diagrams, OpenAPI draft, threat model, data model inventory, or architecture plans.
---

# Objective
Produce a complete Phase B Architecture Pack from approved Phase A outputs.

# Source Priority
1. Read `docs/sdlc/Phase_B_Specification_Architecture_Pack.md`.
2. Cross-check `docs/sdlc/01_Technijian_SDLC_v6_0.md` for phase gates.
3. If local docs are missing, use `technijian-usa/tech-sdlc/docs/sdlc/Phase_B_Specification_Architecture_Pack.md`.

# Required Inputs
- Approved Phase A intake artifacts.
- Domain operations and RBAC sketch.
- NFRs and risk register.
- Known external systems and trust boundaries.

# Output Root
Default to `docs/spec/phase-b/`.

# Deliverables To Generate
- `diagrams/system-context.mmd`
- `diagrams/component.mmd`
- `diagrams/sequence-<flow>.mmd` for each major flow
- `diagrams/data-flow.mmd`
- `threat-model-mitigation-plan.md`
- `openapi-draft.yaml`
- `data-model-inventory.md`
- `security-quality-operations-plan.md`
- `promotion-rollback-model.md`
- `observability-plan.md`
- `architecture-decision-records.md`
- `phase-b-exit-checklist.md`

# Workflow
1. Verify entrance criteria: Phase A complete and owners identified (TArch, Product, SecOps).
2. Generate system context and component diagrams as code (Mermaid or PlantUML).
3. Generate sequence diagrams for critical use cases including auth and error paths (401, 403, 500).
4. Generate data-flow diagram with trust boundaries and sensitive data movement.
5. Draft OpenAPI 3.0 spec from Phase A domain operations, including bearer auth and standard error responses.
6. Generate STRIDE threat model with top risks and concrete mitigations.
7. Build data model inventory aligned to operations and API schemas.
8. Draft security, quality, operations, promotion and rollback, and observability plans.
9. Record architecture decisions and unresolved items in ADR format.
10. Produce exit checklist with required approvals (TArch, SecOps, DoSE).

# Exit Gate Checks
- Architecture Pack exists with all required artifacts.
- Architecture is traceable back to Phase A requirements.
- API-First and SPOnly constraints are reflected.
- Approvals are captured or explicitly pending with owners and dates.
- No critical unresolved risk is hidden.

# Guardrails
- Do not begin UI build or generated code tasks in this phase.
- Do not skip threat modeling.
- Do not produce an OpenAPI draft without sequence and data-flow context.
