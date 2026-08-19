public with sharing class OOPS_ConfigurationDAO {
    public static MaskingConfiguration__c getConfigurationById(Id configurationId) {
        Map<String, Schema.SObjectField> fieldMap = MaskingConfiguration__c.SObjectType.getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{ 'Id' };
        List<String> optionalFields = new List<String>{
            'ConfigurationName__c',
            'Description__c',
            'Active__c',
            'DefaultBatchSize__c',
            'RecordScope__c',
            'FirstNRecordCount__c',
            'RequirePreviewBeforeExecution__c'
        };

        for (String fieldApiName : optionalFields) {
            if (fieldMap.containsKey(fieldApiName) && fieldMap.get(fieldApiName).getDescribe().isAccessible()) {
                queryFields.add(fieldApiName);
            }
        }

        String soql =
            'SELECT ' + String.join(queryFields, ', ') +
            ' FROM MaskingConfiguration__c WHERE Id = :configurationId LIMIT 1';
        List<MaskingConfiguration__c> rows = (List<MaskingConfiguration__c>) Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<ObjectConfiguration__c> getObjectConfigurationsByConfigurationId(Id configurationId) {
        return [
            SELECT Id, MaskingConfiguration__c, ObjectApiName__c, ObjectLabel__c, ProcessingOrder__c
            FROM ObjectConfiguration__c
            WHERE MaskingConfiguration__c = :configurationId
            ORDER BY ProcessingOrder__c ASC, CreatedDate ASC
        ];
    }

    public static List<FieldConfiguration__c> getFieldConfigurationsByObjectConfigurationIds(Set<Id> objectConfigurationIds) {
        if (objectConfigurationIds == null || objectConfigurationIds.isEmpty()) {
            return new List<FieldConfiguration__c>();
        }

        Map<String, Schema.SObjectField> fieldMap = FieldConfiguration__c.SObjectType.getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{ 'Id', 'ObjectConfiguration__c' };
        List<String> optionalFields = new List<String>{
            'FieldApiName__c',
            'FieldLabel__c',
            'SalesforceDataType__c',
            'FieldLength__c',
            'Included__c',
            'Updateable__c',
            'RequiredField__c',
            'MaskingStrategy__c',
            'FixedReplacementValue__c',
            'UnsupportedReason__c',
            'DisplayOrder__c'
        };

        for (String fieldApiName : optionalFields) {
            if (fieldMap.containsKey(fieldApiName) && fieldMap.get(fieldApiName).getDescribe().isAccessible()) {
                queryFields.add(fieldApiName);
            }
        }

        String soql =
            'SELECT ' + String.join(queryFields, ', ') +
            ' FROM FieldConfiguration__c WHERE ObjectConfiguration__c IN :objectConfigurationIds';

        if (queryFields.contains('DisplayOrder__c')) {
            soql += ' ORDER BY DisplayOrder__c ASC, CreatedDate ASC';
        } else {
            soql += ' ORDER BY CreatedDate ASC';
        }

        return (List<FieldConfiguration__c>) Database.query(soql);
    }

    public static void insertMaskingConfigurations(List<MaskingConfiguration__c> recordsToInsert) {
        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    public static void updateMaskingConfigurations(List<MaskingConfiguration__c> recordsToUpdate) {
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }

    public static void insertObjectConfigurations(List<ObjectConfiguration__c> recordsToInsert) {
        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    public static void updateObjectConfigurations(List<ObjectConfiguration__c> recordsToUpdate) {
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }

    public static void insertFieldConfigurations(List<FieldConfiguration__c> recordsToInsert) {
        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    public static void updateFieldConfigurations(List<FieldConfiguration__c> recordsToUpdate) {
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }

    public static void deleteObjectConfigurationsByIds(Set<Id> idsToDelete) {
        if (idsToDelete == null || idsToDelete.isEmpty()) {
            return;
        }
        delete [SELECT Id FROM ObjectConfiguration__c WHERE Id IN :idsToDelete];
    }

    public static void deleteFieldConfigurationsByIds(Set<Id> idsToDelete) {
        if (idsToDelete == null || idsToDelete.isEmpty()) {
            return;
        }
        delete [SELECT Id FROM FieldConfiguration__c WHERE Id IN :idsToDelete];
    }
}
