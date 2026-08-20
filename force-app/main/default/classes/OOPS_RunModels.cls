public with sharing class OOPS_RunModels {
    public class ConfigurationOption {
        @AuraEnabled public Id configurationId { get; set; }
        @AuraEnabled public String configurationName { get; set; }
    }

    public class PreviewFieldDelta {
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String beforeValue { get; set; }
        @AuraEnabled public String afterValue { get; set; }
        @AuraEnabled public Boolean changed { get; set; }
    }

    public class PreviewRecord {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<PreviewFieldDelta> fieldDeltas { get; set; }

        public PreviewRecord() {
            fieldDeltas = new List<PreviewFieldDelta>();
        }
    }

    public class PreviewResponse {
        @AuraEnabled public Id runId { get; set; }
        @AuraEnabled public String runStatus { get; set; }
        @AuraEnabled public Integer sampledRecordCount { get; set; }
        @AuraEnabled public List<PreviewRecord> records { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }

        public PreviewResponse() {
            records = new List<PreviewRecord>();
            warnings = new List<String>();
        }
    }

    public class ExecutionResponse {
        @AuraEnabled public Id runId { get; set; }
        @AuraEnabled public String runStatus { get; set; }
        @AuraEnabled public String asyncJobId { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class RunStatusResponse {
        @AuraEnabled public Id runId { get; set; }
        @AuraEnabled public String runType { get; set; }
        @AuraEnabled public String runStatus { get; set; }
        @AuraEnabled public Integer recordsAttempted { get; set; }
        @AuraEnabled public Integer recordsUpdated { get; set; }
        @AuraEnabled public Integer recordsFailed { get; set; }
        @AuraEnabled public Integer recordsSkipped { get; set; }
        @AuraEnabled public Integer exceptionCount { get; set; }
        @AuraEnabled public String asyncJobId { get; set; }
        @AuraEnabled public Datetime startedAt { get; set; }
        @AuraEnabled public Datetime completedAt { get; set; }
        @AuraEnabled public String errorSummary { get; set; }
        @AuraEnabled public List<RunRecordOutcome> recordOutcomes { get; set; }

        public RunStatusResponse() {
            recordOutcomes = new List<RunRecordOutcome>();
        }
    }

    public class RunRecordOutcome {
        @AuraEnabled public String outcomeType { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public String reason { get; set; }
        @AuraEnabled public Datetime occurredAt { get; set; }
    }
}
