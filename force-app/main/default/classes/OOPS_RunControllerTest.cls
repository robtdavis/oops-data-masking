@IsTest
private class OOPS_RunControllerTest {
    @IsTest
    static void getSavedConfigurations_authorized() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        OOPS_Authorization.testOverrideHasExecutePermission = true;

        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationName = 'Controller Config';
        dto.active = true;
        dto.defaultBatchSize = 50;
        dto.recordScope = 'All Records';

        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;

        OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
        fieldDto.fieldApiName = 'LastName';
        fieldDto.fieldLabel = 'Last Name';
        fieldDto.salesforceDataType = 'String';
        fieldDto.included = true;
        fieldDto.maskingStrategy = 'Last Name';
        objectDto.fieldConfigurations.add(fieldDto);
        dto.objectConfigurations.add(objectDto);
        OOPS_ConfigurationService.saveConfiguration(dto);

        List<OOPS_RunModels.ConfigurationOption> options = OOPS_RunController.getSavedConfigurations();
        System.assertNotEquals(null, options, 'Expected a list response.');

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void getSavedConfigurations_unauthorizedThrowsHandled() {
        OOPS_Authorization.testOverrideHasExecutePermission = false;

        try {
            OOPS_RunController.getSavedConfigurations();
            System.assert(false, 'Expected authorization exception.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void launchPreview_worksWhenAuthorized() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        OOPS_Authorization.testOverrideHasExecutePermission = true;

        Id cfgId = createConfig('Controller Preview Config');

        OOPS_RunModels.PreviewResponse preview = OOPS_RunController.launchPreview(cfgId);
        System.assertNotEquals(null, preview.runId, 'Expected preview run id.');

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void getRunStatus_invalidId_throwsHandled() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;

        try {
            OOPS_RunController.getRunStatus('a01gL0000000001QAA');
            System.assert(false, 'Expected handled error for invalid run id.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()), 'Expected readable message.');
        }

        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void getRunStatus_previewRun_returnsHandledOutcome() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        OOPS_Authorization.testOverrideHasExecutePermission = true;

        Id cfgId = createConfig('Controller Status Config');
        OOPS_RunModels.PreviewResponse preview = OOPS_RunController.launchPreview(cfgId);

        try {
            OOPS_RunController.getRunStatus(preview.runId);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()), 'Expected readable handled message when status lookup is restricted.');
        }

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void launchPreview_invalidConfig_throwsHandled() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;

        try {
            OOPS_RunController.launchPreview('a00gL0000000001QAA');
            System.assert(false, 'Expected handled exception for invalid config.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        OOPS_Authorization.testOverrideHasExecutePermission = null;
    }

    @IsTest
    static void launchExecution_invalidConfig_throwsHandled() {
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = true;

        try {
            OOPS_RunController.launchExecution('a00gL0000000002QAA');
            System.assert(false, 'Expected handled exception for invalid config.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        OOPS_Authorization.testOverrideHasExecutePermission = null;
        OOPS_Authorization.testOverrideIsSandbox = null;
    }

    @IsTest
    static void launchExecution_worksWhenSandboxAllowed() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;
        OOPS_Authorization.testOverrideHasExecutePermission = true;
        OOPS_Authorization.testOverrideIsSandbox = true;

        Id cfgId = createConfig('Controller Execute Config');

        Test.startTest();
        OOPS_RunModels.ExecutionResponse execution = OOPS_RunController.launchExecution(cfgId);
        Test.stopTest();

        System.assertNotEquals(null, execution.runId, 'Expected execution run id.');

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
        OOPS_Authorization.testOverrideHasExecutePermission = null;
        OOPS_Authorization.testOverrideIsSandbox = null;
    }

    private static Id createConfig(String configName) {
        OOPS_ConfigurationDTO dto = new OOPS_ConfigurationDTO();
        dto.configurationName = configName;
        dto.active = true;
        dto.defaultBatchSize = 50;
        dto.recordScope = 'All Records';

        OOPS_ConfigurationDTO.ObjectConfigurationDTO objectDto = new OOPS_ConfigurationDTO.ObjectConfigurationDTO();
        objectDto.objectApiName = 'Contact';
        objectDto.objectLabel = 'Contact';
        objectDto.included = true;

        OOPS_ConfigurationDTO.FieldConfigurationDTO fieldDto = new OOPS_ConfigurationDTO.FieldConfigurationDTO();
        fieldDto.fieldApiName = 'LastName';
        fieldDto.fieldLabel = 'Last Name';
        fieldDto.salesforceDataType = 'String';
        fieldDto.included = true;
        fieldDto.maskingStrategy = 'Last Name';
        objectDto.fieldConfigurations.add(fieldDto);

        dto.objectConfigurations.add(objectDto);
        return OOPS_ConfigurationService.saveConfiguration(dto);
    }
}
