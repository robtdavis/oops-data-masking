public with sharing class OOPS_MaskingBatch implements Database.Batchable<SObject> {
    private Id runId;
    private Id configurationId;
    private List<String> objectApiNames;
    private Integer currentObjectIndex;
    private String recordScope;
    private Integer firstNRecordCount;
    private Integer configuredBatchSize;

    public OOPS_MaskingBatch(
        Id runId,
        Id configurationId,
        List<String> objectApiNames,
        Integer currentObjectIndex,
        String recordScope,
        Integer firstNRecordCount,
        Integer configuredBatchSize
    ) {
        this.runId = runId;
        this.configurationId = configurationId;
        this.objectApiNames = new List<String>();
        if (objectApiNames != null) {
            this.objectApiNames.addAll(objectApiNames);
        }
        this.currentObjectIndex = currentObjectIndex == null ? 0 : currentObjectIndex;
        this.recordScope = recordScope;
        this.firstNRecordCount = firstNRecordCount;
        this.configuredBatchSize = configuredBatchSize;
    }

    public OOPS_MaskingBatch(
        Id runId,
        Id configurationId,
        List<String> objectApiNames,
        String recordScope,
        Integer firstNRecordCount,
        Integer configuredBatchSize
    ) {
        this(runId, configurationId, objectApiNames, 0, recordScope, firstNRecordCount, configuredBatchSize);
    }

    public OOPS_MaskingBatch(Id runId, Id configurationId, String objectApiName, String recordScope, Integer firstNRecordCount) {
        this(runId, configurationId, new List<String>{ objectApiName }, 0, recordScope, firstNRecordCount, null);
    }

    public OOPS_MaskingBatch(Id runId, Id configurationId, String recordScope, Integer firstNRecordCount) {
        this(runId, configurationId, 'Contact', recordScope, firstNRecordCount);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String currentObjectApiName = getCurrentObjectApiName();
        if (String.isBlank(currentObjectApiName)) {
            throw new OOPS_ConfigurationException('No object selected for masking execution.');
        }

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

        List<FieldConfiguration__c> fieldConfigs = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, currentObjectApiName);
        Map<String, Schema.SObjectField> describeFieldMap = Schema.getGlobalDescribe().get(currentObjectApiName).getDescribe().fields.getMap();

        Set<String> selectFieldSet = new Set<String>{ 'Id' };
        for (FieldConfiguration__c cfg : fieldConfigs) {
            if (!String.isBlank(cfg.FieldApiName__c) && describeFieldMap.containsKey(cfg.FieldApiName__c)) {
                selectFieldSet.add(cfg.FieldApiName__c);
            }
        }

        List<String> selectFields = new List<String>();
        selectFields.addAll(selectFieldSet);
        selectFields.sort();

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + currentObjectApiName;
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

        String currentObjectApiName = getCurrentObjectApiName();

        List<FieldConfiguration__c> fieldConfigs = OOPS_RunDAO.getIncludedFieldConfigurations(configurationId, currentObjectApiName);
        Map<String, String> strategyByField = new Map<String, String>();
        Map<String, String> fixedReplacementByField = new Map<String, String>();
        for (FieldConfiguration__c cfg : fieldConfigs) {
            strategyByField.put(cfg.FieldApiName__c, cfg.MaskingStrategy__c);
            fixedReplacementByField.put(cfg.FieldApiName__c, cfg.FixedReplacementValue__c);
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(currentObjectApiName).getDescribe().fields.getMap();

        List<SObject> updates = new List<SObject>();
        Map<Integer, Id> rowIdByIndex = new Map<Integer, Id>();
        Map<Integer, String> strategyByIndex = new Map<Integer, String>();

        Integer idx = 0;
        for (SObject row : scope) {
            Id sourceId = (Id) row.get('Id');
            SObject updateRow = Schema.getGlobalDescribe().get(currentObjectApiName).newSObject(sourceId);
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
                strategyByIndex.put(idx, currentObjectApiName + ' masking');
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
                    exRow.SourceObject__c = currentObjectApiName;
                    exRow.SourceObjectApiName__c = currentObjectApiName;
                    exRow.SourceRecordId__c = String.valueOf(rowIdByIndex.get(i));
                    exRow.SourceRecordName__c = currentObjectApiName + '-' + String.valueOf(rowIdByIndex.get(i)).right(6);
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
        if (hasMoreObjectsToProcess()) {
            Integer nextIndex = currentObjectIndex + 1;
            Integer nextBatchSize = configuredBatchSize == null || configuredBatchSize <= 0 ? 200 : configuredBatchSize;
            if (nextBatchSize > 200) {
                nextBatchSize = 200;
            }

            Database.executeBatch(
                new OOPS_MaskingBatch(
                    runId,
                    configurationId,
                    objectApiNames,
                    nextIndex,
                    recordScope,
                    firstNRecordCount,
                    nextBatchSize
                ),
                nextBatchSize
            );
            return;
        }

        MaskingRun__c runRow = OOPS_RunDAO.getRunById(runId);
        if (runRow == null) {
            return;
        }

        Integer candidateCount = getTotalCandidateCount();
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

    private String getCurrentObjectApiName() {
        if (objectApiNames == null || objectApiNames.isEmpty()) {
            return null;
        }
        if (currentObjectIndex == null || currentObjectIndex < 0 || currentObjectIndex >= objectApiNames.size()) {
            return null;
        }
        return objectApiNames[currentObjectIndex];
    }

    private Boolean hasMoreObjectsToProcess() {
        return objectApiNames != null && currentObjectIndex != null && (currentObjectIndex + 1) < objectApiNames.size();
    }

    private Integer getTotalCandidateCount() {
        Integer total = 0;
        if (objectApiNames == null) {
            return total;
        }

        for (String objectApi : objectApiNames) {
            total += OOPS_RunDAO.getCandidateRecordCount(objectApi, recordScope, firstNRecordCount);
        }
        return total;
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
