<purpose>
Validate that compliance requirements declared in Phase A (Requirements) are actually implemented in the codebase. Checks HIPAA, SOC2, GDPR, and PCI-DSS compliance flags against actual code patterns for data encryption, audit logging, PII/PHI handling, access controls, and data retention.

Fills the Phase A-to-F compliance gap in Technijian SDLC v6.0 by providing automated compliance evidence gathering and violation detection.
</purpose>

<core_principle>
Compliance is not a checkbox -- it's verified in code. Every compliance requirement from Phase A must have a traceable implementation in the codebase. This skill scans the actual code, not documentation, to produce evidence of compliance or flag gaps.
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read Phase A requirements or REQUIREMENTS.md for declared compliance flags.
Read any existing compliance documentation in docs/compliance/.
Scan the full codebase for compliance-relevant patterns.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone
2. Read REQUIREMENTS.md or Phase A output for declared compliance standards
3. Check for existing compliance docs in `docs/compliance/`
4. Detect tech stack for framework-specific checks (ASP.NET Core, React, SQL Server)
5. Check for existing security configuration (auth, encryption, logging)

Parse arguments:
- `$ARGUMENTS` may contain: `--standard <hipaa|soc2|gdpr|pci>`, `--report-only`, `--fix`
- `--report-only`: Generate report without suggesting fixes
- `--fix`: Auto-generate missing compliance code where possible
</step>

<step name="ask_standards">
If not specified in arguments:

```
AskUserQuestion(
  header="Standards",
  question="Which compliance standards should be validated?",
  multiSelect=true,
  options=[
    {
      label: "HIPAA (Recommended)",
      description: "Health data protection. Checks: PHI encryption at rest/transit, audit logging, access controls, BAA-ready architecture, minimum necessary access."
    },
    {
      label: "SOC 2 Type II",
      description: "Service organization controls. Checks: access controls, change management, monitoring, incident response, data integrity, availability."
    },
    {
      label: "GDPR",
      description: "EU data protection. Checks: consent management, data subject rights (access/delete/export), data minimization, privacy by design, DPA-ready."
    },
    {
      label: "PCI-DSS",
      description: "Payment card security. Checks: cardholder data encryption, network segmentation, access controls, vulnerability management, audit trails."
    }
  ]
)
```

Store as `STANDARDS[]`.
</step>

<step name="scan_codebase">
Scan the entire codebase for compliance-relevant patterns. Run checks in parallel where possible:

**1. Data Encryption**
- [ ] HTTPS enforcement (check middleware, Kestrel config, HSTS headers)
- [ ] TLS 1.2+ minimum (check SSL/TLS configuration)
- [ ] Encryption at rest (check database encryption settings, column-level encryption)
- [ ] Sensitive field encryption in code (check for encrypt/decrypt patterns on PII/PHI fields)
- [ ] Key management (check for hardcoded keys, proper key vault usage)
- [ ] Connection string encryption (not plaintext in appsettings)

**2. Audit Logging**
- [ ] All data mutations logged (check for audit trail on Create/Update/Delete)
- [ ] Audit includes: who, what, when, from where (userId, action, timestamp, IP)
- [ ] Audit logs are immutable (append-only, no DELETE on audit tables)
- [ ] Audit log retention policy defined
- [ ] Failed access attempts logged
- [ ] Admin actions logged separately

**3. PII/PHI Handling**
- [ ] PII fields identified and documented (name, email, phone, SSN, DOB, etc.)
- [ ] PII not logged (check Serilog/logging config for PII masking)
- [ ] PII not in URLs or query strings
- [ ] PII not in error messages returned to clients
- [ ] PII not in client-side storage (localStorage, cookies) without encryption
- [ ] PHI fields have additional access controls (if HIPAA)
- [ ] Data masking for non-production environments

**4. Access Controls**
- [ ] All API endpoints have `[Authorize]` attribute (except explicitly public)
- [ ] Role-based access control (RBAC) implemented
- [ ] TenantId isolation on all database queries (multi-tenancy)
- [ ] Session management (timeout, concurrent session limits)
- [ ] Password policy enforcement (if applicable)
- [ ] MFA support (if applicable)

**5. Data Subject Rights** (GDPR specific)
- [ ] Right to access: API endpoint to export user data
- [ ] Right to deletion: API endpoint to delete user data (with cascade)
- [ ] Right to portability: Data export in machine-readable format
- [ ] Consent management: Consent records stored and queryable
- [ ] Data retention: Automated deletion after retention period

**6. Input Validation**
- [ ] All DTOs have validation attributes (Required, MaxLength, etc.)
- [ ] SQL injection prevention (parameterized queries only -- SPOnly pattern helps here)
- [ ] XSS prevention (output encoding, CSP headers)
- [ ] CSRF protection (anti-forgery tokens)
- [ ] File upload validation (type, size, content scanning)

**7. Infrastructure Security**
- [ ] CORS properly configured (not wildcard in production)
- [ ] Security headers (X-Content-Type-Options, X-Frame-Options, CSP, etc.)
- [ ] Rate limiting on auth endpoints
- [ ] API versioning (no breaking changes without deprecation)
- [ ] Error handling doesn't leak stack traces or internal details
</step>

<step name="check_hipaa">
If HIPAA is in STANDARDS[]:

**HIPAA-specific checks:**
- [ ] PHI inventory documented (what PHI is collected, where stored, who accesses)
- [ ] Minimum necessary access (users only see PHI they need for their role)
- [ ] PHI encryption at rest (database TDE or column-level encryption)
- [ ] PHI encryption in transit (TLS 1.2+ on all PHI transfers)
- [ ] Audit trail on all PHI access (read AND write, not just mutations)
- [ ] Emergency access procedure (break-glass mechanism)
- [ ] Automatic logoff (session timeout configurable per tenant)
- [ ] Unique user identification (no shared accounts)
- [ ] Media disposal procedure documented (for data at rest)
- [ ] Backup and recovery tested

**HIPAA code patterns to search for:**
```
// Good: PHI access audit
[AuditAccess(PhiCategory.Demographics)]
public async Task<PatientDto> GetPatient(string id)

// Bad: PHI in log
_logger.LogInformation("Patient {Name} SSN {SSN}", patient.Name, patient.SSN);

// Bad: PHI in error response
return BadRequest($"Patient {patient.Name} not found");
```
</step>

<step name="check_soc2">
If SOC2 is in STANDARDS[]:

**SOC 2 Trust Service Criteria checks:**

**Security (CC6):**
- [ ] Logical access controls with role-based permissions
- [ ] Authentication mechanisms (MFA, SSO)
- [ ] Network security (firewall rules, VPN for admin)
- [ ] Vulnerability management (dependency scanning)

**Availability (A1):**
- [ ] Health check endpoints
- [ ] Monitoring and alerting configuration
- [ ] Backup and recovery procedures
- [ ] Incident response plan documented

**Processing Integrity (PI1):**
- [ ] Input validation on all data entry points
- [ ] Data integrity checks (checksums, reconciliation)
- [ ] Error handling with retry logic

**Confidentiality (C1):**
- [ ] Data classification (public, internal, confidential, restricted)
- [ ] Encryption for confidential data
- [ ] Access logging for confidential data

**Privacy (P1-P8):**
- [ ] Privacy notice/policy
- [ ] Consent collection and management
- [ ] Data retention and disposal
</step>

<step name="check_gdpr">
If GDPR is in STANDARDS[]:

**GDPR Article compliance checks:**

**Lawful basis (Art. 6):**
- [ ] Consent collection mechanism exists
- [ ] Consent records stored with timestamp and scope
- [ ] Legitimate interest documented for non-consent processing

**Data subject rights (Art. 15-22):**
- [ ] Art. 15: Right of access (data export endpoint)
- [ ] Art. 16: Right to rectification (data update endpoint)
- [ ] Art. 17: Right to erasure (data deletion with cascade)
- [ ] Art. 18: Right to restrict processing (account suspension)
- [ ] Art. 20: Right to portability (machine-readable export: JSON/CSV)
- [ ] Art. 21: Right to object (opt-out mechanism)

**Privacy by design (Art. 25):**
- [ ] Data minimization (only collect what's needed)
- [ ] Purpose limitation (data used only for stated purpose)
- [ ] Storage limitation (auto-delete after retention period)
- [ ] Default privacy settings (opt-in, not opt-out)

**Data breach (Art. 33-34):**
- [ ] Breach detection mechanism (anomaly detection, alerts)
- [ ] Breach notification procedure documented
- [ ] Breach logging and evidence preservation

**Cross-border (Art. 44-49):**
- [ ] Data residency configuration (EU data stays in EU)
- [ ] Transfer mechanism documented (SCC, adequacy decision)
</step>

<step name="generate_report">
Generate compliance evidence report:

```
docs/compliance/
  compliance-report-{date}.md          # Main report
  evidence/
    encryption-evidence.md             # Encryption implementation evidence
    audit-logging-evidence.md          # Audit trail evidence
    access-control-evidence.md         # Access control evidence
    pii-handling-evidence.md           # PII/PHI handling evidence
    data-rights-evidence.md            # Data subject rights evidence (if GDPR)
  gaps/
    compliance-gaps.md                 # Identified gaps with remediation steps
```

**Report format:**
```markdown
# Compliance Validation Report

**Date**: {date}
**Standards**: {HIPAA, SOC2, GDPR, PCI-DSS}
**Project**: {project name}
**Score**: {pass_count}/{total_checks} checks passed ({percentage}%)

## Summary

| Standard | Passed | Warnings | Failed | Score |
|----------|--------|----------|--------|-------|
| HIPAA    | 15     | 3        | 2      | 75%   |
| SOC 2    | 20     | 5        | 1      | 77%   |
| GDPR     | 12     | 4        | 4      | 60%   |

## Critical Findings

### FAILED: PHI in log output
**Standard**: HIPAA
**Severity**: Critical
**Location**: src/Server/Services/PatientService.cs:42
**Finding**: Patient name logged in plaintext via _logger.LogInformation
**Remediation**: Use Serilog destructuring with [NotLogged] attribute or mask PII fields
**Evidence**: {code snippet}

### FAILED: No data deletion endpoint
**Standard**: GDPR Art. 17
**Severity**: High
**Location**: N/A (missing implementation)
**Finding**: No API endpoint for user data deletion (right to erasure)
**Remediation**: Add DELETE /api/users/{id}/data endpoint with cascade deletion SP

## Passed Checks (Evidence)

### PASSED: HTTPS enforcement
**Standard**: HIPAA, SOC2, GDPR, PCI
**Evidence**: src/Server/Program.cs:15 -- app.UseHttpsRedirection()
**Evidence**: src/Server/Program.cs:22 -- app.UseHsts()

{... more checks ...}

## Warnings

### WARNING: Audit log retention not configured
**Standard**: HIPAA, SOC2
**Finding**: Audit logs exist but no retention policy or auto-archival configured
**Recommendation**: Add scheduled job to archive audit logs older than {retention period}
```
</step>

<step name="generate_fixes">
If `--fix` flag is set, auto-generate code fixes for common gaps:

**PII masking in logs:**
- Generate Serilog destructuring policy that masks PII fields
- Generate `[NotLogged]` attribute for sensitive DTO properties

**Missing [Authorize]:**
- Add `[Authorize]` to controllers missing it
- Generate a code review checklist for manual verification

**Missing audit logging:**
- Generate audit logging middleware/action filter
- Generate audit table migration if not exists

**Missing data export endpoint:**
- Generate data export controller and SP
- Generate data deletion controller and SP (with cascade)

**Missing security headers:**
- Generate security headers middleware

Note: Auto-fixes are generated as separate files for review, not applied directly.
</step>

<step name="commit_and_report">
Commit generated report:

```bash
git add docs/compliance/
git commit -m "docs: generate compliance validation report ({standards})"
```

Report:
```
## Compliance Validation Complete

**Standards**: {HIPAA | SOC2 | GDPR | PCI-DSS}
**Overall Score**: {percentage}%

| Category | Status |
|----------|--------|
| Encryption | {Pass/Warn/Fail} |
| Audit Logging | {Pass/Warn/Fail} |
| PII/PHI Handling | {Pass/Warn/Fail} |
| Access Controls | {Pass/Warn/Fail} |
| Data Subject Rights | {Pass/Warn/Fail} |
| Input Validation | {Pass/Warn/Fail} |
| Infrastructure | {Pass/Warn/Fail} |

### Critical Gaps ({count})
{List of failed checks with file locations}

### Report Location
docs/compliance/compliance-report-{date}.md

### Next Steps
1. Review critical findings in the report
2. Address FAILED items (prioritize by severity)
3. Review WARNING items for risk acceptance or remediation
4. Re-run /gsd:sdlc-compliance after fixes to verify
5. Archive report as compliance evidence for auditors
```
</step>

</process>

<success_criteria>
- [ ] All declared compliance standards checked against actual code
- [ ] Encryption at rest and in transit verified
- [ ] Audit logging coverage validated
- [ ] PII/PHI handling checked (no PII in logs, URLs, error responses)
- [ ] Access controls verified ([Authorize], RBAC, TenantId isolation)
- [ ] Data subject rights implementation checked (if GDPR)
- [ ] Compliance report generated with evidence and gaps
- [ ] Gap remediation steps documented with code locations
- [ ] Report suitable for auditor review
</success_criteria>

<failure_handling>
- **No Phase A requirements found**: Ask user to declare applicable compliance standards manually
- **No codebase to scan**: Error -- compliance validation requires existing code
- **Mixed results**: Generate report with partial results; flag unchecked items
- **Unknown compliance standard requested**: Warn and skip; only validate known standards
- **Large codebase timeout**: Split scan into parallel sub-scans by layer (frontend, backend, database)
</failure_handling>

