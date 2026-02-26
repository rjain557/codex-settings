---
name: tj-sdlc-phase-e-deliverables
description: Generate Technijian SDLC v6.0 Phase E Contract Freeze (SCG1) deliverables. Use when asked for Phase E artifacts, final UI contract, OpenAPI, API-to-SP map, DB plan, test plan, contract validation report, CI gates, or SCG1 sign-off.
---

# Objective
Freeze the single contract pack and produce SCG1-ready evidence.

# Source Priority
1. Read `docs/sdlc/Phase_E_Contract_Freeze.md`.
2. Cross-check `docs/sdlc/01_Technijian_SDLC_v6_0.md` for phase gates.
3. If local docs are missing, use `technijian-usa/tech-sdlc/docs/sdlc/Phase_E_Contract_Freeze.md`.

# Required Inputs
- Approved Phase D blueprint and `ui-contract-draft.csv`.
- Phase C generated outputs in `generated/sql`, `generated/backend`, and `generated/frontend`.
- Phase B architecture pack.
- Assigned approvers (TArch, SecOps, Product Lead, DoSE).

# Output Files
All files are required under `docs/spec/`:
- `ui-contract.csv`
- `openapi.yaml`
- `apitospmap.csv`
- `db-plan.md`
- `test-plan.md`
- `ci-gates.md`
- `validation-report.md`
- `scg1-signoff.md` (or equivalent tracker record link)

# UI Contract Schema
`ui-contract.csv` columns:
- `route_id`
- `url`
- `screen_name`
- `roles_scopes`
- `layout_shell`
- `components`
- `view_model_schema`
- `actions`
- `states`
- `notes`

# API-to-SP Map Schema
`apitospmap.csv` columns:
- `method`
- `path`
- `operationId`
- `sp_name`
- `sp_params`
- `sp_resultshape`
- `transaction`
- `roles_scopes`
- `tenant_rule`
- `pagination`
- `error_cases`

# Workflow
1. Verify entrance criteria: Phase D complete, route inventory exists, generated outputs exist, architecture pack available, owners assigned.
2. Finalize OpenAPI from UI contract and ensure stable operationIds with full response and error coverage.
3. Generate API-to-SP map with 100 percent operation coverage and explicit tenant/auth rules.
4. Generate DB plan for entities, tables, views, SPs, UDFs, indexes, and constraints.
5. Generate test plan across unit, contract, integration, end-to-end, accessibility, and performance.
6. Validate generated code against frozen contract:
- SQL vs DB plan and API-to-SP map
- Controllers/services vs OpenAPI and SPOnly rule
- DTO-model exact property/type/nullability match
- UI routes/states vs UI contract
7. Produce CI and security gates document (SPOnly enforcement, typed-client drift, spec sync, security scans, contract checks).
8. Build SCG1 checklist and sign-off record with approver names, roles, and dates.

# Exit Gate Checks
- UI contract frozen and committed.
- OpenAPI frozen and committed.
- API-to-SP map has 100 percent coverage.
- DB plan approved.
- Test plan complete.
- CI and security gates defined.
- Validation report reviewed with gaps tracked for Phase F.
- SCG1 sign-off recorded by TArch, SecOps, Product Lead, and DoSE.

# Guardrails
- Do not write production implementation code in this phase.
- Do not modify generated code except for validation evidence.
- Do not proceed to Phase F before SCG1 is complete.
