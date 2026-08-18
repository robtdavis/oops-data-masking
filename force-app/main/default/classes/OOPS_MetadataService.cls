public with sharing class OOPS_MetadataService {
    private static final Set<String> UNSUPPORTED_SYSTEM_FIELDS = new Set<String>{
        'Id', 'IsDeleted', 'CreatedById', 'CreatedDate', 'LastModifiedById', 'LastModifiedDate',
        'SystemModstamp', 'LastViewedDate', 'LastReferencedDate'
    };

    public class ObjectOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public Boolean queryable { get; set; }
        @AuraEnabled public Boolean updateable { get; set; }
        @AuraEnabled public Boolean supported { get; set; }
        @AuraEnabled public String unsupportedReason { get; set; }
    }

    public class FieldOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public String dataType { get; set; }
        @AuraEnabled public Boolean updateable { get; set; }
        @AuraEnabled public Boolean calculated { get; set; }
        @AuraEnabled public Boolean relationshipField { get; set; }
        @AuraEnabled public Boolean supported { get; set; }
        @AuraEnabled public String unsupportedReason { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public Integer length { get; set; }
        @AuraEnabled public Boolean included { get; set; }
    }

    public static List<ObjectOption> getAvailableObjects() {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<ObjectOption> options = new List<ObjectOption>();

        for (String objectApiName : globalDescribe.keySet()) {
            if (isUnsupportedObjectApiName(objectApiName)) {
                continue;
            }

            Schema.DescribeSObjectResult describe = globalDescribe.get(objectApiName).getDescribe();
            if (!describe.isQueryable() || !describe.isUpdateable()) {
                continue;
            }

            ObjectOption option = new ObjectOption();
            option.apiName = objectApiName;
            option.supported = true;
            option.label = describe.getLabel();
            option.queryable = true;
            option.updateable = true;
            option.unsupportedReason = null;
            options.add(option);
        }

        options.sort(new ObjectOptionSorter());
        return options;
    }

    public static List<FieldOption> getAvailableFields(String objectApiName) {
        validateObjectApiName(objectApiName);

        Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();

        List<FieldOption> options = new List<FieldOption>();
        for (Schema.SObjectField fieldRef : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldRef.getDescribe();
            FieldOption option = new FieldOption();
            option.label = fieldDescribe.getLabel();
            option.apiName = fieldDescribe.getName();
            option.dataType = String.valueOf(fieldDescribe.getType());
            option.updateable = fieldDescribe.isUpdateable();
            option.calculated = fieldDescribe.isCalculated();
            option.relationshipField = fieldDescribe.getType() == Schema.DisplayType.Reference;
            option.required = !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate();
            option.length = fieldDescribe.getLength();
            option.supported = true;
            option.unsupportedReason = null;
            option.included = false;

            if (UNSUPPORTED_SYSTEM_FIELDS.contains(option.apiName)) {
                option.supported = false;
                option.unsupportedReason = 'System field is not supported.';
            } else if (fieldDescribe.isCalculated()) {
                option.supported = false;
                option.unsupportedReason = 'Formula fields are not supported.';
            } else if (fieldDescribe.isAutoNumber()) {
                option.supported = false;
                option.unsupportedReason = 'Auto-number fields are not supported.';
            } else if (!fieldDescribe.isUpdateable()) {
                option.supported = false;
                option.unsupportedReason = 'Field is not updateable.';
            } else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                option.supported = false;
                option.unsupportedReason = 'Relationship fields are not supported for masking in this release.';
            } else if (!isSupportedDisplayType(fieldDescribe.getType())) {
                option.supported = false;
                option.unsupportedReason = 'Data type is not supported in this release.';
            }

            options.add(option);
        }

        options.sort(new FieldOptionSorter());
        return options;
    }

    public static void validateObjectApiName(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw new OOPS_ConfigurationException('Object API name is required.');
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            throw new OOPS_ConfigurationException('Object ' + objectApiName + ' was not found.');
        }

        Schema.DescribeSObjectResult describe = globalDescribe.get(objectApiName).getDescribe();
        if (!describe.isQueryable()) {
            throw new OOPS_ConfigurationException('Object ' + objectApiName + ' is not queryable.');
        }
        if (!describe.isUpdateable()) {
            throw new OOPS_ConfigurationException('Object ' + objectApiName + ' is not updateable.');
        }
    }

    private static Boolean isUnsupportedObjectApiName(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return true;
        }
        if (objectApiName.endsWith('ChangeEvent') || objectApiName.endsWith('History') || objectApiName.endsWith('Feed')) {
            return true;
        }
        return false;
    }

    private static Boolean isSupportedDisplayType(Schema.DisplayType displayType) {
        Set<Schema.DisplayType> supported = new Set<Schema.DisplayType>{
            Schema.DisplayType.String,
            Schema.DisplayType.TextArea,
            Schema.DisplayType.EncryptedString,
            Schema.DisplayType.Email,
            Schema.DisplayType.Phone,
            Schema.DisplayType.Url,
            Schema.DisplayType.Integer,
            Schema.DisplayType.Double,
            Schema.DisplayType.Currency,
            Schema.DisplayType.Percent,
            Schema.DisplayType.Date,
            Schema.DisplayType.DateTime,
            Schema.DisplayType.Boolean,
            Schema.DisplayType.Picklist,
            Schema.DisplayType.MultiPicklist
        };
        return supported.contains(displayType);
    }

    private class ObjectOptionSorter implements Comparator<ObjectOption> {
        public Integer compare(ObjectOption a, ObjectOption b) {
            return String.valueOf(a.label).toLowerCase().compareTo(String.valueOf(b.label).toLowerCase());
        }
    }

    private class FieldOptionSorter implements Comparator<FieldOption> {
        public Integer compare(FieldOption a, FieldOption b) {
            return String.valueOf(a.label).toLowerCase().compareTo(String.valueOf(b.label).toLowerCase());
        }
    }
}
