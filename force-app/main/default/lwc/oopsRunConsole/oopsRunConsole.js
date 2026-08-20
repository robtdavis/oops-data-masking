import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getSavedConfigurations from '@salesforce/apex/OOPS_RunController.getSavedConfigurations';
import launchPreview from '@salesforce/apex/OOPS_RunController.launchPreview';
import launchExecution from '@salesforce/apex/OOPS_RunController.launchExecution';
import getRunStatus from '@salesforce/apex/OOPS_RunController.getRunStatus';
import isSandboxEnvironment from '@salesforce/apex/OOPS_RunController.isSandboxEnvironment';

const SHARED_SELECTION_KEY = 'oops.selectedConfigurationId';
const SHARED_SELECTION_EVENT = 'oopsconfigurationselection';
const RUN_STATUS_POLL_INTERVAL_MS = 3000;

export default class OopsRunConsole extends LightningElement {
    @track loading = false;
    @track running = false;
    @track statusRefreshing = false;
    @track configs = [];
    @track selectedConfigurationId;

    @track previewRows = [];
    @track previewRunId;

    @track runId;
    @track runStatus;
    @track runCounters;
    @track runRecordOutcomes = [];
    @track sandboxEnvironment;

    runStatusPollHandle;
    lastKnownRunStatus;

    connectedCallback() {
        this.loadEnvironment();
        this.loadConfigurations();
    }

    disconnectedCallback() {
        this.stopRunStatusPolling();
    }

    get configOptions() {
        return this.configs.map((c) => ({ label: c.configurationName, value: c.configurationId }));
    }

    get canExecute() {
        return !!this.selectedConfigurationId && !this.loading && !this.running;
    }

    get hasActiveExecution() {
        return !!this.runId && !this.isTerminalStatus(this.runStatus);
    }

    get disableActionButtons() {
        return !this.canExecute || this.hasActiveExecution;
    }

    get disableRefreshButton() {
        return this.statusRefreshing || !this.runId;
    }

    get isRunStatusTerminal() {
        return this.isTerminalStatus(this.runStatus);
    }

    get showPreviewPanel() {
        return !!this.previewRunId && !this.hasActiveExecution;
    }

    async loadConfigurations() {
        this.loading = true;
        try {
            this.configs = await getSavedConfigurations();
            this.hydrateSelectedConfigurationFromSharedState();
        } catch (error) {
            this.showError(error, 'Unable to load configurations.');
        } finally {
            this.loading = false;
        }
    }

    async loadEnvironment() {
        try {
            this.sandboxEnvironment = await isSandboxEnvironment();
        } catch (error) {
            this.sandboxEnvironment = null;
        }
    }

    handleConfigurationChange(event) {
        this.selectedConfigurationId = event.detail.value;
        this.publishSelectedConfiguration();
    }

    hydrateSelectedConfigurationFromSharedState() {
        const sharedConfigurationId = this.getSharedConfigurationId();
        if (!sharedConfigurationId) {
            return;
        }

        const existsInOptions = this.configs.some((config) => config.configurationId === sharedConfigurationId);
        if (existsInOptions) {
            this.selectedConfigurationId = sharedConfigurationId;
        }
    }

    publishSelectedConfiguration() {
        try {
            const valueToStore = this.selectedConfigurationId || '';
            window.localStorage.setItem(SHARED_SELECTION_KEY, valueToStore);
            window.dispatchEvent(
                new CustomEvent(SHARED_SELECTION_EVENT, {
                    detail: { configurationId: this.selectedConfigurationId || null }
                })
            );
        } catch (storageError) {
            // Ignore storage restrictions in hardened browser contexts.
        }
    }

    getSharedConfigurationId() {
        try {
            const storedValue = window.localStorage.getItem(SHARED_SELECTION_KEY);
            return storedValue || null;
        } catch (storageError) {
            return null;
        }
    }

    async handlePreview() {
        if (!this.selectedConfigurationId) {
            this.showToast('Select a Configuration', 'Choose a saved configuration first.', 'warning');
            return;
        }

        this.loading = true;
        this.previewRows = [];
        this.previewRunId = null;
        this.runRecordOutcomes = [];

        try {
            const response = await launchPreview({ configurationId: this.selectedConfigurationId });
            this.previewRunId = response.runId;
            this.previewRows = (response.records || []).map((row) => ({
                id: row.recordId || row.contactId,
                recordId: row.recordId || row.contactId,
                objectApiName: row.objectApiName || 'Record',
                details: (row.fieldDeltas || [])
                    .map((d) => `${d.fieldApiName}: ${d.beforeValue || '(blank)'} -> ${d.afterValue || '(blank)'}`)
                    .join(' | ')
            }));
            this.showToast('Preview Complete', `Previewed ${response.sampledRecordCount} record(s).`, 'success');
        } catch (error) {
            this.showError(error, 'Unable to run preview.');
        } finally {
            this.loading = false;
        }
    }

    async handleExecute() {
        if (!this.selectedConfigurationId) {
            this.showToast('Select a Configuration', 'Choose a saved configuration first.', 'warning');
            return;
        }

        if (this.sandboxEnvironment === null || this.sandboxEnvironment === undefined) {
            await this.loadEnvironment();
        }

        if (this.sandboxEnvironment === false) {
            const confirmed = await LightningConfirm.open({
                message:
                    'You are running in a production org. Do you want to continue with masking execution? This action can modify live data.',
                label: 'Confirm Production Execution',
                variant: 'header-warning'
            });

            if (!confirmed) {
                return;
            }
        }

        this.running = true;
        try {
            this.previewRows = [];
            this.previewRunId = null;
            this.runRecordOutcomes = [];
            const response = await launchExecution({ configurationId: this.selectedConfigurationId });
            this.runId = response.runId;
            this.runStatus = response.runStatus;
            this.lastKnownRunStatus = response.runStatus;
            this.runCounters = {
                attempted: 0,
                updated: 0,
                failed: 0,
                skipped: 0,
                exceptions: 0
            };
            this.runRecordOutcomes = [];
            this.showToast('Execution Queued', 'Masking execution has started.', 'success');
            this.startRunStatusPolling();
            await this.refreshRunStatus();
        } catch (error) {
            this.showError(error, 'Unable to launch execution.');
        } finally {
            this.running = false;
        }
    }

    async handleRefreshRunStatus() {
        await this.refreshRunStatus(true);
    }

    async refreshRunStatus(showManualToast = false) {
        if (!this.runId) {
            return;
        }

        if (this.statusRefreshing) {
            return;
        }

        this.statusRefreshing = true;
        try {
            const previousStatus = this.runStatus;
            const status = await getRunStatus({ runId: this.runId });
            this.runStatus = status.runStatus;
            this.lastKnownRunStatus = status.runStatus;
            this.runCounters = {
                attempted: status.recordsAttempted,
                updated: status.recordsUpdated,
                failed: status.recordsFailed,
                skipped: status.recordsSkipped,
                exceptions: status.exceptionCount
            };
            this.runRecordOutcomes = (status.recordOutcomes || []).map((row, index) => ({
                key: `${row.recordId || 'record'}-${index}`,
                outcomeType: row.outcomeType || 'Failed',
                objectApiName: row.objectApiName || 'Record',
                recordId: row.recordId || 'Unknown',
                reason: row.reason || 'No details provided.'
            }));

            if (showManualToast) {
                this.showToast('Run Status Refreshed', `Current status: ${this.runStatus || 'Unknown'}.`, 'info');
            }

            if (!this.isTerminalStatus(previousStatus) && this.isTerminalStatus(this.runStatus)) {
                this.stopRunStatusPolling();
                const variant = this.runStatus === 'Completed' ? 'success' : 'warning';
                this.showToast('Execution Finished', `Run finished with status: ${this.runStatus}.`, variant);
            }
        } catch (error) {
            this.stopRunStatusPolling();
            this.showError(error, 'Unable to refresh run status.');
        } finally {
            this.statusRefreshing = false;
        }
    }

    startRunStatusPolling() {
        this.stopRunStatusPolling();
        this.runStatusPollHandle = window.setInterval(() => {
            this.refreshRunStatus();
        }, RUN_STATUS_POLL_INTERVAL_MS);
    }

    stopRunStatusPolling() {
        if (this.runStatusPollHandle) {
            window.clearInterval(this.runStatusPollHandle);
            this.runStatusPollHandle = null;
        }
    }

    isTerminalStatus(status) {
        return status === 'Completed' || status === 'Completed with Exceptions' || status === 'Failed' || status === 'Aborted';
    }

    get hasRunRecordOutcomes() {
        return this.runRecordOutcomes && this.runRecordOutcomes.length > 0;
    }

    showError(error, fallbackMessage) {
        const message = error?.body?.message || error?.message || fallbackMessage;
        this.showToast('Error', message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
