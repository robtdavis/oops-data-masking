public with sharing class OOPS_RunDAO {
    public static List<MaskingConfiguration__c> getActiveConfigurations() {
        if (!Schema.sObjectType.MaskingConfiguration__c.isAccessible() ||
            !Schema.sObjectType.ObjectConfiguration__c.isAccessible()) {
            return new List<MaskingConfiguration__c>();
        }

        Map<String, Schema.SObjectField> configFieldMap = MaskingConfiguration__c.SObjectType.getDescribe().fields.getMap();

        List<String> selectFields = new List<String>{ 'Id' };
        if (configFieldMap.containsKey('ConfigurationName__c') &&
            configFieldMap.get('ConfigurationName__c').getDescribe().isAccessible()) {
            selectFields.add('ConfigurationName__c');
        }

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM MaskingConfiguration__c WHERE Id IN (' +
            'SELECT MaskingConfiguration__c FROM ObjectConfiguration__c)';

        if (configFieldMap.containsKey('Active__c') &&
            configFieldMap.get('Active__c').getDescribe().isAccessible()) {
            soql += ' AND Active__c = true';
        }

        if (selectFields.contains('ConfigurationName__c')) {
            soql += ' ORDER BY ConfigurationName__c ASC';
        }

        return (List<MaskingConfiguration__c>) Database.query(soql);
    }

    public static List<MaskingConfiguration__c> getActiveContactConfigurations() {
        return getActiveConfigurations();
    }

    public static MaskingConfiguration__c getConfigurationById(Id configurationId) {
        if (!Schema.sObjectType.MaskingConfiguration__c.isAccessible()) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldMap = MaskingConfiguration__c.SObjectType.getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{ 'Id' };
        List<String> optionalFields = new List<String>{
            'ConfigurationName__c',
            'Active__c',
            'DefaultBatchSize__c',
            'RecordScope__c',
            'FirstNRecordCount__c'
        };

        for (String fieldApi : optionalFields) {
            if (fieldMap.containsKey(fieldApi) && fieldMap.get(fieldApi).getDescribe().isAccessible()) {
                queryFields.add(fieldApi);
            }
        }

        String soql = 'SELECT ' + String.join(queryFields, ', ') +
            ' FROM MaskingConfiguration__c WHERE Id = :configurationId LIMIT 1';
        List<MaskingConfiguration__c> rows = (List<MaskingConfiguration__c>) Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<FieldConfiguration__c> getIncludedFieldConfigurations(Id configurationId, String objectApiName) {
        OOPS_MetadataService.validateObjectApiName(objectApiName);

        if (!Schema.sObjectType.FieldConfiguration__c.isAccessible() ||
            !Schema.sObjectType.ObjectConfiguration__c.isAccessible()) {
            return new List<FieldConfiguration__c>();
        }

        Map<String, Schema.SObjectField> fieldMap = FieldConfiguration__c.SObjectType.getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{ 'Id' };
        List<String> optionalFields = new List<String>{
            'FieldApiName__c',
            'MaskingStrategy__c',
            'Included__c',
            'FixedReplacementValue__c',
            'Updateable__c',
            'DisplayOrder__c'
        };
        for (String fieldApi : optionalFields) {
            if (fieldMap.containsKey(fieldApi) && fieldMap.get(fieldApi).getDescribe().isAccessible()) {
                selectFields.add(fieldApi);
            }
        }

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM FieldConfiguration__c WHERE ObjectConfiguration__r.MaskingConfiguration__c = :configurationId' +
            ' AND ObjectConfiguration__r.ObjectApiName__c = :objectApiName';
        if (selectFields.contains('Included__c')) {
            soql += ' AND Included__c = true';
        }
        if (selectFields.contains('DisplayOrder__c')) {
            soql += ' ORDER BY DisplayOrder__c ASC, CreatedDate ASC';
        } else {
            soql += ' ORDER BY CreatedDate ASC';
        }

        return (List<FieldConfiguration__c>) Database.query(soql);
    }

    public static List<FieldConfiguration__c> getIncludedContactFieldConfigurations(Id configurationId) {
        return getIncludedFieldConfigurations(configurationId, 'Contact');
    }

    public static Integer getCandidateRecordCount(String objectApiName, String recordScope, Integer firstNRecordCount) {
        OOPS_MetadataService.validateObjectApiName(objectApiName);

        String soql = 'SELECT COUNT() FROM ' + objectApiName;
        Integer total = Database.countQuery(soql);
        if (recordScope == 'First N Records' && firstNRecordCount != null && firstNRecordCount > 0) {
            return Math.min(total, firstNRecordCount);
        }
        return total;
    }

    public static Integer getCandidateContactCount(String recordScope, Integer firstNRecordCount) {
        return getCandidateRecordCount('Contact', recordScope, firstNRecordCount);
    }

    public static List<SObject> getPreviewRecords(String objectApiName, Set<String> includedFieldApis, Integer maxRows, String recordScope, Integer firstNRecordCount) {
        OOPS_MetadataService.validateObjectApiName(objectApiName);

        Integer limitSize = maxRows;
        if (recordScope == 'First N Records' && firstNRecordCount != null && firstNRecordCount > 0) {
            limitSize = Math.min(limitSize, firstNRecordCount);
        }

        Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> describeFieldMap = objectDescribe.fields.getMap();

        Set<String> selectFieldSet = new Set<String>{ 'Id' };
        for (String fieldApi : includedFieldApis) {
            if (!String.isBlank(fieldApi) && describeFieldMap.containsKey(fieldApi)) {
                selectFieldSet.add(fieldApi);
            }
        }

        List<String> selectFields = new List<String>();
        selectFields.addAll(selectFieldSet);
        selectFields.sort();

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM ' + objectApiName;
        if (describeFieldMap.containsKey('CreatedDate')) {
            soql += ' ORDER BY CreatedDate ASC';
        }
        soql += ' LIMIT ' + limitSize;
        return Database.query(soql);
    }

    public static List<Contact> getPreviewContacts(Integer maxRows, String recordScope, Integer firstNRecordCount) {
        Set<String> fields = new Set<String>{ 'FirstName', 'LastName', 'Email', 'Phone', 'MobilePhone', 'HomePhone', 'OtherPhone', 'AssistantPhone', 'Fax' };
        List<SObject> rows = getPreviewRecords('Contact', fields, maxRows, recordScope, firstNRecordCount);
        List<Contact> contacts = new List<Contact>();
        for (SObject row : rows) {
            contacts.add((Contact) row);
        }
        return contacts;
    }

    public static Contact getContactById(Id contactId) {
        List<Contact> rows = [
            SELECT Id, Name
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    public static Integer countMaskingExceptionsByRun(Id runId) {
        return [
            SELECT COUNT()
            FROM MaskingException__c
            WHERE MaskingRun__c = :runId
            AND (FieldApiName__c = null OR FieldApiName__c != 'Skipped')
        ];
    }

    public static Integer countSkippedDiagnosticsByRun(Id runId) {
        return [
            SELECT COUNT()
            FROM MaskingException__c
            WHERE MaskingRun__c = :runId
            AND FieldApiName__c = 'Skipped'
        ];
    }

    public static List<MaskingException__c> getRunOutcomeDiagnostics(Id runId, Integer maxRows) {
        Integer limitRows = (maxRows == null || maxRows <= 0) ? 100 : maxRows;
        if (limitRows > 100) {
            limitRows = 100;
        }

        return [
            SELECT Id, SourceObjectApiName__c, SourceRecordId__c, ErrorMessage__c, FieldApiName__c, OccurredAt__c
            FROM MaskingException__c
            WHERE MaskingRun__c = :runId
            ORDER BY CreatedDate DESC
            LIMIT :limitRows
        ];
    }

    public static List<MaskingRun__c> getActiveMaskingRuns() {
        return [
            SELECT Id, Status__c
            FROM MaskingRun__c
            WHERE RunType__c = 'Masking'
            AND Status__c IN ('Queued', 'Running', 'Aborting')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    public static List<MaskingRun__c> getActiveContactMaskingRuns() {
        return getActiveMaskingRuns();
    }

    public static void insertRun(MaskingRun__c runRow) {
        List<MaskingRun__c> rows = new List<MaskingRun__c>{ runRow };
        rows = (List<MaskingRun__c>) Security.stripInaccessible(AccessType.CREATABLE, rows).getRecords();
        insert rows;
        runRow.Id = rows[0].Id;
    }

    public static void updateRun(MaskingRun__c runRow) {
        List<MaskingRun__c> rows = new List<MaskingRun__c>{ runRow };
        rows = (List<MaskingRun__c>) Security.stripInaccessible(AccessType.UPDATABLE, rows).getRecords();
        update rows;
    }

    public static void updateRuns(List<MaskingRun__c> runRows) {
        if (!runRows.isEmpty()) {
            runRows = (List<MaskingRun__c>) Security.stripInaccessible(AccessType.UPDATABLE, runRows).getRecords();
            update runRows;
        }
    }

    public static void insertMaskingExceptions(List<MaskingException__c> exceptionRows) {
        if (!exceptionRows.isEmpty()) {
            exceptionRows = (List<MaskingException__c>) Security.stripInaccessible(AccessType.CREATABLE, exceptionRows).getRecords();
            insert exceptionRows;
        }
    }

    public static MaskingRun__c getRunById(Id runId) {
        Map<String, Schema.SObjectField> fieldMap = MaskingRun__c.SObjectType.getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{ 'Id' };
        List<String> optional = new List<String>{
            'RunType__c',
            'Status__c',
            'RecordsAttempted__c',
            'RecordsUpdated__c',
            'RecordsFailed__c',
            'RecordsSkipped__c',
            'ExceptionCount__c',
            'AsyncJobId__c',
            'StartedAt__c',
            'CompletedAt__c',
            'ErrorSummary__c'
        };
        for (String fieldApi : optional) {
            if (fieldMap.containsKey(fieldApi) && fieldMap.get(fieldApi).getDescribe().isAccessible()) {
                queryFields.add(fieldApi);
            }
        }

        String soql = 'SELECT ' + String.join(queryFields, ', ') +
            ' FROM MaskingRun__c WHERE Id = :runId LIMIT 1';
        List<MaskingRun__c> rows = (List<MaskingRun__c>) Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    public static void incrementRunCounters(Id runId, Integer attemptedDelta, Integer updatedDelta, Integer failedDelta) {
        Map<String, Schema.SObjectField> fieldMap = MaskingRun__c.SObjectType.getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{ 'Id' };
        if (fieldMap.containsKey('RecordsAttempted__c') && fieldMap.get('RecordsAttempted__c').getDescribe().isAccessible()) queryFields.add('RecordsAttempted__c');
        if (fieldMap.containsKey('RecordsUpdated__c') && fieldMap.get('RecordsUpdated__c').getDescribe().isAccessible()) queryFields.add('RecordsUpdated__c');
        if (fieldMap.containsKey('RecordsFailed__c') && fieldMap.get('RecordsFailed__c').getDescribe().isAccessible()) queryFields.add('RecordsFailed__c');

        String soql = 'SELECT ' + String.join(queryFields, ', ') +
            ' FROM MaskingRun__c WHERE Id = :runId LIMIT 1';
        List<MaskingRun__c> rows = (List<MaskingRun__c>) Database.query(soql);
        if (rows.isEmpty()) {
            return;
        }

        MaskingRun__c runRow = rows[0];
        if (queryFields.contains('RecordsAttempted__c')) {
            Integer current = toInt(runRow.get('RecordsAttempted__c'));
            runRow.put('RecordsAttempted__c', current + attemptedDelta);
        }
        if (queryFields.contains('RecordsUpdated__c')) {
            Integer current = toInt(runRow.get('RecordsUpdated__c'));
            runRow.put('RecordsUpdated__c', current + updatedDelta);
        }
        if (queryFields.contains('RecordsFailed__c')) {
            Integer current = toInt(runRow.get('RecordsFailed__c'));
            runRow.put('RecordsFailed__c', current + failedDelta);
        }
        updateRun(runRow);
    }

    public static void finalizeRun(Id runId, Integer skippedCount, Integer exceptionCount, Datetime startedAt, Datetime completedAt, String terminalStatus) {
        MaskingRun__c runRow = new MaskingRun__c(Id = runId);
        Map<String, Schema.SObjectField> fieldMap = MaskingRun__c.SObjectType.getDescribe().fields.getMap();

        if (fieldMap.containsKey('RecordsSkipped__c')) runRow.put('RecordsSkipped__c', skippedCount);
        if (fieldMap.containsKey('ExceptionCount__c')) runRow.put('ExceptionCount__c', exceptionCount);
        if (fieldMap.containsKey('CompletedAt__c')) runRow.put('CompletedAt__c', completedAt);
        if (fieldMap.containsKey('DurationSeconds__c') && startedAt != null && completedAt != null) {
            runRow.put('DurationSeconds__c', Integer.valueOf((completedAt.getTime() - startedAt.getTime()) / 1000));
        }
        if (fieldMap.containsKey('Status__c')) runRow.put('Status__c', terminalStatus);
        updateRun(runRow);
    }

    public static Integer toInt(Object value) {
        if (value == null) {
            return 0;
        }
        return Integer.valueOf(String.valueOf(value));
    }

    public static Integer getIntegerField(SObject row, String fieldApiName) {
        try {
            Object value = row.get(fieldApiName);
            return value == null ? 0 : Integer.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return 0;
        }
    }
}
