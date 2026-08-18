public with sharing class OOPS_ConfigurationService {
    private static final String RECORD_SCOPE_ALL = 'All Records';
    private static final String RECORD_SCOPE_FIRST_N = 'First N Records';

    public static OOPS_ConfigurationDTO getConfiguration(Id configurationId) {
        OOPS_Authorization.assertConfigurePermission();
        ensureConfigReadAccess();

        if (configurationId == null) {
            return new OOPS_ConfigurationDTO();
        }

        MaskingConfiguration__c parent = OOPS_ConfigurationDAO.getConfigurationById(configurationId);
        if (parent == null) {
            throw new OOPS_ConfigurationException('Masking configuration was not found.');
        }

        List<ObjectConfiguration__c> objectRows = OOPS_ConfigurationDAO.getObjectConfigurationsByConfigurationId(configurationId);
        Set<Id> objectIds = new Set<Id>();
        for (ObjectConfiguration__c row : objectRows) {
            objectIds.add(row.Id);
        }
        List<FieldConfiguration__c> fieldRows = OOPS_ConfigurationDAO.getFieldConfigurationsByObjectConfigurationIds(objectIds);

        Map<Id, List<FieldConfiguration__c>> fieldsByObjectId = new Map<Id, List<FieldConfiguration__c>>();
        for (FieldConfiguration__c fieldRow : fieldRows) {
            if (!fieldsByObjectId.containsKey(fieldRow.ObjectConfiguration__c)) {
                fieldsByObjectId.put(fieldRow.ObjectConfiguration__c, new List<FieldConfiguration__c>());
            }
            fieldsByObjectId.get(fieldRow.ObjectConfiguration__c).add(fieldRow);
        }

        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationId = parent.Id;
        dto.configurationName = getStringValue(parent, 'ConfigurationName__c');
        dto.description = getStringValue(parent, 'Description__c');
        dto.active = getBooleanValue(parent, 'Active__c', false);
        dto.defaultBatchSize = getIntegerValue(parent, 'DefaultBatchSize__c');
        dto.recordScope = getStringValue(parent, 'RecordScope__c');
        dto.firstNRecordCount = getIntegerValue(parent, 'FirstNRecordCount__c');
        dto.requirePreviewBeforeExecution = getBooleanValue(parent, 'RequirePreviewBeforeExecution__c', true);

        for (ObjectConfiguration__c objectRow : objectRows) {
            OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
            objectDto.objectConfigurationId = objectRow.Id;
            objectDto.objectApiName = objectRow.ObjectApiName__c;
            objectDto.objectLabel = objectRow.ObjectLabel__c;
            objectDto.included = true;
            objectDto.processingOrder = 1;

            List<FieldConfiguration__c> children = fieldsByObjectId.get(objectRow.Id);
            if (children != null) {
                for (FieldConfiguration__c childRow : children) {
                    OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
                    fieldDto.fieldConfigurationId = childRow.Id;
                    fieldDto.fieldApiName = getStringValue(childRow, 'FieldApiName__c');
                    fieldDto.fieldLabel = getStringValue(childRow, 'FieldLabel__c');
                    fieldDto.salesforceDataType = getStringValue(childRow, 'SalesforceDataType__c');
                    fieldDto.fieldLength = getIntegerValue(childRow, 'FieldLength__c');
                    fieldDto.included = getBooleanValue(childRow, 'Included__c', false);
                    fieldDto.updateable = getBooleanValue(childRow, 'Updateable__c', false);
                    fieldDto.required = getBooleanValue(childRow, 'RequiredField__c', false);
                    fieldDto.maskingStrategy = getStringValue(childRow, 'MaskingStrategy__c');
                    fieldDto.fixedReplacementValue = getStringValue(childRow, 'FixedReplacementValue__c');
                    fieldDto.unsupportedReason = getStringValue(childRow, 'UnsupportedReason__c');
                    fieldDto.displayOrder = getIntegerValue(childRow, 'DisplayOrder__c') == null ? 1 : getIntegerValue(childRow, 'DisplayOrder__c');
                    objectDto.fieldConfigurations.add(fieldDto);
                }
            }
            dto.objectConfigurations.add(objectDto);
        }

        return dto;
    }

    public static Id saveConfiguration(OOPS_ConfigurationDTO configuration) {
        OOPS_Authorization.assertConfigurePermission();
        validateConfiguration(configuration);

        ensureConfigWriteAccess(configuration.configurationId != null);
        ensureObjectConfigWriteAccess();
        ensureFieldConfigWriteAccess();

        normalizeForSave(configuration);

        MaskingConfiguration__c parent;
        if (configuration.configurationId == null) {
            parent = new MaskingConfiguration__c();
        } else {
            parent = new MaskingConfiguration__c(Id = configuration.configurationId);
        }

        parent.ConfigurationName__c = configuration.configurationName;
        parent.Description__c = configuration.description;
        parent.Active__c = configuration.active;
        parent.DefaultBatchSize__c = configuration.defaultBatchSize;
        parent.RecordScope__c = configuration.recordScope;
        parent.FirstNRecordCount__c = configuration.firstNRecordCount;
        parent.RequirePreviewBeforeExecution__c = configuration.requirePreviewBeforeExecution;

        if (configuration.configurationId == null) {
            List<MaskingConfiguration__c> insertRows = new List<MaskingConfiguration__c>{ parent };
            insertRows = (List<MaskingConfiguration__c>) Security.stripInaccessible(AccessType.CREATABLE, insertRows).getRecords();
            OOPS_ConfigurationDAO.insertMaskingConfigurations(insertRows);
            parent = insertRows[0];
            configuration.configurationId = parent.Id;
        } else {
            List<MaskingConfiguration__c> updateRows = new List<MaskingConfiguration__c>{ parent };
            updateRows = (List<MaskingConfiguration__c>) Security.stripInaccessible(AccessType.UPDATABLE, updateRows).getRecords();
            OOPS_ConfigurationDAO.updateMaskingConfigurations(updateRows);
        }

        List<ObjectConfiguration__c> existingObjects = OOPS_ConfigurationDAO.getObjectConfigurationsByConfigurationId(parent.Id);
        Map<String, ObjectConfiguration__c> existingObjectByApi = new Map<String, ObjectConfiguration__c>();
        Set<Id> existingObjectIds = new Set<Id>();
        for (ObjectConfiguration__c row : existingObjects) {
            existingObjectByApi.put(row.ObjectApiName__c, row);
            existingObjectIds.add(row.Id);
        }

        List<FieldConfiguration__c> existingFields = OOPS_ConfigurationDAO.getFieldConfigurationsByObjectConfigurationIds(existingObjectIds);
        Map<Id, Map<String, FieldConfiguration__c>> existingFieldByObjectAndApi = new Map<Id, Map<String, FieldConfiguration__c>>();
        for (FieldConfiguration__c row : existingFields) {
            if (!existingFieldByObjectAndApi.containsKey(row.ObjectConfiguration__c)) {
                existingFieldByObjectAndApi.put(row.ObjectConfiguration__c, new Map<String, FieldConfiguration__c>());
            }
            existingFieldByObjectAndApi.get(row.ObjectConfiguration__c).put(row.FieldApiName__c, row);
        }

        List<OOPS_ConfigurationDTO.ObjectConfigurationDTO> incomingIncludedObjects = new List<OOPS_ConfigurationDTO.ObjectConfigurationDTO>();
        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : configuration.objectConfigurations) {
            if (objectDto != null && objectDto.included == true) {
                incomingIncludedObjects.add(objectDto);
            }
        }

        List<ObjectConfiguration__c> objectInserts = new List<ObjectConfiguration__c>();
        List<ObjectConfiguration__c> objectUpdates = new List<ObjectConfiguration__c>();
        Map<String, Id> objectIdByApi = new Map<String, Id>();

        Integer objectOrder = 1;
        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : incomingIncludedObjects) {
            ObjectConfiguration__c existing = existingObjectByApi.get(objectDto.objectApiName);
            if (existing == null) {
                ObjectConfiguration__c insertRow = new ObjectConfiguration__c();
                insertRow.MaskingConfiguration__c = parent.Id;
                insertRow.ObjectApiName__c = objectDto.objectApiName;
                insertRow.ObjectLabel__c = objectDto.objectLabel;
                insertRow.ProcessingOrder__c = objectOrder;
                insertRow.LastMetadataReviewAt__c = System.now();
                objectInserts.add(insertRow);
            } else {
                existing.ObjectLabel__c = objectDto.objectLabel;
                existing.ProcessingOrder__c = objectOrder;
                existing.LastMetadataReviewAt__c = System.now();
                objectUpdates.add(existing);
                objectIdByApi.put(existing.ObjectApiName__c, existing.Id);
            }
            objectOrder++;
        }

        if (!objectInserts.isEmpty()) {
            objectInserts = (List<ObjectConfiguration__c>) Security.stripInaccessible(AccessType.CREATABLE, objectInserts).getRecords();
            OOPS_ConfigurationDAO.insertObjectConfigurations(objectInserts);
            for (ObjectConfiguration__c row : objectInserts) {
                objectIdByApi.put(row.ObjectApiName__c, row.Id);
            }
        }
        if (!objectUpdates.isEmpty()) {
            objectUpdates = (List<ObjectConfiguration__c>) Security.stripInaccessible(AccessType.UPDATABLE, objectUpdates).getRecords();
            OOPS_ConfigurationDAO.updateObjectConfigurations(objectUpdates);
        }

        Set<String> incomingObjectApis = new Set<String>();
        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : incomingIncludedObjects) {
            incomingObjectApis.add(objectDto.objectApiName);
        }

        Set<Id> objectIdsToDelete = new Set<Id>();
        for (ObjectConfiguration__c existing : existingObjects) {
            if (!incomingObjectApis.contains(existing.ObjectApiName__c)) {
                objectIdsToDelete.add(existing.Id);
            }
        }

        Set<Id> fieldIdsToDelete = new Set<Id>();
        List<FieldConfiguration__c> fieldInserts = new List<FieldConfiguration__c>();
        List<FieldConfiguration__c> fieldUpdates = new List<FieldConfiguration__c>();

        Set<String> maskingStrategyValues = getMaskingStrategyValues();

        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : incomingIncludedObjects) {
            Id objectId = objectIdByApi.get(objectDto.objectApiName);
            Map<String, FieldConfiguration__c> existingByApi = existingFieldByObjectAndApi.get(objectId);
            if (existingByApi == null) {
                existingByApi = new Map<String, FieldConfiguration__c>();
            }

            Map<String, OOPS_MetadataService.FieldOption> supportedFieldMap = new Map<String, OOPS_MetadataService.FieldOption>();
            for (OOPS_MetadataService.FieldOption option : OOPS_MetadataService.getAvailableFields(objectDto.objectApiName)) {
                supportedFieldMap.put(option.apiName, option);
            }

            Set<String> incomingIncludedFieldApis = new Set<String>();
            Integer displayOrder = 1;

            for (OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto : objectDto.fieldConfigurations) {
                if (fieldDto == null || fieldDto.included != true) {
                    continue;
                }
                incomingIncludedFieldApis.add(fieldDto.fieldApiName);

                OOPS_MetadataService.FieldOption metadataField = supportedFieldMap.get(fieldDto.fieldApiName);
                if (metadataField == null || metadataField.supported != true) {
                    continue;
                }

                String maskingStrategy = String.isBlank(fieldDto.maskingStrategy) ? 'Do Not Mask' : fieldDto.maskingStrategy;
                if (!maskingStrategyValues.contains(maskingStrategy)) {
                    throw new OOPS_ConfigurationException('Masking strategy ' + maskingStrategy + ' is not valid.');
                }

                FieldConfiguration__c existingField = existingByApi.get(fieldDto.fieldApiName);
                if (existingField == null) {
                    FieldConfiguration__c insertField = new FieldConfiguration__c();
                    insertField.ObjectConfiguration__c = objectId;
                    insertField.FieldApiName__c = metadataField.apiName;
                    insertField.FieldLabel__c = metadataField.label;
                    insertField.SalesforceDataType__c = metadataField.dataType;
                    insertField.FieldLength__c = metadataField.length;
                    insertField.Included__c = true;
                    insertField.Updateable__c = metadataField.updateable;
                    insertField.RequiredField__c = metadataField.required;
                    insertField.MaskingStrategy__c = maskingStrategy;
                    insertField.FixedReplacementValue__c = fieldDto.fixedReplacementValue;
                    insertField.UnsupportedReason__c = metadataField.unsupportedReason;
                    insertField.DisplayOrder__c = fieldDto.displayOrder == null ? displayOrder : fieldDto.displayOrder;
                    fieldInserts.add(insertField);
                } else {
                    existingField.FieldLabel__c = metadataField.label;
                    existingField.SalesforceDataType__c = metadataField.dataType;
                    existingField.FieldLength__c = metadataField.length;
                    existingField.Included__c = true;
                    existingField.Updateable__c = metadataField.updateable;
                    existingField.RequiredField__c = metadataField.required;
                    existingField.MaskingStrategy__c = maskingStrategy;
                    existingField.FixedReplacementValue__c = fieldDto.fixedReplacementValue;
                    existingField.UnsupportedReason__c = metadataField.unsupportedReason;
                    existingField.DisplayOrder__c = fieldDto.displayOrder == null ? displayOrder : fieldDto.displayOrder;
                    fieldUpdates.add(existingField);
                }
                displayOrder++;
            }

            for (String existingFieldApi : existingByApi.keySet()) {
                if (!incomingIncludedFieldApis.contains(existingFieldApi)) {
                    fieldIdsToDelete.add(existingByApi.get(existingFieldApi).Id);
                }
            }
        }

        if (!fieldIdsToDelete.isEmpty()) {
            OOPS_ConfigurationDAO.deleteFieldConfigurationsByIds(fieldIdsToDelete);
        }
        if (!fieldInserts.isEmpty()) {
            fieldInserts = (List<FieldConfiguration__c>) Security.stripInaccessible(AccessType.CREATABLE, fieldInserts).getRecords();
            OOPS_ConfigurationDAO.insertFieldConfigurations(fieldInserts);
        }
        if (!fieldUpdates.isEmpty()) {
            fieldUpdates = (List<FieldConfiguration__c>) Security.stripInaccessible(AccessType.UPDATABLE, fieldUpdates).getRecords();
            OOPS_ConfigurationDAO.updateFieldConfigurations(fieldUpdates);
        }

        if (!objectIdsToDelete.isEmpty()) {
            OOPS_ConfigurationDAO.deleteObjectConfigurationsByIds(objectIdsToDelete);
        }

        return parent.Id;
    }

    public static void validateConfiguration(OOPS_ConfigurationDTO configuration) {
        if (configuration == null) {
            throw new OOPS_ConfigurationException('Configuration payload is required.');
        }
        if (String.isBlank(configuration.configurationName)) {
            throw new OOPS_ConfigurationException('Configuration Name is required.');
        }
        if (configuration.defaultBatchSize == null || configuration.defaultBatchSize <= 0) {
            throw new OOPS_ConfigurationException('Default Batch Size must be a positive number.');
        }

        Set<String> validScopes = getRecordScopeValues();
        if (String.isBlank(configuration.recordScope) || !validScopes.contains(configuration.recordScope)) {
            throw new OOPS_ConfigurationException('Record Scope must be a valid value from metadata.');
        }

        if (configuration.recordScope == RECORD_SCOPE_FIRST_N) {
            if (configuration.firstNRecordCount == null || configuration.firstNRecordCount <= 0) {
                throw new OOPS_ConfigurationException('First N Record Count must be greater than zero when Record Scope is First N Records.');
            }
        }

        List<OOPS_ConfigurationDTO.ObjectConfigurationDTO> includedObjects = new List<OOPS_ConfigurationDTO.ObjectConfigurationDTO>();
        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : configuration.objectConfigurations) {
            if (objectDto != null && objectDto.included == true) {
                includedObjects.add(objectDto);
            }
        }

        if (includedObjects.isEmpty()) {
            throw new OOPS_ConfigurationException('At least one object must be explicitly included.');
        }

        Set<String> seenObjects = new Set<String>();
        Set<String> maskingStrategyValues = getMaskingStrategyValues();

        for (OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto : includedObjects) {
            if (String.isBlank(objectDto.objectApiName)) {
                throw new OOPS_ConfigurationException('Object API name is required for included objects.');
            }
            if (!seenObjects.add(objectDto.objectApiName)) {
                throw new OOPS_ConfigurationException('Duplicate object selections are not allowed: ' + objectDto.objectApiName);
            }
            OOPS_MetadataService.validateObjectApiName(objectDto.objectApiName);

            Map<String, OOPS_MetadataService.FieldOption> availableFieldByApi = new Map<String, OOPS_MetadataService.FieldOption>();
            for (OOPS_MetadataService.FieldOption option : OOPS_MetadataService.getAvailableFields(objectDto.objectApiName)) {
                availableFieldByApi.put(option.apiName, option);
            }

            List<OOPS_ConfigurationDTO.FieldConfigurationDTO> includedFields = new List<OOPS_ConfigurationDTO.FieldConfigurationDTO>();
            for (OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto : objectDto.fieldConfigurations) {
                if (fieldDto != null && fieldDto.included == true) {
                    includedFields.add(fieldDto);
                }
            }

            if (includedFields.isEmpty()) {
                throw new OOPS_ConfigurationException('Each included object must include at least one explicitly selected field.');
            }

            Set<String> seenFields = new Set<String>();
            for (OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto : includedFields) {
                if (String.isBlank(fieldDto.fieldApiName)) {
                    throw new OOPS_ConfigurationException('Included fields must provide a Field API Name.');
                }
                if (!seenFields.add(fieldDto.fieldApiName)) {
                    throw new OOPS_ConfigurationException('Duplicate field selections are not allowed for ' + objectDto.objectApiName + ': ' + fieldDto.fieldApiName);
                }

                OOPS_MetadataService.FieldOption available = availableFieldByApi.get(fieldDto.fieldApiName);
                if (available == null) {
                    throw new OOPS_ConfigurationException('Field ' + fieldDto.fieldApiName + ' is not valid for object ' + objectDto.objectApiName + '.');
                }
                if (available.supported != true) {
                    throw new OOPS_ConfigurationException('Field ' + fieldDto.fieldApiName + ' cannot be included: ' + available.unsupportedReason);
                }
                if (available.updateable != true) {
                    throw new OOPS_ConfigurationException('Field ' + fieldDto.fieldApiName + ' is not updateable and cannot be included.');
                }

                String maskingStrategy = String.isBlank(fieldDto.maskingStrategy) ? 'Do Not Mask' : fieldDto.maskingStrategy;
                if (!maskingStrategyValues.contains(maskingStrategy)) {
                    throw new OOPS_ConfigurationException('Masking strategy ' + maskingStrategy + ' is not a valid Field Configuration value.');
                }
            }
        }
    }

    private static void normalizeForSave(OOPS_ConfigurationDTO configuration) {
        if (configuration.recordScope == RECORD_SCOPE_ALL) {
            configuration.firstNRecordCount = null;
        }
    }

    private static Set<String> getRecordScopeValues() {
        Set<String> values = new Set<String>();
        Schema.DescribeFieldResult describe = MaskingConfiguration__c.RecordScope__c.getDescribe();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            values.add(entry.getValue());
        }
        return values;
    }

    private static Set<String> getMaskingStrategyValues() {
        Set<String> values = new Set<String>();
        Schema.DescribeFieldResult describe = FieldConfiguration__c.MaskingStrategy__c.getDescribe();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            values.add(entry.getValue());
        }
        return values;
    }

    private static void ensureConfigReadAccess() {
        if (!Schema.sObjectType.MaskingConfiguration__c.isAccessible()) {
            throw new OOPS_ConfigurationException('You do not have access to masking configurations.');
        }
        if (!Schema.sObjectType.ObjectConfiguration__c.isAccessible() ||
            !Schema.sObjectType.FieldConfiguration__c.isAccessible()) {
            throw new OOPS_ConfigurationException('You do not have access to configuration child records.');
        }
    }

    private static void ensureConfigWriteAccess(Boolean isUpdate) {
        if (isUpdate) {
            if (!Schema.sObjectType.MaskingConfiguration__c.isUpdateable()) {
                throw new OOPS_ConfigurationException('You do not have update access to masking configurations.');
            }
        } else {
            if (!Schema.sObjectType.MaskingConfiguration__c.isCreateable()) {
                throw new OOPS_ConfigurationException('You do not have create access to masking configurations.');
            }
        }
    }

    private static void ensureObjectConfigWriteAccess() {
        if (!Schema.sObjectType.ObjectConfiguration__c.isCreateable() || !Schema.sObjectType.ObjectConfiguration__c.isUpdateable()) {
            throw new OOPS_ConfigurationException('You do not have required access to object configurations.');
        }
    }

    private static void ensureFieldConfigWriteAccess() {
        if (!Schema.sObjectType.FieldConfiguration__c.isCreateable() || !Schema.sObjectType.FieldConfiguration__c.isUpdateable()) {
            throw new OOPS_ConfigurationException('You do not have required access to field configurations.');
        }
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

    private static Boolean getBooleanValue(SObject row, String fieldApiName, Boolean defaultValue) {
        try {
            Object value = row.get(fieldApiName);
            return value == null ? defaultValue : (Boolean) value;
        } catch (Exception ex) {
            return defaultValue;
        }
    }

}
