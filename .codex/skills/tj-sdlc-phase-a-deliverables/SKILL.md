---
name: tj-sdlc-phase-a-deliverables
description: Generate Technijian SDLC v6.0 Phase A Intake and Requirements deliverables (Intake Pack). Use when asked for Phase A artifacts, intake brief, stakeholder RACI, data classification, NFRs, risk register, dependency inventory, environment identities, or draft acceptance criteria.
---

# Objective
Produce a complete Phase A Intake Pack and confirm entrance and exit criteria.

# Source Priority
1. Read `docs/sdlc/Phase_A_Intake_Requirements.md`.
2. Cross-check `docs/sdlc/01_Technijian_SDLC_v6_0.md` for phase gates.
3. If local docs are missing, use `technijian-usa/tech-sdlc/docs/sdlc/Phase_A_Intake_Requirements.md`.

# Required Inputs
- Sponsor, product lead, engineering lead, and project name.
- Intake ticket, email thread, transcript, or notes.
- Constraints (timeline, budget, compliance, systems).
- Known actors and workflows.

# Output Root
Default to `docs/spec/phase-a/`.
If the repository already uses an established convention, preserve that convention.

# Deliverables To Generate
- `intake-brief.md`
- `stakeholders-raci.md`
- `data-classification-regulatory-scope.md`
- `domain-operations-rbac-sketch.md`
- `nfrs.md`
- `environments-seeded-identities-plan.md`
- `dependency-inventory.md`
- `risk-register.md`
- `acceptance-criteria-draft.md`
- `phase-a-exit-checklist.md`

# Workflow
1. Verify entrance criteria: sponsor identified, leads assigned, intake ticket exists.
2. Transform discovery inputs into an intake brief with problem statement, outcomes, success metrics, scope, and out-of-scope.
3. Build stakeholder and RACI coverage with ownership and approvers.
4. Produce data classification and regulatory scope (HIPAA, SOC2, GDPR, PCI where applicable).
5. Draft domain operations and RBAC sketch by actor and access level.
6. Draft NFRs for security, compliance, performance, availability, accessibility, and observability.
7. Produce dependency inventory and initial risk register with likelihood, impact, mitigation, and owner.
8. Generate Gherkin-style acceptance criteria draft for major operations.
9. Add explicit principle commitment in intake artifacts: API-First, SPOnly, Contract-First.
10. Produce exit checklist evidence with DoSE and Product Lead approval placeholders.

# Exit Gate Checks
- Intake Pack is complete and internally consistent.
- Regulatory scope and baseline risk register exist.
- Core principles are explicitly affirmed.
- Approval placeholders exist for DoSE and Product Lead.
- Missing information is listed as open questions.

# Guardrails
- Do not start architecture design in this phase.
- Do not write implementation code.
- Do not mark Phase A complete if any required artifact is missing.
