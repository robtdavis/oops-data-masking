public with sharing class OOPS_MaskingRules {
    public static final String FIXED_PHONE_VALUE = '555-555-1212';

    public static String maskFirstName() {
        return 'Contact';
    }

    public static String maskLastName(Id contactId) {
        String idString = String.valueOf(contactId);
        Integer startAt = Math.max(0, idString.length() - 6);
        return 'Contact-' + idString.substring(startAt);
    }

    public static String maskEmail(String emailValue) {
        if (String.isBlank(emailValue)) {
            return emailValue;
        }
        String lowered = emailValue.toLowerCase();
        if (lowered.endsWith('.invalid')) {
            return emailValue;
        }
        return emailValue + '.invalid';
    }

    public static String maskPhone() {
        return FIXED_PHONE_VALUE;
    }

    public static Object getMaskedValue(String fieldApiName, Schema.DisplayType fieldType, Contact contactRow) {
        if (fieldApiName == 'FirstName') {
            return maskFirstName();
        }
        if (fieldApiName == 'LastName') {
            return maskLastName(contactRow.Id);
        }
        if (fieldApiName == 'Email') {
            return maskEmail((String) contactRow.get('Email'));
        }
        if (fieldType == Schema.DisplayType.Phone) {
            return maskPhone();
        }
        return contactRow.get(fieldApiName);
    }
}
