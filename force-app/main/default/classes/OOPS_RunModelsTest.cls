@IsTest
private class OOPS_RunModelsTest {
    @IsTest
    static void constructors_and_properties_are_usable() {
        OOPS_RunModels.ConfigurationOption cfg = new OOPS_RunModels.ConfigurationOption();
        cfg.configurationId = 'a00gL0000000001QAA';
        cfg.configurationName = 'Sample';

        OOPS_RunModels.PreviewFieldDelta delta = new OOPS_RunModels.PreviewFieldDelta();
        delta.fieldApiName = 'Email';
        delta.beforeValue = 'a@example.com';
        delta.afterValue = 'a@example.com.invalid';
        delta.changed = true;

        OOPS_RunModels.PreviewRecord recordDto = new OOPS_RunModels.PreviewRecord();
        recordDto.contactId = '003gL0000000001QAA';
        recordDto.fieldDeltas.add(delta);

        OOPS_RunModels.PreviewResponse preview = new OOPS_RunModels.PreviewResponse();
        preview.runId = 'a01gL0000000001QAA';
        preview.runStatus = 'Previewed';
        preview.sampledRecordCount = 1;
        preview.records.add(recordDto);
        preview.warnings.add('cap reached');

        OOPS_RunModels.ExecutionResponse exec = new OOPS_RunModels.ExecutionResponse();
        exec.runId = 'a01gL0000000002QAA';
        exec.runStatus = 'Queued';
        exec.asyncJobId = '707gL0000000001QAA';
        exec.message = 'queued';

        OOPS_RunModels.RunStatusResponse status = new OOPS_RunModels.RunStatusResponse();
        status.runId = 'a01gL0000000003QAA';
        status.runType = 'Masking';
        status.runStatus = 'Running';
        status.recordsAttempted = 10;
        status.recordsUpdated = 9;
        status.recordsFailed = 1;
        status.recordsSkipped = 0;
        status.exceptionCount = 1;
        status.asyncJobId = '707gL0000000002QAA';
        status.errorSummary = 'none';

        System.assertEquals('Sample', cfg.configurationName);
        System.assertEquals(true, preview.records[0].fieldDeltas[0].changed);
        System.assertEquals('Queued', exec.runStatus);
        System.assertEquals(10, status.recordsAttempted);
    }
}
