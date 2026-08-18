@IsTest
private class OOPS_MaskingRulesTest {
    @IsTest
    static void rules_applyExpectedDeterministicValues() {
        Contact c = new Contact(LastName = 'Original', FirstName = 'Before', Email = 'user@example.com', Phone = '111-111-1111');
        insert c;

        System.assertEquals('Contact', OOPS_MaskingRules.maskFirstName());

        String maskedLast = OOPS_MaskingRules.maskLastName(c.Id);
        System.assert(maskedLast.startsWith('Contact-'), 'Expected deterministic prefix.');
        System.assertEquals(14, maskedLast.length(), 'Expected Contact- + 6 chars.');

        System.assertEquals('user@example.com.invalid', OOPS_MaskingRules.maskEmail('user@example.com'));
        System.assertEquals('user@example.com.invalid', OOPS_MaskingRules.maskEmail('user@example.com.invalid'));
        System.assertEquals('555-555-1212', OOPS_MaskingRules.maskPhone());
    }
}
