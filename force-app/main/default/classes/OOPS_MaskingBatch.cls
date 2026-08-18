public with sharing class OOPS_MaskingBatch implements Database.Batchable<SObject> {
    private Id runId;
    private Id configurationId;
    private String objectApiName;
    private String recordScope;
    private Integer firstNRecordCount;

    public OOPS_MaskingBatch(Id runId, Id configurationId, String objectApiName, String recordScope, Integer firstNRecordCount) {
        this.runId = runId;
        this.configurationId = configurationId;
        this.objectApiName = objectApiName;
        this.recordScope = recordScope;
        this.firstNRecordCount = firstNRecordCount;
    }

    public OOPS_MaskingBatch(Id runId, Id configurationId, String recordScope, Integer firstNRecordCount) {
        this(runId, configurationId, 'Contact', recordScope, firstNRecordCount);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<MaskingRun__c> runs = [
            SELECT Id, Status__c
            FROM MaskingRun__c
            WHERE Id = :runId
            LIMIT 1
        ];
        if (runs.isEmpty()) {
            throw new OOPS_ConfigurationException('Masking run not found.');
        }

        MaskingRun__c runRow = runs[0];
        runRow.Status__c = 'Running';
        runRow.AsyncJobId__c = bc.getJobId();
        OOPS_RunDAO.updateRun(runRow);

        List<FieldConfiguration__c> fieldConfigs = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, objectApiName);
        Map<String, Schema.SObjectField> describeFieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        Set<String> selectFieldSet = new Set<String>{ 'Id' };
        for (FieldConfiguration__c cfg : fieldConfigs) {
            if (!String.isBlank(cfg.FieldApiName__c) && describeFieldMap.containsKey(cfg.FieldApiName__c)) {
                selectFieldSet.add(cfg.FieldApiName__c);
            }
        }

        List<String> selectFields = new List<String>();
        selectFields.addAll(selectFieldSet);
        selectFields.sort();

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + objectApiName;
        if (describeFieldMap.containsKey('CreatedDate')) {
            soql += ' ORDER BY CreatedDate ASC';
        }
        if (recordScope == 'First N Records' && firstNRecordCount != null && firstNRecordCount > 0) {
            soql += ' LIMIT ' + firstNRecordCount;
        }
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope.isEmpty()) {
            return;
        }

        List<FieldConfiguration__c> fieldConfigs = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, objectApiName);
        Map<String, String> strategyByField = new Map<String, String>();
        Map<String, String> fixedReplacementByField = new Map<String, String>();
        for (FieldConfiguration__c cfg : fieldConfigs) {
            strategyByField.put(cfg.FieldApiName__c, cfg.MaskingStrategy__c);
            fixedReplacementByField.put(cfg.FieldApiName__c, cfg.FixedReplacementValue__c);
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        List<SObject> updates = new List<SObject>();
        Map<Integer, Id> rowIdByIndex = new Map<Integer, Id>();
        Map<Integer, String> strategyByIndex = new Map<Integer, String>();

        Integer idx = 0;
        for (SObject row : scope) {
            Id sourceId = (Id) row.get('Id');
            SObject updateRow = Schema.getGlobalDescribe().get(objectApiName).newSObject(sourceId);
            Boolean anyChanged = false;

            for (String fieldApi : strategyByField.keySet()) {
                if (!fieldMap.containsKey(fieldApi)) {
                    continue;
                }

                Schema.DescribeFieldResult dfr = fieldMap.get(fieldApi).getDescribe();
                if (!dfr.isUpdateable()) {
                    continue;
                }

                String strategy = strategyByField.get(fieldApi);
                String fixedReplacementValue = fixedReplacementByField.get(fieldApi);
                Object maskedValue = getMaskedValueForStrategy(fieldApi, strategy, fixedReplacementValue, dfr.getType(), row);
                Object currentValue = row.get(fieldApi);

                String currentString = currentValue == null ? null : String.valueOf(currentValue);
                String maskedString = maskedValue == null ? null : String.valueOf(maskedValue);

                if (currentString != maskedString) {
                    updateRow.put(fieldApi, maskedValue);
                    anyChanged = true;
                }
            }

            if (anyChanged) {
                updates.add(updateRow);
                rowIdByIndex.put(idx, sourceId);
                strategyByIndex.put(idx, objectApiName + ' masking');
                idx++;
            }
        }

        Integer attempted = updates.size();
        Integer updatedCount = 0;
        Integer failedCount = 0;
        List<MaskingException__c> exceptions = new List<MaskingException__c>();

        if (!updates.isEmpty()) {
            Database.SaveResult[] results = Database.update(updates, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    updatedCount++;
                } else {
                    failedCount++;
                    Database.Error err = results[i].getErrors()[0];
                    MaskingException__c exRow = new MaskingException__c();
                    exRow.MaskingRun__c = runId;
                    exRow.SourceObject__c = objectApiName;
                    exRow.SourceObjectApiName__c = objectApiName;
                    exRow.SourceRecordId__c = String.valueOf(rowIdByIndex.get(i));
                    exRow.SourceRecordName__c = objectApiName + '-' + String.valueOf(rowIdByIndex.get(i)).right(6);
                    exRow.FieldApiName__c = 'Multiple';
                    exRow.MaskingStrategy__c = strategyByIndex.get(i);
                    exRow.ErrorMessage__c = truncate(err.getMessage(), 255);
                    exRow.ExceptionType__c = classifyExceptionType(err.getStatusCode());
                    exRow.OccurredAt__c = System.now();
                    exRow.TechnicalDetails__c = truncate('StatusCode=' + String.valueOf(err.getStatusCode()), 32768);
                    exceptions.add(exRow);
                }
            }
        }

        if (!exceptions.isEmpty()) {
            OOPS_RunDAO.insertMaskingExceptions(exceptions);
        }

        OOPS_RunDAO.incrementRunCounters(runId, attempted, updatedCount, failedCount);
    }

    public void finish(Database.BatchableContext bc) {
        MaskingRun__c runRow = OOPS_RunDAO.getRunById(runId);
        if (runRow == null) {
            return;
        }

        Integer candidateCount = OOPS_RunDAO.getCandidateRecordCount(objectApiName, recordScope, firstNRecordCount);
        Integer attempted = OOPS_RunDAO.getIntegerField(runRow, 'RecordsAttempted__c');
        Integer skipped = candidateCount - attempted;
        if (skipped < 0) {
            skipped = 0;
        }

        Integer exceptionCount = OOPS_RunDAO.countMaskingExceptionsByRun(runId);
        Integer failedCount = OOPS_RunDAO.getIntegerField(runRow, 'RecordsFailed__c');
        String terminalStatus = failedCount == 0 ? 'Completed' : 'Completed with Exceptions';
        Datetime startedAt;
        try {
            startedAt = (Datetime) runRow.get('StartedAt__c');
        } catch (Exception ex) {
            startedAt = null;
        }
        Datetime completedAt = System.now();
        OOPS_RunDAO.finalizeRun(runId, skipped, exceptionCount, startedAt, completedAt, terminalStatus);
    }

    private static Object getMaskedValueForStrategy(String fieldApiName, String strategy, String fixedReplacementValue, Schema.DisplayType fieldType, SObject source) {
        if (strategy == 'Do Not Mask') {
            return source.get(fieldApiName);
        }
        if (strategy == 'First Name' && fieldApiName == 'FirstName') {
            return OOPS_MaskingRules.maskFirstName();
        }
        if (strategy == 'Last Name' && fieldApiName == 'LastName') {
            return OOPS_MaskingRules.maskLastName((Id) source.get('Id'));
        }
        if (strategy == 'Email Suffix' && fieldApiName == 'Email') {
            return OOPS_MaskingRules.maskEmail((String) source.get('Email'));
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
        return source.get(fieldApiName);
    }

    private static String classifyExceptionType(StatusCode code) {
        if (code == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
            return 'Validation Rule';
        }
        if (code == StatusCode.UNABLE_TO_LOCK_ROW) {
            return 'Record Locked';
        }
        if (code == StatusCode.INSUFFICIENT_ACCESS_OR_READONLY) {
            return 'Insufficient Access';
        }
        return 'Update Failed';
    }

    private static String truncate(String input, Integer maxLen) {
        if (input == null) {
            return null;
        }
        return input.length() > maxLen ? input.substring(0, maxLen) : input;
    }
}
