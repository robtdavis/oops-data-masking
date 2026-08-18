# OOPS Data Masking

OOPS is a Salesforce data masking application that helps administrators safely anonymize Salesforce data for testing, development, demonstrations, and other lower-environment use cases.

Administrators can configure object- and field-level masking strategies, preview expected changes, limit execution scope, run masking operations, and monitor results through governance and safety controls.

## Key Features

* Configurable object and field masking strategies
* Multi-object masking configurations
* Preview-before-execution workflow
* First N Records or All Records scope
* Permission-based execution controls
* Additional safeguards for non-sandbox environments
* Run status and exception monitoring
* Bulk-oriented masking execution
* Configuration reuse and editing
* Governance controls designed to reduce accidental data changes

---

# Safety First

OOPS is designed primarily for use in Salesforce sandboxes.

**Execute Masking modifies Salesforce records. It is a data-changing operation, not a simulation.**

Do not run masking in production unless a formal exception has been reviewed and approved.

Previewing a configuration is read-only. Executing a configuration is not.

---

# Production Override

## Intent

OOPS favors sandbox execution by design.

A production override exists only to support tightly controlled testing scenarios, such as Developer Edition orgs or other non-sandbox environments where Salesforce environment detection classifies the org as production.

The override is not intended to make production masking a normal operating practice.

## Required Conditions

Execution in a non-sandbox environment is allowed only when **all** of the following conditions are met:

1. The user has the `Execute_OOPS` permission.
2. The user has the `Execute_OOPS_In_Production` permission.
3. `OOPSSettings__c.ProductionExecutionEnabled__c` is enabled.
4. The user explicitly confirms the production warning in the OOPS Run Console.

If any requirement is not satisfied, execution is blocked.

## Important Warning

Approval of production execution does **not** make the masking operation safe for production data.

It only removes the technical execution guards.

**The masking run will still modify Salesforce records.**

---

# Design Principles

OOPS is built around several architectural principles.

### Sandbox First

Masking is expected to occur primarily in lower environments where production-like data must be anonymized before testing or development.

### Preview Before Change

Administrators can review proposed field-level changes before executing a masking run.

Configurations can also require preview before execution.

### Least Privilege

Configuration, execution, and production override capabilities are separated through permissions.

### Controlled Scope

Masking can be limited to a small number of records before expanding to a larger execution scope.

### Auditability

Masking runs expose execution status, including attempted, updated, failed, skipped, and exception counts.

### Extensibility

Masking behavior is configuration-driven so additional objects, fields, and masking strategies can be supported without redesigning the application workflow.

---

# Setup and Deployment

## Prerequisites

* Salesforce CLI
* VS Code with Salesforce extensions
* Access to a target Salesforce org
* Sandbox strongly recommended

## Authenticate

```bash
sf org login web --alias <orgAlias>
```

## Validate Deployment

```bash
sf project deploy start \
  --dry-run \
  --ignore-conflicts \
  --source-dir force-app/main/default \
  --target-org <orgAlias> \
  --wait 30 \
  --json
```

## Deploy

```bash
sf project deploy start \
  --ignore-conflicts \
  --source-dir force-app/main/default \
  --target-org <orgAlias> \
  --wait 30 \
  --json
```

---

# Permissions

Assign permissions according to the user's responsibilities.

### `Configure_OOPS`

Allows administration of OOPS masking configurations.

### `Execute_OOPS`

Allows preview and execution of masking operations.

### `Execute_OOPS_In_Production`

Allows execution in a non-sandbox environment when all additional production safeguards are also satisfied.

This permission should be assigned only for tightly controlled override scenarios.

---

# Quick Start

A typical OOPS workflow is:

1. Deploy OOPS to a sandbox.
2. Assign the appropriate permissions.
3. Create a masking configuration.
4. Select objects and fields.
5. Assign masking strategies.
6. Define record scope.
7. Save the configuration.
8. Preview the expected changes.
9. Execute a small test scope.
10. Review results and exceptions.
11. Expand execution scope only after validation.

---

# Configure OOPS

Configure OOPS uses a five-step wizard.

## Tab 1: Details

Define the top-level behavior of the masking configuration.

### Configuration Options

* Configuration Name
* Default Batch Size
* Description
* Active
* Require Preview Before Execution

### Validation

* Configuration Name is required.
* Default Batch Size must be greater than `0`.

---

## Tab 2: Objects

Select one or more updateable Salesforce objects to include in the configuration.

### Features

* Alphabet navigation for large object lists
* Multi-object selection
* Object context carried into field configuration

At least one updateable object must be selected.

Object selection determines which fields are available in the next step.

---

## Tab 3: Fields

Select fields and define how each field should be masked.

For each selected field, administrators can configure:

* Masking Strategy
* Fixed Replacement Value, when applicable
* Display Order

Saved field selections and masking values are reloaded when an existing configuration is edited.

Field configuration remains scoped to its associated object when multiple objects are selected.

### Validation

At least one field must be selected before continuing.

---

## Tab 4: Scope

Define which records should be included during preview and execution.

### Record Scope

* All Records
* First N Records

When **First N Records** is selected, a record count must also be provided.

### Validation

`First N Record Count` must be greater than `0`.

---

## Tab 5: Review

Review the complete masking configuration before saving.

The Review step displays:

* Configuration settings
* Selected objects
* Selected fields
* Masking strategies
* Scope settings

Saving a configuration does **not** modify business records.

It only saves the masking definition.

---

# OOPS Run Console

The Run Console is used to preview and execute saved masking configurations.

## Step 1: Select a Configuration

Choose a saved masking configuration from the configuration picklist.

The selected configuration can also be synchronized with Configure OOPS for editing continuity.

---

## Step 2: Preview

Click:

**Preview (max 50)**

Preview displays a sample of the proposed masking changes before execution.

Administrators can review:

* Source records
* Original field values
* Proposed masked values
* Object-specific masking behavior

Preview is read-only and does not modify Salesforce records.

Preview can include records from multiple configured objects, subject to the preview limit.

---

## Step 3: Execute Masking

Click:

**Execute Masking**

Execution applies the configured masking strategies to Salesforce records.

**This operation changes data.**

If OOPS detects a non-sandbox environment, an additional confirmation dialog is displayed.

Execution should proceed only when the environment and change controls have been explicitly approved.

# Critical Warning

## ⚠️ Executing masking will modify Salesforce records.

## Production execution is not recommended for normal operation.

## The production override exists only for controlled testing and exceptional use cases.

---

## Step 4: Monitor Run Status

Click:

**Refresh Run Status**

Run status provides visibility into:

* Attempted records
* Updated records
* Failed records
* Skipped records
* Exceptions

Exceptions should be investigated before additional or larger masking runs are executed.

---

# Recommended Operating Process

For normal usage:

1. Build and test configurations in a sandbox.
2. Run Preview.
3. Review expected changes with appropriate business or technical owners.
4. Execute a limited **First N Records** scope.
5. Validate masked records.
6. Review run status and exceptions.
7. Correct configuration issues if necessary.
8. Increase execution scope only after successful validation.
9. Execute the full approved scope.

This progressive approach reduces the risk of unintended changes and provides an opportunity to validate masking behavior before large-volume execution.

---

# Known Operational Considerations

* Masking changes Salesforce data and should be treated as a controlled data operation.
* Users should validate masking strategies against representative records before large executions.
* Production override permissions should not be broadly assigned.
* Preview provides additional confidence but does not eliminate the need for proper testing and change control.
* Large data volumes should be approached incrementally and monitored through run results and exception reporting.

---

# License

MIT License

Copyright (c) 2026 Robert Davis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
