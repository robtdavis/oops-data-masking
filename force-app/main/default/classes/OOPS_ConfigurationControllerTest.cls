@IsTest
private class OOPS_ConfigurationControllerTest {
    @IsTest
    static void controllerMethods_workWhenAuthorized() {
        OOPS_Authorization.testOverrideHasConfigurePermission = true;

        List<OOPS_MetadataService.ObjectOption> objects = OOPS_ConfigurationController.getAvailableObjects();
        System.assert(objects.size() > 0, 'Expected object options.');

        List<OOPS_MetadataService.FieldOption> fields = OOPS_ConfigurationController.getAvailableFields('Contact');
        System.assert(fields.size() > 0, 'Expected Contact field options.');

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
    }

    @IsTest
    static void controllerMethods_throwHandledExceptionWhenUnauthorized() {
        OOPS_Authorization.testOverrideHasConfigurePermission = false;

        try {
            OOPS_ConfigurationController.getAvailableObjects();
            System.assert(false, 'Expected authorization failure.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()), 'Expected readable authorization message.');
        }

        OOPS_Authorization.testOverrideHasConfigurePermission = null;
    }
}
