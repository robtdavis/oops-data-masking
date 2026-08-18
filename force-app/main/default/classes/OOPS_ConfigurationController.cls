public with sharing class OOPS_ConfigurationController {
    @AuraEnabled(cacheable=true)
    public static OOPS_ConfigurationDTO getConfiguration(Id configurationId) {
        try {
            OOPS_Authorization.assertConfigurePermission();
            return OOPS_ConfigurationService.getConfiguration(configurationId);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load configuration. ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OOPS_MetadataService.ObjectOption> getAvailableObjects() {
        try {
            OOPS_Authorization.assertConfigurePermission();
            return OOPS_MetadataService.getAvailableObjects();
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load available objects. ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OOPS_MetadataService.FieldOption> getAvailableFields(String objectApiName) {
        try {
            OOPS_Authorization.assertConfigurePermission();
            return OOPS_MetadataService.getAvailableFields(objectApiName);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load available fields. ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static Id saveConfiguration(OOPS_ConfigurationDTO configuration) {
        try {
            OOPS_Authorization.assertConfigurePermission();
            return OOPS_ConfigurationService.saveConfiguration(configuration);
        } catch (OOPS_ConfigurationException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to save configuration. ' + ex.getMessage());
        }
    }
}
