@IsTest
private class OOPS_ConfigurationDAOTest {
    @IsTest
    static void getFieldConfigurations_returnsEmptyForEmptyInput() {
        List<FieldConfiguration__c> rows = OOPS_ConfigurationDAO.getFieldConfigurationsByObjectConfigurationIds(new Set<Id>());
        System.assertEquals(0, rows.size(), 'Expected no rows for empty object configuration id input.');
    }

    @IsTest
    static void deleteMethods_acceptEmptySets() {
        Test.startTest();
        OOPS_ConfigurationDAO.deleteFieldConfigurationsByIds(new Set<Id>());
        OOPS_ConfigurationDAO.deleteObjectConfigurationsByIds(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Delete methods should no-op on empty sets.');
    }
}
