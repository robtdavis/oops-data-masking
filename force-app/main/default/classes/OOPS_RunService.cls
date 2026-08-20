public with sharing class OOPS_RunService {
    public static final Integer PREVIEW_LIMIT = 50;
    public static final Integer RUN_OUTCOME_DIAGNOSTIC_LIMIT = 100;

    public static List<OOPS_RunModels.ConfigurationOption> getSavedConfigurations() {
        OOPS_Authorization.assertExecutePermission();

        List<OOPS_RunModels.ConfigurationOption> options = new List<OOPS_RunModels.ConfigurationOption>();
        for (MaskingConfiguration__c row : OOPS_RunDAO.getActiveConfigurations()) {
            OOPS_RunModels.ConfigurationOption option = new OOPS_RunModels.ConfigurationOption();
            option.configurationId = row.Id;
            option.configurationName = row.ConfigurationName__c;
            options.add(option);
        }
        return options;
    }

    public static OOPS_RunModels.PreviewResponse launchPreview(Id configurationId) {
        OOPS_Authorization.assertExecutePermission();

        ConfigurationContext ctx = loadAndValidateConfiguration(configurationId);
        MaskingRun__c runRow = buildNewRun(ctx, 'Preview', 'Previewing');
        OOPS_RunDAO.insertRun(runRow);

        OOPS_RunModels.PreviewResponse response = new OOPS_RunModels.PreviewResponse();
        response.runId = runRow.Id;

        try {
            Integer remainingLimit = PREVIEW_LIMIT;
            for (String objectApiName : ctx.objectApiNames) {
                if (remainingLimit <= 0) {
                    break;
                }

                List<FieldConfiguration__c> objectFieldConfigs = ctx.fieldConfigurationsByObjectApi.get(objectApiName);
                if (objectFieldConfigs == null || objectFieldConfigs.isEmpty()) {
                    continue;
                }

                Set<String> includedFieldApis = new Set<String>();
                Map<String, FieldConfiguration__c> configByFieldApi = new Map<String, FieldConfiguration__c>();
                for (FieldConfiguration__c cfg : objectFieldConfigs) {
                    includedFieldApis.add(cfg.FieldApiName__c);
                    configByFieldApi.put(cfg.FieldApiName__c, cfg);
                }

                List<SObject> rows = OOPS_RunDAO.getPreviewRecords(
                    objectApiName,
                    includedFieldApis,
                    remainingLimit,
                    ctx.recordScope,
                    ctx.firstNRecordCount
                );
                Map<String, Schema.SObjectField> objectFieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

                for (SObject row : rows) {
                    OOPS_RunModels.PreviewRecord recordDto = new OOPS_RunModels.PreviewRecord();
                    recordDto.recordId = (Id) row.get('Id');
                    recordDto.contactId = recordDto.recordId;
                    recordDto.objectApiName = objectApiName;

                    for (String fieldApi : includedFieldApis) {
                        if (!objectFieldMap.containsKey(fieldApi)) {
                            continue;
                        }
                        Schema.DescribeFieldResult dfr = objectFieldMap.get(fieldApi).getDescribe();
                        Object beforeValueObj = row.get(fieldApi);
                        FieldConfiguration__c fieldCfg = configByFieldApi.get(fieldApi);
                        String strategy = fieldCfg == null ? 'Do Not Mask' : fieldCfg.MaskingStrategy__c;
                        String fixedReplacementValue = fieldCfg == null ? null : fieldCfg.FixedReplacementValue__c;
                        Object afterValueObj = getMaskedValueForStrategy(fieldApi, strategy, fixedReplacementValue, dfr.getType(), row);

                        OOPS_RunModels.PreviewFieldDelta delta = new OOPS_RunModels.PreviewFieldDelta();
                        delta.fieldApiName = fieldApi;
                        delta.beforeValue = beforeValueObj == null ? null : String.valueOf(beforeValueObj);
                        delta.afterValue = afterValueObj == null ? null : String.valueOf(afterValueObj);
                        delta.changed = delta.beforeValue != delta.afterValue;
                        recordDto.fieldDeltas.add(delta);
                    }

                    response.records.add(recordDto);
                }

                remainingLimit -= rows.size();
            }

            Integer attempted = response.records.size();
            Integer skipped = ctx.estimatedCandidateCountTotal - attempted;
            if (skipped < 0) {
                skipped = 0;
            }

            runRow.Status__c = 'Previewed';
            runRow.CompletedAt__c = System.now();
            runRow.DurationSeconds__c = Integer.valueOf((runRow.CompletedAt__c.getTime() - runRow.StartedAt__c.getTime()) / 1000);
            runRow.RecordsAttempted__c = attempted;
            runRow.RecordsUpdated__c = 0;
            runRow.RecordsFailed__c = 0;
            runRow.RecordsSkipped__c = skipped;
            runRow.ExceptionCount__c = 0;

            OOPS_RunDAO.updateRun(runRow);

            response.runStatus = runRow.Status__c;
            response.sampledRecordCount = attempted;
            if (ctx.estimatedCandidateCountTotal > PREVIEW_LIMIT) {
                response.warnings.add('Preview is capped at 50 records.');
            }
            return response;
        } catch (Exception ex) {
            runRow.Status__c = 'Failed';
            runRow.CompletedAt__c = System.now();
            runRow.ErrorSummary__c = truncateError(ex.getMessage());
            OOPS_RunDAO.updateRun(runRow);
            throw new OOPS_ConfigurationException('Preview failed. ' + ex.getMessage());
        }
    }

    public static OOPS_RunModels.ExecutionResponse launchExecution(Id configurationId) {
        OOPS_Authorization.assertExecutePermission();
        OOPS_Authorization.assertExecutionAllowedForEnvironment();

        ConfigurationContext ctx = loadAndValidateConfiguration(configurationId);
        assertNoActiveExecution();

        MaskingRun__c runRow = buildNewRun(ctx, 'Masking', 'Queued');
        OOPS_RunDAO.insertRun(runRow);

        Integer batchSize = ctx.defaultBatchSize;
        if (batchSize == null || batchSize <= 0) {
            batchSize = 200;
        }
        if (batchSize > 200) {
            batchSize = 200;
        }

        String jobId = Database.executeBatch(
            new OOPS_MaskingBatch(
                runRow.Id,
                ctx.configurationId,
                ctx.objectApiNames,
                ctx.recordScope,
                ctx.firstNRecordCount,
                batchSize
            ),
            batchSize
        );
        runRow.AsyncJobId__c = jobId;
        OOPS_RunDAO.updateRun(runRow);

        OOPS_RunModels.ExecutionResponse response = new OOPS_RunModels.ExecutionResponse();
        response.runId = runRow.Id;
        response.runStatus = runRow.Status__c;
        response.asyncJobId = jobId;
        response.message = 'Masking execution queued.';
        return response;
    }

    public static OOPS_RunModels.RunStatusResponse getRunStatus(Id runId) {
        OOPS_Authorization.assertExecutePermission();

        MaskingRun__c row = OOPS_RunDAO.getRunById(runId);
        if (row == null) {
            throw new OOPS_ConfigurationException('Masking run not found.');
        }

        OOPS_RunModels.RunStatusResponse response = new OOPS_RunModels.RunStatusResponse();
        response.runId = row.Id;
        response.runType = getStringValue(row, 'RunType__c');
        response.runStatus = getStringValue(row, 'Status__c');
        response.recordsAttempted = getIntegerValue(row, 'RecordsAttempted__c') == null ? 0 : getIntegerValue(row, 'RecordsAttempted__c');
        response.recordsUpdated = getIntegerValue(row, 'RecordsUpdated__c') == null ? 0 : getIntegerValue(row, 'RecordsUpdated__c');
        response.recordsFailed = getIntegerValue(row, 'RecordsFailed__c') == null ? 0 : getIntegerValue(row, 'RecordsFailed__c');
        response.recordsSkipped = getIntegerValue(row, 'RecordsSkipped__c') == null ? 0 : getIntegerValue(row, 'RecordsSkipped__c');
        response.exceptionCount = getIntegerValue(row, 'ExceptionCount__c') == null ? 0 : getIntegerValue(row, 'ExceptionCount__c');
        response.asyncJobId = getStringValue(row, 'AsyncJobId__c');
        response.startedAt = (Datetime) row.get('StartedAt__c');
        response.completedAt = (Datetime) row.get('CompletedAt__c');
        response.errorSummary = getStringValue(row, 'ErrorSummary__c');

        for (MaskingException__c diagnostic : OOPS_RunDAO.getRunOutcomeDiagnostics(runId, RUN_OUTCOME_DIAGNOSTIC_LIMIT)) {
            OOPS_RunModels.RunRecordOutcome outcome = new OOPS_RunModels.RunRecordOutcome();
            outcome.outcomeType = diagnostic.FieldApiName__c == 'Skipped' ? 'Skipped' : 'Failed';
            outcome.objectApiName = diagnostic.SourceObjectApiName__c;
            outcome.recordId = diagnostic.SourceRecordId__c;
            outcome.reason = diagnostic.ErrorMessage__c;
            outcome.occurredAt = diagnostic.OccurredAt__c;
            response.recordOutcomes.add(outcome);
        }

        return response;
    }

    public static void assertNoActiveExecution() {
        List<MaskingRun__c> activeRuns = OOPS_RunDAO.getActiveMaskingRuns();
        if (!activeRuns.isEmpty()) {
            throw new OOPS_ConfigurationException('Another masking run is already active. Wait for it to finish before starting a new run.');
        }
    }

    private static MaskingRun__c buildNewRun(ConfigurationContext ctx, String runType, String status) {
        OrgInfo orgInfo = getOrgInfo();

        MaskingRun__c runRow = new MaskingRun__c();
        runRow.MaskingConfiguration__c = ctx.configurationId;
        runRow.RunType__c = runType;
        runRow.Status__c = status;
        runRow.StartedBy__c = UserInfo.getUserId();
        runRow.StartedAt__c = System.now();
        runRow.BatchSize__c = ctx.defaultBatchSize;
        runRow.RecordScope__c = ctx.recordScope;
        runRow.FirstNRecordCount__c = ctx.firstNRecordCount;
        runRow.ObjectsSelected__c = ctx.objectApiNames == null || ctx.objectApiNames.isEmpty() ? 1 : ctx.objectApiNames.size();
        runRow.RecordsAttempted__c = 0;
        runRow.RecordsUpdated__c = 0;
        runRow.RecordsFailed__c = 0;
        runRow.RecordsSkipped__c = 0;
        runRow.ExceptionCount__c = 0;
        runRow.EnvironmentType__c = orgInfo.environmentType;
        runRow.OrganizationId__c = orgInfo.organizationId;
        runRow.OrganizationName__c = orgInfo.organizationName;
        runRow.SandboxName__c = orgInfo.sandboxName;
        return runRow;
    }

    private static ConfigurationContext loadAndValidateConfiguration(Id configurationId) {
        if (configurationId == null) {
            throw new OOPS_ConfigurationException('A saved configuration is required.');
        }

        MaskingConfiguration__c config = OOPS_RunDAO.getConfigurationById(configurationId);
        if (config == null) {
            throw new OOPS_ConfigurationException('Configuration not found.');
        }

        List<ObjectConfiguration__c> objectConfigs = OOPS_ConfigurationDAO.getObjectConfigurationsByConfigurationId(configurationId);
        if (objectConfigs.isEmpty()) {
            throw new OOPS_ConfigurationException('Configuration must include at least one object.');
        }

        ObjectConfiguration__c selectedObject = objectConfigs[0];
        List<FieldConfiguration__c> includedFields = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, selectedObject.ObjectApiName__c);
        if (includedFields.isEmpty()) {
            throw new OOPS_ConfigurationException(
                'Configuration must include at least one field for object ' + selectedObject.ObjectApiName__c + '.'
            );
        }

        Set<String> allowedStrategies = new Set<String>{
            'Do Not Mask',
            'First Name',
            'Last Name',
            'Email Suffix',
            'Fixed Phone',
            'Fixed Value',
            'Clear Field'
        };

        for (FieldConfiguration__c fieldCfg : includedFields) {
            if (String.isBlank(fieldCfg.FieldApiName__c)) {
                throw new OOPS_ConfigurationException('Included field is missing an API name.');
            }
            if (!allowedStrategies.contains(fieldCfg.MaskingStrategy__c)) {
                throw new OOPS_ConfigurationException('Unsupported masking strategy in this slice: ' + fieldCfg.MaskingStrategy__c);
            }
        }

        List<String> objectApiNames = new List<String>();
        Map<String, List<FieldConfiguration__c>> fieldConfigurationsByObjectApi = new Map<String, List<FieldConfiguration__c>>();
        Integer estimatedCandidateCountTotal = 0;

        for (ObjectConfiguration__c objectCfg : objectConfigs) {
            List<FieldConfiguration__c> objectFields = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, objectCfg.ObjectApiName__c);
            if (objectFields.isEmpty()) {
                throw new OOPS_ConfigurationException(
                    'Configuration must include at least one field for object ' + objectCfg.ObjectApiName__c + '.'
                );
            }

            for (FieldConfiguration__c fieldCfg : objectFields) {
                if (String.isBlank(fieldCfg.FieldApiName__c)) {
                    throw new OOPS_ConfigurationException('Included field is missing an API name.');
                }
                if (!allowedStrategies.contains(fieldCfg.MaskingStrategy__c)) {
                    throw new OOPS_ConfigurationException('Unsupported masking strategy in this slice: ' + fieldCfg.MaskingStrategy__c);
                }
            }

            objectApiNames.add(objectCfg.ObjectApiName__c);
            fieldConfigurationsByObjectApi.put(objectCfg.ObjectApiName__c, objectFields);
            estimatedCandidateCountTotal += OOPS_RunDAO.getCandidateRecordCount(
                objectCfg.ObjectApiName__c,
                String.isBlank(config.RecordScope__c) ? 'All Records' : config.RecordScope__c,
                config.FirstNRecordCount__c == null ? null : Integer.valueOf(config.FirstNRecordCount__c)
            );
        }

        ConfigurationContext ctx = new ConfigurationContext();
        ctx.configurationId = config.Id;
        ctx.configurationName = getStringValue(config, 'ConfigurationName__c');
        ctx.objectApiName = selectedObject.ObjectApiName__c;
        Integer batchSize = getIntegerValue(config, 'DefaultBatchSize__c');
        ctx.defaultBatchSize = batchSize == null ? 200 : batchSize;
        String scopeValue = getStringValue(config, 'RecordScope__c');
        ctx.recordScope = String.isBlank(scopeValue) ? 'All Records' : scopeValue;
        ctx.firstNRecordCount = getIntegerValue(config, 'FirstNRecordCount__c');
        ctx.fieldConfigurations = includedFields;
        ctx.estimatedCandidateCount = OOPS_RunDAO.getCandidateRecordCount(ctx.objectApiName, ctx.recordScope, ctx.firstNRecordCount);
        ctx.objectApiNames = objectApiNames;
        ctx.fieldConfigurationsByObjectApi = fieldConfigurationsByObjectApi;
        ctx.estimatedCandidateCountTotal = estimatedCandidateCountTotal;
        return ctx;
    }

    private static Object getMaskedValueForStrategy(String fieldApiName, String strategy, String fixedReplacementValue, Schema.DisplayType fieldType, SObject row) {
        if (strategy == 'Do Not Mask') {
            return row.get(fieldApiName);
        }
        if (strategy == 'First Name' && fieldApiName == 'FirstName') {
            return OOPS_MaskingRules.maskFirstName();
        }
        if (strategy == 'Last Name' && fieldApiName == 'LastName') {
            return OOPS_MaskingRules.maskLastName((Id) row.get('Id'));
        }
        if (strategy == 'Email Suffix' && fieldApiName == 'Email') {
            return OOPS_MaskingRules.maskEmail((String) row.get('Email'));
        }
        if (strategy == 'Fixed Phone' && fieldType == Schema.DisplayType.Phone) {
            return OOPS_MaskingRules.maskPhone();
        }
        if (strategy == 'Fixed Value') {
            return fixedReplacementValue;
        }
        if (strategy == 'Clear Field') {
            return null;
        }
        return row.get(fieldApiName);
    }

    private static OrgInfo getOrgInfo() {
        Organization orgRow = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];

        OrgInfo info = new OrgInfo();
        info.organizationId = orgRow.Id;
        info.organizationName = orgRow.Name;
        info.environmentType = orgRow.IsSandbox ? 'Sandbox' : 'Production';
        info.sandboxName = orgRow.IsSandbox ? UserInfo.getOrganizationName() : null;
        return info;
    }

    private static String truncateError(String message) {
        if (String.isBlank(message)) {
            return 'Unknown error';
        }
        Integer maxLen = 32000;
        return message.length() > maxLen ? message.substring(0, maxLen) : message;
    }

    private static String getStringValue(SObject row, String fieldApiName) {
        try {
            Object value = row.get(fieldApiName);
            return value == null ? null : String.valueOf(value);
        } catch (Exception ex) {
            return null;
        }
    }

    private static Integer getIntegerValue(SObject row, String fieldApiName) {
        try {
            Object value = row.get(fieldApiName);
            return value == null ? null : Integer.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }

    public class ConfigurationContext {
        public Id configurationId;
        public String configurationName;
        public String objectApiName;
        public List<String> objectApiNames;
        public Map<String, List<FieldConfiguration__c>> fieldConfigurationsByObjectApi;
        public Integer defaultBatchSize;
        public String recordScope;
        public Integer firstNRecordCount;
        public List<FieldConfiguration__c> fieldConfigurations;
        public Integer estimatedCandidateCount;
        public Integer estimatedCandidateCountTotal;
    }

    public class OrgInfo {
        public String organizationId;
        public String organizationName;
        public String environmentType;
        public String sandboxName;
    }
}
