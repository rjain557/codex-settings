---
name: tj-sdlc-phase-c-deliverables
description: Generate Technijian SDLC v6.0 Phase C UI Prototyping and Full-Stack Code Generation deliverables. Use when asked for Phase C artifacts, Figma Make prompt, generated SQL and .NET and React outputs, storyboard docs, DTO validation, or build verification.
---

# Objective
Produce all Phase C outputs from approved Phase B artifacts and finalized Figma designs.

# Source Priority
1. Read `docs/sdlc/Phase_C_UI_Prototyping_Figma_Full_Stack_Generation.md`.
2. Cross-check `docs/sdlc/01_Technijian_SDLC_v6_0.md` for phase gates.
3. If local docs are missing, use `technijian-usa/tech-sdlc/docs/sdlc/Phase_C_UI_Prototyping_Figma_Full_Stack_Generation.md`.

# Required Inputs
- Approved Phase B architecture pack and OpenAPI draft.
- Phase A NFRs and RBAC rules.
- Design system constraints and branding.
- Figma storyboard/screens for all planned routes.

# Technology Requirements
- Backend: .NET 8 Web API
- Data access: Dapper with stored procedures only (SPOnly)
- Database: SQL Server
- Frontend: React 18 + TypeScript
- API docs: Swagger/OpenAPI
- No Entity Framework

# Deliverables To Generate
- `docs/spec/figma-make-prompt.md`
- `docs/spec/phase-c-design-critique.md`
- `generated/sql/schema.sql`
- `generated/sql/programmability.sql`
- `generated/sql/procedures.sql`
- `generated/sql/seed.sql`
- `generated/backend/<ProjectName>/...`
- `generated/frontend/...`
- `design/storyboard/screens/*`
- `design/storyboard/README.md`
- `design/accessibility.md`
- `design/copy-deck.md`
- `docs/spec/phase-c-dto-validation-report.md`
- `docs/spec/phase-c-build-verification.md`

# Workflow
1. Verify entrance criteria: Phase B approved, OpenAPI draft exists, design system available, RBAC defined.
2. Create and complete the Figma Make prompt from Phase A and B artifacts.
3. Generate and refine Figma screens and validate five states per screen: Default, Empty, Loading, Error, Forbidden.
4. Run AI design critique for WCAG, NFR, architecture, and responsive gaps.
5. Generate SQL artifacts (`schema.sql`, `programmability.sql`, `procedures.sql`, `seed.sql`) with idempotent SP-first patterns.
6. Generate .NET 8 backend with models, DTOs, services, controllers, Program configuration, logging, and auth.
7. Generate React 18 frontend with typed API client, route pages, state handling, and accessibility.
8. Export storyboard assets and supporting docs.
9. Run mandatory DTO and controller consistency validation:
- DTO naming conventions
- Controller to DTO references
- Required property completeness
- Duplicate class detection
- Exact DTO to model property/type/nullability matching
10. Run mandatory build verification:
- `dotnet restore` then `dotnet build`
- `npm install` then `npm run build`
11. Record failures and fixes before handoff.

# Exit Gate Checks
- Figma prompt is complete and stored.
- Screens and five states are complete.
- Generated SQL, backend, and frontend outputs exist.
- Storyboard docs exist.
- DTO validation passes with zero critical failures.
- Build verification succeeds for backend and frontend.
- Human design and code sign-off is recorded.

# Guardrails
- Do not skip DTO validation or build verification.
- Do not use Entity Framework or direct table queries in API services.
- Do not proceed to Phase D without sign-off and passing gates.
