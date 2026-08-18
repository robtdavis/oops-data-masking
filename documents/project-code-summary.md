# OOPS Project Code Summary

## Summary
This project implements a Salesforce data-masking application with a configuration wizard and run console. It includes:
- Apex services/controllers for configuring masking behavior and launching runs.
- Metadata-driven object/field discovery with support for queryable and updateable objects.
- Batch-based execution and preview flow with run tracking, counters, and exception logging.
- Lightning Web Components for Configure OOPS and Run Console user experiences.
- Permission sets and custom permissions to separate configure/execute/admin duties.

The current implementation supports selecting one object per configuration execution path, but the selected object can be any supported object in the org.

## Architecture Overview
The solution is organized around these layers:
- UI layer (LWC): collects config choices, starts preview/execution, and displays results/status.
- Controller layer (AuraEnabled Apex): translates UI requests to service calls and returns safe handled errors.
- Service layer (Apex): validates business rules, enforces permissions/environment checks, and orchestrates DAO/batch logic.
- DAO layer (Apex): queries and updates custom configuration and run-tracking objects.
- Batch layer (Apex): performs masking updates in chunks with exception capture.

## Main Functional Areas

### 1. Authorization and Safety
Key class:
- force-app/main/default/classes/OOPS_Authorization.cls

Responsibilities:
- Enforces Configure and Execute custom permissions.
- Restricts execution to sandbox via assertSandboxOnlyExecution().
- Provides test overrides for permission and sandbox checks.

### 2. Configuration Experience
Key classes:
- force-app/main/default/classes/OOPS_ConfigurationController.cls
- force-app/main/default/classes/OOPS_ConfigurationService.cls
- force-app/main/default/classes/OOPS_ConfigurationDAO.cls
- force-app/main/default/classes/OOPS_ConfigurationDTO.cls
- force-app/main/default/classes/OOPS_MetadataService.cls

Responsibilities:
- Retrieves object options and field options from schema describe.
- Persists masking configurations and included fields.
- Validates selected objects, fields, record scope, and masking strategies.
- Uses strict include semantics for selected fields.

Recent behavior notes:
- Object options are sourced from object describe and constrained to objects that are queryable and updateable.
- Field options mark unsupported fields with reasons.

### 3. Run Console and Orchestration
Key classes:
- force-app/main/default/classes/OOPS_RunController.cls
- force-app/main/default/classes/OOPS_RunService.cls
- force-app/main/default/classes/OOPS_RunDAO.cls
- force-app/main/default/classes/OOPS_RunModels.cls

Responsibilities:
- Lists active saved configurations.
- Launches preview and execution for a selected configuration.
- Tracks run status and counters.
- Builds run records with environment metadata.

Recent behavior notes:
- Preview and execution are object-aware (not fixed to Contact-only execution logic).
- Preview response includes generic record context (recordId/objectApiName) while retaining compatibility fields.

### 4. Masking Execution Engine
Key classes:
- force-app/main/default/classes/OOPS_MaskingBatch.cls
- force-app/main/default/classes/OOPS_MaskingRules.cls

Responsibilities:
- Runs Database.Batchable<SObject> updates for the selected object.
- Applies strategy-based masking per included field.
- Captures per-record failures to MaskingException__c and updates run counters.

Supported strategy set in current services:
- Do Not Mask
- First Name
- Last Name
- Email Suffix
- Fixed Phone
- Fixed Value
- Clear Field

### 5. Front-End Components
Key LWCs:
- force-app/main/default/lwc/oopsConfigure
- force-app/main/default/lwc/oopsRunConsole

Configure OOPS:
- Multi-step wizard for details, objects, fields, scope, and review.
- Loads and saves configuration records.
- Supports shared selected-configuration handoff from Run Console.

Run Console:
- Selects configuration and starts preview/execution.
- Polls run status and displays counters.
- Writes selected configuration to shared local state for Configure OOPS pre-load.

### 6. Metadata and Security Assets
Key metadata areas:
- force-app/main/default/objects
- force-app/main/default/layouts
- force-app/main/default/permissionsets
- force-app/main/default/customPermissions
- force-app/main/default/tabs
- force-app/main/default/applications

Includes:
- Custom objects for configuration, runs, and exceptions.
- Permission sets: OOPS_Administrator, OOPS_Configurator, OOPS_Operator, OOPS_Production_Operator.
- Custom permissions such as Configure_OOPS and Execute_OOPS.

## Test Coverage Artifacts
Representative tests:
- force-app/main/default/classes/OOPS_ConfigurationControllerTest.cls
- force-app/main/default/classes/OOPS_ConfigurationServiceTest.cls
- force-app/main/default/classes/OOPS_RunControllerTest.cls
- force-app/main/default/classes/OOPS_RunServiceTest.cls
- force-app/main/default/classes/OOPS_MaskingBatchTest.cls
- force-app/main/default/classes/OOPS_MetadataServiceTest.cls

These tests cover major happy paths and key guardrail behavior for configuration and execution slices.

## Current Operational Constraints
- Execution is blocked in production by explicit sandbox-only guard in OOPS_Authorization.assertSandboxOnlyExecution().
- Run orchestration currently assumes one selected object per active execution path.
- Production enablement requires controlled changes and explicit governance decisions (see production guide).

## Change Log Notes (Recent Direction)
- Transitioned from Contact-only selection logic to schema-driven object support for queryable/updateable objects.
- Generalized run preview/execution data path to use object API from configuration context.
- Added shared selection handoff between Run Console and Configure OOPS.
