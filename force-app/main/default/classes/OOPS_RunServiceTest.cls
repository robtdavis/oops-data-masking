@IsTest
private class OOPS_RunServiceTest {
    @TestSetup
    static void setupData() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        insert new Contact(FirstName = 'A', LastName = 'One', Email = 'one@example.com', Phone = '1111111111');
        insert new Contact(FirstName = 'B', LastName = 'Two', Email = 'two@example.com', Phone = '2222222222');

        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationName = 'Run Service Config';
        dto.active = true;
        dto.defaultBatchSize = 50;
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
    static void launchPreview_createsRunAndReturnsRows() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        Id cfgId = [SELECT Id FROM MaskingConfiguration__c WHERE ConfigurationName__c = 'Run Service Config' LIMIT 1].Id;

        OOPS_RunModels.PreviewResponse response = OOPS_RunService.launchPreview(cfgId);

        System.assertNotEquals(null, response.runId, 'Preview run must be created only at launch time.');
        System.assert(response.sampledRecordCount > 0, 'Expected sample records.');

        MaskingRun__c runRow = [SELECT RunType__c, Status__c FROM MaskingRun__c WHERE Id = :response.runId LIMIT 1];
        System.assertEquals('Preview', runRow.RunType__c);
        System.assertEquals('Previewed', runRow.Status__c);

        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void launchExecution_requiresSandboxInThisSlice() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = false;
        Id cfgId = [SELECT Id FROM MaskingConfiguration__c WHERE ConfigurationName__c = 'Run Service Config' LIMIT 1].Id;

        try {
            OOPS_RunService.launchExecution(cfgId);
            System.assert(false, 'Expected sandbox-only guard.');
        } catch (OOPS_ConfigurationException ex) {
            System.assert(ex.getMessage().contains('sandbox'));
        }

        OOPS_Authorization.testOverrideHasExecutePermission = null;
        OOPS_Authorization.testOverrideIsSandbox = null;
    }

    @IsTest
    static void launchExecution_blocksWhenActiveRunExists() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = true;

        Id cfgId = [SELECT Id FROM MaskingConfiguration__c WHERE ConfigurationName__c = 'Run Service Config' LIMIT 1].Id;

        OOPS_RunModels.ExecutionResponse first = OOPS_RunService.launchExecution(cfgId);
        System.assertNotEquals(null, first.runId, 'Expected first launch to queue an active run.');

        try {
            OOPS_RunService.launchExecution(cfgId);
            System.assert(false, 'Expected active-run block.');
        } catch (OOPS_ConfigurationException ex) {
            System.assert(ex.getMessage().contains('already active'));
        }

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
