# OOPS Production Org Enablement Guide

## Purpose
This guide describes how to allow OOPS masking execution in a production org safely.

## Current Status (Implemented)
The following items are implemented in code:
- Production-aware authorization method added in `force-app/main/default/classes/OOPS_Authorization.cls`:
  - `assertExecutionAllowedForEnvironment()`
  - Requires `Execute_OOPS_In_Production` permission in production
  - Requires `OOPSSettings__c.ProductionExecutionEnabled__c == true` in production
- Run launch guard updated in `force-app/main/default/classes/OOPS_RunService.cls`:
  - `launchExecution()` now calls `assertExecutionAllowedForEnvironment()`
- Production confirmation modal added in `force-app/main/default/lwc/oopsRunConsole/oopsRunConsole.js`:
  - When Execute Masking is pressed in production, user must explicitly confirm before execution proceeds
- Environment check endpoint exposed for LWC in `force-app/main/default/classes/OOPS_RunController.cls`:
  - `isSandboxEnvironment()`

Current behavior blocks execution in production by design:
- force-app/main/default/classes/OOPS_Authorization.cls
- Method: assertSandboxOnlyExecution()

Execution call site:
- force-app/main/default/classes/OOPS_RunService.cls
- Method: launchExecution()

## Recommended Enablement Approach
Use a feature-flagged guard instead of removing all safety checks.

### Target Behavior
Allow execution in production only when all conditions are true:
1. User has Execute_OOPS.
2. User has Execute_OOPS_In_Production.
3. Org-level setting explicitly enables production execution.
4. Optional: additional confirmation requirement from settings.

## Implementation Steps

### 1) Add authorization method for production gating
File:
- force-app/main/default/classes/OOPS_Authorization.cls

Add a method such as:
- assertExecutionAllowedForEnvironment()

Logic:
- If sandbox: allow with Execute_OOPS.
- If production:
  - require Execute_OOPS_In_Production custom permission
  - require OOPSSettings__c.ProductionExecutionEnabled__c == true
  - throw OOPS_ConfigurationException with explicit message when blocked

Note:
- Keep assertExecutePermission() call in place.

Status:
- Completed.

### 2) Replace sandbox-only guard in run launch path
File:
- force-app/main/default/classes/OOPS_RunService.cls

In launchExecution():
- Replace OOPS_Authorization.assertSandboxOnlyExecution();
- With OOPS_Authorization.assertExecutionAllowedForEnvironment();

Status:
- Completed.

### 2a) Add production confirmation in Run Console
Files:
- force-app/main/default/lwc/oopsRunConsole/oopsRunConsole.js
- force-app/main/default/classes/OOPS_RunController.cls

Behavior:
- Execute Masking click checks org environment.
- If production, show a confirmation modal.
- Execution proceeds only when user confirms.

Status:
- Completed.

### 3) Keep permissions principle-of-least-privilege
Metadata to verify:
- force-app/main/default/customPermissions/Execute_OOPS_In_Production.customPermission-meta.xml
- force-app/main/default/permissionsets/OOPS_Production_Operator.permissionset-meta.xml

Recommendations:
- Only assign OOPS_Production_Operator to approved operators.
- Do not include Execute_OOPS_In_Production in broad admin/configurator profiles unless intended.

### 4) Confirm org setting path
Metadata already present:
- force-app/main/default/objects/OOPSSettings__c/fields/ProductionExecutionEnabled__c.field-meta.xml
- force-app/main/default/layouts/OOPSSettings__c-OOPS Settings Layout.layout-meta.xml

Recommendations:
- Default ProductionExecutionEnabled__c to false.
- Require explicit change control to set true.
- Track who enabled it and when.

### 5) Add tests before deployment
Update/add tests in:
- force-app/main/default/classes/OOPS_RunServiceTest.cls
- force-app/main/default/classes/OOPS_RunControllerTest.cls
- force-app/main/default/classes/OOPS_Authorization.cls (via existing test-visible overrides and/or additional test scaffolding)

Minimum test scenarios:
1. Sandbox + Execute_OOPS => allowed.
2. Production + missing Execute_OOPS_In_Production => blocked.
3. Production + permission present + setting false => blocked.
4. Production + permission present + setting true => allowed.

Status:
- Recommended and still pending for full production-readiness signoff.

## Deployment Procedure (Production)

### 1) Validate in sandbox first
Example:
- sf project deploy start --dry-run --ignore-conflicts --source-dir force-app/main/default --target-org <sandboxAlias> --wait 30 --json

### 2) Run Apex tests
Recommended:
- sf apex run test --target-org <sandboxAlias> --result-format human --wait 30 --code-coverage

### 3) Deploy to production with validation
Example:
- sf project deploy start --dry-run --ignore-conflicts --source-dir force-app/main/default --target-org <prodAlias> --wait 30 --json

### 4) Deploy to production
Example:
- sf project deploy start --ignore-conflicts --source-dir force-app/main/default --target-org <prodAlias> --wait 30 --json

### 5) Post-deploy checklist
1. Confirm Execute_OOPS_In_Production is assigned only to intended users.
2. Confirm ProductionExecutionEnabled__c remains false until approved go-live.
3. Execute controlled pilot run on low-risk object/data subset.
4. Verify run counters, exception records, and rollback playbook readiness.

## Operational Safeguards
- Use least privilege for operator assignments.
- Require peer approval to toggle production execution setting.
- Keep run scope conservative for first production runs.
- Monitor exceptions and run durations closely.
- Document business owner approval before enabling in production.

## Optional Hardening Enhancements
- Require dual confirmation token before production launch.
- Add scheduled blackout windows in authorization checks.
- Add object allowlist for production masking targets.
- Add audit object for production execution approvals.
