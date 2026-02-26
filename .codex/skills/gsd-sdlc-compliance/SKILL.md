---
name: gsd-sdlc-compliance
description: Validate HIPAA/SOC2/GDPR/PCI compliance implementation against actual code Use when the user asks for 'gsd:sdlc-compliance', 'gsd-sdlc-compliance', or equivalent trigger phrases.
---

# Purpose
Validate that compliance requirements from Phase A are actually implemented in code. Scans the codebase for data encryption, audit logging, PII/PHI handling, access controls, and data subject rights.

The user chooses which standards to validate:
- **HIPAA**: PHI encryption, audit trails, minimum necessary access, emergency access
- **SOC 2 Type II**: Access controls, monitoring, incident response, data integrity
- **GDPR**: Consent management, data subject rights (access/delete/export), data minimization
- **PCI-DSS**: Cardholder data encryption, network segmentation, audit trails

Generates a compliance evidence report suitable for auditor review. Optionally auto-generates code fixes for common gaps.

# When to use
Use when the user requests the original gsd:sdlc-compliance flow (for example: $gsd-sdlc-compliance).
Also use on natural-language requests that match this behavior: Validate HIPAA/SOC2/GDPR/PCI compliance implementation against actual code

# Inputs
The user's text after invoking $gsd-sdlc-compliance is the arguments. Parse it into required fields; if any required field is missing, ask targeted follow-up questions.
Expected argument shape from source: [--standard <hipaa|soc2|gdpr|pci>] [--report-only] [--fix].
Context from source:
```text
Target: <parsed-arguments> (optional flags)

@.planning/STATE.md
@.planning/REQUIREMENTS.md
```

# Workflow
Load and follow these referenced artifacts first:
- @C:/Users/rjain/.codex/get-shit-done/workflows/sdlc-compliance.md
Then execute this process:
```text
Execute the sdlc-compliance workflow from @C:/Users/rjain/.codex/get-shit-done/workflows/sdlc-compliance.md end-to-end.
Read Phase A compliance declarations. Scan the full codebase for compliance patterns. Generate evidence report with pass/warn/fail per check and gap remediation steps.
```

# Outputs / artifacts
Produce the artifacts specified by the workflow and summarize created/updated files.

# Guardrails (what not to do / how to ask for missing info)
- Do not invent missing project files, phase numbers, or state; inspect the repo first.
- Do not skip validation or checkpoint gates described in referenced workflows.
- If required context is missing, ask focused questions (one small batch) and proceed after answers.

# Source (path to original Codex command file)
- C:\Users\rjain\.codex\commands\gsd\sdlc-compliance.md

