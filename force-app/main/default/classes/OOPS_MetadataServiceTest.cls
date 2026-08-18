@IsTest
private class OOPS_MetadataServiceTest {
    @IsTest
    static void getAvailableObjects_includesContactAsSupported() {
        List<OOPS_MetadataService.ObjectOption> objects = OOPS_MetadataService.getAvailableObjects();
        System.assertNotEquals(0, objects.size(), 'Expected at least one object option.');

        Boolean foundContact = false;
        for (OOPS_MetadataService.ObjectOption option : objects) {
            if (option.apiName == 'Contact') {
                foundContact = true;
                System.assertEquals(true, option.supported, 'Contact should be supported.');
                System.assertEquals(true, option.queryable, 'Contact should be queryable.');
            }
        }
        System.assertEquals(true, foundContact, 'Expected Contact option.');
    }

    @IsTest
    static void getAvailableFields_defaultsToExcludedAndContainsSupportedField() {
        List<OOPS_MetadataService.FieldOption> fields = OOPS_MetadataService.getAvailableFields('Contact');
        System.assertNotEquals(0, fields.size(), 'Expected field options for Contact.');

        Boolean foundSupported = false;
        for (OOPS_MetadataService.FieldOption fieldOption : fields) {
            System.assertEquals(false, fieldOption.included, 'Fields should default to unselected.');
            if (fieldOption.supported == true) {
                foundSupported = true;
            }
        }
        System.assertEquals(true, foundSupported, 'Expected at least one supported Contact field.');
    }

    @IsTest
    static void validateObjectApiName_rejectsUnsupportedObject() {
        try {
            OOPS_MetadataService.validateObjectApiName('Account');
            System.assert(false, 'Expected unsupported object exception.');
        } catch (OOPS_ConfigurationException ex) {
            System.assert(ex.getMessage().contains('not supported'), 'Expected not supported message.');
        }
    }
}
