@IsTest
private class OOPS_MaskingBatchTest {
    @TestSetup
    static void setupData() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'F' + i,
                LastName = 'L' + i,
                Email = 'u' + i + '@example.com',
                Phone = '1111111111'
            ));
        }
        contacts.add(new Contact(
            FirstName = 'Long',
            LastName = 'Email',
            Email = 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnop@a.com',
            Phone = '3333333333'
        ));
        insert contacts;

        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationName = 'Batch Config';
        dto.active = true;
        dto.defaultBatchSize = 2;
        dto.recordScope = 'All Records';

        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;

        objectDto.fieldConfigurations.add(buildField('FirstName', 'First Name'));
        objectDto.fieldConfigurations.add(buildField('LastName', 'Last Name'));
        objectDto.fieldConfigurations.add(buildField('Email', 'Email Suffix'));

        dto.objectConfigurations.add(objectDto);
        OOPS_ConfigurationService.saveConfiguration(dto);
        OOPS_Authorization.testOverrideHasConfigurePermission = null;
    }

    @IsTest
    static void batch_updatesContactsAndCompletes() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = true;

        Id cfgId = [SELECT Id FROM MaskingConfiguration__c WHERE ConfigurationName__c = 'Batch Config' LIMIT 1].Id;

        Test.startTest();
        OOPS_RunModels.ExecutionResponse response = OOPS_RunService.launchExecution(cfgId);
        Test.stopTest();

        System.assertNotEquals(null, response.runId, 'Expected run id.');

        MaskingRun__c runRow = [
            SELECT Status__c
            FROM MaskingRun__c
            WHERE Id = :response.runId
            LIMIT 1
        ];

        System.assert(runRow.Status__c == 'Completed' || runRow.Status__c == 'Completed with Exceptions', 'Expected terminal status.');

        List<Contact> updated = [SELECT FirstName, LastName, Email FROM Contact ORDER BY CreatedDate ASC LIMIT 5];
        System.assertEquals('Contact', updated[0].FirstName, 'FirstName should be masked.');
        System.assert(updated[0].LastName.startsWith('Contact-'), 'LastName should be deterministic masked value.');
        System.assert(updated[0].Email.endsWith('.invalid'), 'Email should append invalid suffix.');

        OOPS_Authorization.testOverrideHasExecutePermission = null;
        OOPS_Authorization.testOverrideIsSandbox = null;
    }

    @IsTest
    static void batch_partialSuccess_capturesExceptions() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = true;

        Id cfgId = [SELECT Id FROM MaskingConfiguration__c WHERE ConfigurationName__c = 'Batch Config' LIMIT 1].Id;

        Test.startTest();
        OOPS_RunModels.ExecutionResponse second = OOPS_RunService.launchExecution(cfgId);
        Test.stopTest();

        Integer exceptionCount = [SELECT COUNT() FROM MaskingException__c WHERE MaskingRun__c = :second.runId];
        System.assert(exceptionCount > 0, 'Expected at least one masking exception from overlength email update.');

        OOPS_Authorization.testOverrideHasExecutePermission = null;
        OOPS_Authorization.testOverrideIsSandbox = null;
    }

    private static OOPS_ConfigurationDTO.FieldConfigurationDTO buildField(String apiName, String strategy) {
        OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
        fieldDto.fieldApiName = apiName;
        fieldDto.fieldLabel = apiName;
        fieldDto.salesforceDataType = 'String';
        fieldDto.included = true;
        fieldDto.updateable = true;
        fieldDto.required = (apiName == 'LastName');
        fieldDto.maskingStrategy = strategy;
        return fieldDto;
    }
}
