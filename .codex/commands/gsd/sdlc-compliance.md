---
name: gsd:sdlc-compliance
description: Validate HIPAA/SOC2/GDPR/PCI compliance implementation against actual code
argument-hint: "[--standard <hipaa|soc2|gdpr|pci>] [--report-only] [--fix]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
  - AskUserQuestion
---
<objective>
Validate that compliance requirements from Phase A are actually implemented in code. Scans the codebase for data encryption, audit logging, PII/PHI handling, access controls, and data subject rights.

The user chooses which standards to validate:
- **HIPAA**: PHI encryption, audit trails, minimum necessary access, emergency access
- **SOC 2 Type II**: Access controls, monitoring, incident response, data integrity
- **GDPR**: Consent management, data subject rights (access/delete/export), data minimization
- **PCI-DSS**: Cardholder data encryption, network segmentation, audit trails

Generates a compliance evidence report suitable for auditor review. Optionally auto-generates code fixes for common gaps.
</objective>

<execution_context>
@C:/Users/rjain/.codex/get-shit-done/workflows/sdlc-compliance.md
</execution_context>

<context>
Target: $ARGUMENTS (optional flags)

@.planning/STATE.md
@.planning/REQUIREMENTS.md
</context>

<process>
Execute the sdlc-compliance workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/sdlc-compliance.md end-to-end.
Read Phase A compliance declarations. Scan the full codebase for compliance patterns. Generate evidence report with pass/warn/fail per check and gap remediation steps.
</process>

