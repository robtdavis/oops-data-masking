public with sharing class OOPS_ConfigurationDTO {
    @AuraEnabled public Id configurationId { get; set; }
    @AuraEnabled public String configurationName { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public Boolean active { get; set; }
    @AuraEnabled public Integer defaultBatchSize { get; set; }
    @AuraEnabled public String recordScope { get; set; }
    @AuraEnabled public Integer firstNRecordCount { get; set; }
    @AuraEnabled public Boolean requirePreviewBeforeExecution { get; set; }
    @AuraEnabled public List<ObjectConfigurationDTO> objectConfigurations { get; set; }

    public OOPS_ConfigurationDTO() {
        active = false;
        defaultBatchSize = 200;
        recordScope = 'All Records';
        firstNRecordCount = null;
        requirePreviewBeforeExecution = true;
        objectConfigurations = new List<ObjectConfigurationDTO>();
    }

    public class ObjectConfigurationDTO {
        @AuraEnabled public Id objectConfigurationId { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String objectLabel { get; set; }
        @AuraEnabled public Boolean included { get; set; }
        @AuraEnabled public Integer processingOrder { get; set; }
        @AuraEnabled public List<FieldConfigurationDTO> fieldConfigurations { get; set; }

        public ObjectConfigurationDTO() {
            included = false;
            processingOrder = 1;
            fieldConfigurations = new List<FieldConfigurationDTO>();
        }
    }

    public class FieldConfigurationDTO {
        @AuraEnabled public Id fieldConfigurationId { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String salesforceDataType { get; set; }
        @AuraEnabled public Integer fieldLength { get; set; }
        @AuraEnabled public Boolean included { get; set; }
        @AuraEnabled public Boolean updateable { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public String maskingStrategy { get; set; }
        @AuraEnabled public String fixedReplacementValue { get; set; }
        @AuraEnabled public String unsupportedReason { get; set; }
        @AuraEnabled public Integer displayOrder { get; set; }

        public FieldConfigurationDTO() {
            included = false;
            updateable = false;
            required = false;
            maskingStrategy = 'Do Not Mask';
            displayOrder = 1;
        }
    }
}
