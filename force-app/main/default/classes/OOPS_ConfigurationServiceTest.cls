@IsTest
private class OOPS_ConfigurationServiceTest {
    @TestSetup
    static void setupData() {
        insert new Contact(LastName = 'Config Service Test Contact');
    }

    @IsTest
    static void validateConfiguration_rejectsMissingIncludedFields() {
        OOPS_ConfigurationDTO dto = buildBaseDto();
        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;
        dto.objectConfigurations.add(objectDto);

        try {
            OOPS_ConfigurationService.validateConfiguration(dto);
            System.assert(false, 'Expected validation error when no fields are included.');
        } catch (OOPS_ConfigurationException ex) {
            System.assert(ex.getMessage().contains('at least one explicitly selected field'), 'Expected missing fields message.');
        }
    }

    @IsTest
    static void saveAndGetConfiguration_persistsExplicitAllowlistOnly() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        Integer contactsBefore = [SELECT COUNT() FROM Contact];

        List<OOPS_MetadataService.FieldOption> supported = getSupportedContactFields();
        System.assert(supported.size() > 0, 'Expected at least one supported Contact field.');

        OOPS_ConfigurationDTO dto = buildBaseDto();
        dto.objectConfigurations.add(buildObjectDtoWithFields(supported, 1));

        Test.startTest();
        Id configId = OOPS_ConfigurationService.saveConfiguration(dto);
        Test.stopTest();

        System.assertNotEquals(null, configId, 'Expected saved configuration Id.');

        List<ObjectConfiguration__c> createdObjects = [
            SELECT Id, ObjectApiName__c
            FROM ObjectConfiguration__c
            WHERE MaskingConfiguration__c = :configId
        ];
        System.assertEquals(1, createdObjects.size(), 'Expected exactly one included object row.');
        System.assertEquals('Contact', createdObjects[0].ObjectApiName__c, 'Expected Contact object row.');

        List<FieldConfiguration__c> createdFields = [
            SELECT Id, FieldApiName__c
            FROM FieldConfiguration__c
            WHERE ObjectConfiguration__c = :createdObjects[0].Id
        ];
        System.assertEquals(1, createdFields.size(), 'Expected exactly one included field row.');

        Integer contactsAfter = [SELECT COUNT() FROM Contact];
        System.assertEquals(contactsBefore, contactsAfter, 'Saving configuration must not mutate Contact data.');

        if (supported.size() > 1) {
            OOPS_ConfigurationDTO updateDto = buildBaseDto();
            updateDto.configurationId = configId;
            updateDto.configurationName = 'Service Test Config Updated';
            updateDto.objectConfigurations.add(buildObjectDtoWithField(supported[1]));

            OOPS_ConfigurationService.saveConfiguration(updateDto);

            ObjectConfiguration__c objectRow = [
                SELECT Id
                FROM ObjectConfiguration__c
                WHERE MaskingConfiguration__c = :configId
                LIMIT 1
            ];
            List<FieldConfiguration__c> fieldRows = [
                SELECT FieldApiName__c
                FROM FieldConfiguration__c
                WHERE ObjectConfiguration__c = :objectRow.Id
            ];

            Set<String> persistedFieldApis = new Set<String>();
            for (FieldConfiguration__c row : fieldRows) {
                persistedFieldApis.add(row.FieldApiName__c);
            }

            System.assertEquals(1, persistedFieldApis.size(), 'Expected only explicitly selected field to remain after update.');
            System.assertEquals(true, persistedFieldApis.contains(supported[1].apiName), 'Expected updated included field to persist.');
            System.assertEquals(false, persistedFieldApis.contains(supported[0].apiName), 'Expected removed field to be deleted.');
        }

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
    }

    private static OOPS_ConfigurationDTO buildBaseDto() {
        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationName = 'Service Test Config';
        dto.defaultBatchSize = 200;
        dto.recordScope = 'All Records';
        dto.firstNRecordCount = null;
        return dto;
    }

    private static OOPS_ConfigurationDTO.ObjectConfigurationDTO buildObjectDtoWithFields(
        List<OOPS_MetadataService.FieldOption> supported,
        Integer count
    ) {
        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;
        objectDto.processingOrder = 1;

        Integer limitCount = Math.min(count, supported.size());
        for (Integer i = 0; i < limitCount; i++) {
            OOPS_MetadataService.FieldOption option = supported[i];
            OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
            fieldDto.fieldApiName = option.apiName;
            fieldDto.fieldLabel = option.label;
            fieldDto.salesforceDataType = option.dataType;
            fieldDto.included = true;
            fieldDto.updateable = true;
            fieldDto.required = option.required;
            fieldDto.maskingStrategy = 'Do Not Mask';
            fieldDto.displayOrder = i + 1;
            objectDto.fieldConfigurations.add(fieldDto);
        }
        return objectDto;
    }

    private static OOPS_ConfigurationDTO.ObjectConfigurationDTO buildObjectDtoWithField(
        OOPS_MetadataService.FieldOption option
    ) {
        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;
        objectDto.processingOrder = 1;

        OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
        fieldDto.fieldApiName = option.apiName;
        fieldDto.fieldLabel = option.label;
        fieldDto.salesforceDataType = option.dataType;
        fieldDto.included = true;
        fieldDto.updateable = true;
        fieldDto.required = option.required;
        fieldDto.maskingStrategy = 'Do Not Mask';
        fieldDto.displayOrder = 1;
        objectDto.fieldConfigurations.add(fieldDto);

        return objectDto;
    }

    private static List<OOPS_MetadataService.FieldOption> getSupportedContactFields() {
        List<OOPS_MetadataService.FieldOption> fields = OOPS_MetadataService.getAvailableFields('Contact');
        List<OOPS_MetadataService.FieldOption> supported = new List<OOPS_MetadataService.FieldOption>();
        for (OOPS_MetadataService.FieldOption option : fields) {
            if (option.supported == true) {
                supported.add(option);
            }
        }
        return supported;
    }
}
