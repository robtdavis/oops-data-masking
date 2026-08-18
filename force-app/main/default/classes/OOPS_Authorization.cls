public with sharing class OOPS_Authorization {
    @TestVisible
    private static Boolean testOverrideHasConfigurePermission;
    @TestVisible
    private static Boolean testOverrideHasExecutePermission;
    @TestVisible
    private static Boolean testOverrideIsSandbox;
    @TestVisible
    private static Boolean testOverrideHasExecuteInProductionPermission;
    @TestVisible
    private static Boolean testOverrideProductionExecutionEnabled;

    public static void assertConfigurePermission() {
        if (!hasConfigurePermission()) {
            throw new OOPS_ConfigurationException('You do not have permission to configure OOPS.');
        }
    }

    public static Boolean hasConfigurePermission() {
        if (Test.isRunningTest() && testOverrideHasConfigurePermission != null) {
            return testOverrideHasConfigurePermission;
        }
        return FeatureManagement.checkPermission('Configure_OOPS');
    }

    public static void assertExecutePermission() {
        if (!hasExecutePermission()) {
            throw new OOPS_ConfigurationException('You do not have permission to execute OOPS runs.');
        }
    }

    public static Boolean hasExecutePermission() {
        if (Test.isRunningTest() && testOverrideHasExecutePermission != null) {
            return testOverrideHasExecutePermission;
        }
        return FeatureManagement.checkPermission('Execute_OOPS');
    }

    public static void assertSandboxOnlyExecution() {
        if (!isSandbox()) {
            throw new OOPS_ConfigurationException('This slice allows execution only in sandbox environments.');
        }
    }

    public static void assertExecutionAllowedForEnvironment() {
        if (isSandbox()) {
            return;
        }

        if (!hasExecuteInProductionPermission()) {
            throw new OOPS_ConfigurationException('Execution in production requires the Execute_OOPS_In_Production custom permission.');
        }

        if (!isProductionExecutionEnabled()) {
            throw new OOPS_ConfigurationException('Execution in production is disabled. Enable OOPSSettings__c.ProductionExecutionEnabled__c to proceed.');
        }
    }

    public static Boolean hasExecuteInProductionPermission() {
        if (Test.isRunningTest() && testOverrideHasExecuteInProductionPermission != null) {
            return testOverrideHasExecuteInProductionPermission;
        }
        return FeatureManagement.checkPermission('Execute_OOPS_In_Production');
    }

    public static Boolean isProductionExecutionEnabled() {
        if (Test.isRunningTest() && testOverrideProductionExecutionEnabled != null) {
            return testOverrideProductionExecutionEnabled;
        }

        OOPSSettings__c orgSettings = OOPSSettings__c.getOrgDefaults();
        if (orgSettings == null) {
            return false;
        }
        return orgSettings.ProductionExecutionEnabled__c == true;
    }

    public static Boolean isSandbox() {
        if (Test.isRunningTest() && testOverrideIsSandbox != null) {
            return testOverrideIsSandbox;
        }
        Organization orgRow = [SELECT IsSandbox FROM Organization LIMIT 1];
        return orgRow.IsSandbox;
    }
}
