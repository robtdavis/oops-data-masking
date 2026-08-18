public with sharing class OOPS_RunController {
    @AuraEnabled(cacheable=true)
    public static List<OOPS_RunModels.ConfigurationOption> getSavedConfigurations() {
        try {
            return OOPS_RunService.getSavedConfigurations();
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load configurations. ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static OOPS_RunModels.PreviewResponse launchPreview(Id configurationId) {
        try {
            return OOPS_RunService.launchPreview(configurationId);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to launch preview. ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static OOPS_RunModels.ExecutionResponse launchExecution(Id configurationId) {
        try {
            return OOPS_RunService.launchExecution(configurationId);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to launch execution. ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static OOPS_RunModels.RunStatusResponse getRunStatus(Id runId) {
        try {
            return OOPS_RunService.getRunStatus(runId);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load run status. ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isSandboxEnvironment() {
        try {
            OOPS_Authorization.assertExecutePermission();
            return OOPS_Authorization.isSandbox();
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to determine org environment. ' + ex.getMessage());
        }
    }
}
