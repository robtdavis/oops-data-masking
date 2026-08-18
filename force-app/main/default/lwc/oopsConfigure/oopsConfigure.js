import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/OOPS_ConfigurationController.getConfiguration';
import getAvailableObjects from '@salesforce/apex/OOPS_ConfigurationController.getAvailableObjects';
import getAvailableFields from '@salesforce/apex/OOPS_ConfigurationController.getAvailableFields';
import saveConfiguration from '@salesforce/apex/OOPS_ConfigurationController.saveConfiguration';

const REVIEW_STATEMENT = 'Only the fields listed below will be masked. All other fields are excluded.';
const SHARED_SELECTION_KEY = 'oops.selectedConfigurationId';
const SHARED_SELECTION_EVENT = 'oopsconfigurationselection';
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

export default class OopsConfigure extends LightningElement {
    @api recordId;

    @track loading = false;
    @track saving = false;
    @track step = 1;

    @track configurationId;
    @track configurationName = '';
    @track description = '';
    @track active = false;
    @track defaultBatchSize = 200;
    @track requirePreviewBeforeExecution = true;
    @track recordScope = 'All Records';
    @track firstNRecordCount;

    @track objectOptions = [];
    @track fieldOptions = [];

    @track selectedObjectApiName;
    existingObjectConfigByApi = {};
    existingFieldConfigByObjectApi = {};

    reviewStatement = REVIEW_STATEMENT;
    sharedSelectionHandler;

    get currentStepValue() {
        return String(this.step);
    }

    get recordScopeOptions() {
        return [
            { label: 'All Records', value: 'All Records' },
            { label: 'First N Records', value: 'First N Records' }
        ];
    }

    get maskingStrategyOptions() {
        return [
            { label: 'Do Not Mask', value: 'Do Not Mask' },
            { label: 'Email Suffix', value: 'Email Suffix' },
            // { label: 'Fixed Phone', value: 'Fixed Phone' },
            // { label: 'First Name', value: 'First Name' },
            // { label: 'Last Name', value: 'Last Name' },
            { label: 'Fixed Value', value: 'Fixed Value' },
            { label: 'Clear Field', value: 'Clear Field' }
        ];
    }

    get stepOne() {
        return this.step === 1;
    }

    get stepTwo() {
        return this.step === 2;
    }

    get stepThree() {
        return this.step === 3;
    }

    get stepFour() {
        return this.step === 4;
    }

    get stepFive() {
        return this.step === 5;
    }

    get showFirstN() {
        return this.recordScope === 'First N Records';
    }

    get selectedObjectRows() {
        return this.objectOptions.filter((opt) => opt.selected);
    }

    get selectedObject() {
        return this.selectedObjectRows.length > 0 ? this.selectedObjectRows[0] : null;
    }

    get selectedObjectLabel() {
        return this.selectedObject ? this.selectedObject.label : '';
    }

    get objectTabPath() {
        if (this.selectedObjectRows.length === 0) {
            return 'Objects';
        }
        if (this.selectedObjectRows.length === 1) {
            return `Objects > ${this.selectedObjectLabel}`;
        }
        return `Objects > ${this.selectedObjectRows.length} selected`;
    }

    get fieldTabPath() {
        if (this.selectedObjectRows.length === 0) {
            return 'Objects > Fields';
        }
        if (this.selectedObjectRows.length === 1) {
            const objectName = this.selectedObjectLabel || this.selectedObjectApiName || 'Selected Object';
            return `Objects > ${objectName} > Fields`;
        }
        return `Objects > ${this.selectedObjectRows.length} selected > Fields`;
    }

    get selectedFieldRows() {
        return this.fieldOptions.filter((field) => field.selected);
    }

    get fieldGroups() {
        const grouped = {};

        this.fieldOptions.forEach((field) => {
            const firstLetter = this.getGroupLetter(field.label);
            if (!grouped[firstLetter]) {
                grouped[firstLetter] = [];
            }
            grouped[firstLetter].push(field);
        });

        return Object.keys(grouped)
            .sort()
            .map((letter) => ({
                letter,
                id: `field-group-${letter}`,
                fields: grouped[letter]
            }));
    }

    get fieldIndexLetters() {
        const lettersWithData = new Set(this.fieldGroups.map((group) => group.letter));
        return ALPHABET.map((letter) => ({
            letter,
            disabled: !lettersWithData.has(letter) || this.loading
        }));
    }

    get objectGroups() {
        const grouped = {};

        this.objectOptions.forEach((opt) => {
            const firstLetter = this.getGroupLetter(opt.label);
            if (!grouped[firstLetter]) {
                grouped[firstLetter] = [];
            }
            grouped[firstLetter].push(opt);
        });

        return Object.keys(grouped)
            .sort()
            .map((letter) => ({
                letter,
                id: `group-${letter}`,
                objects: grouped[letter]
            }));
    }

    get objectIndexLetters() {
        const lettersWithData = new Set(this.objectGroups.map((group) => group.letter));
        return ALPHABET.map((letter) => ({
            letter,
            hasObjects: lettersWithData.has(letter),
            disabled: !lettersWithData.has(letter) || this.loading
        }));
    }

    get canGoPrevious() {
        return this.step > 1 && !this.loading && !this.saving;
    }

    get canGoNext() {
        return this.step < 5 && !this.loading && !this.saving;
    }

    get disablePrevious() {
        return !this.canGoPrevious;
    }

    get disableNext() {
        return !this.canGoNext;
    }

    get disableSave() {
        return this.saving || this.loading;
    }

    connectedCallback() {
        this.sharedSelectionHandler = this.handleSharedSelectionEvent.bind(this);
        window.addEventListener(SHARED_SELECTION_EVENT, this.sharedSelectionHandler);
        this.initialize();
    }

    disconnectedCallback() {
        if (this.sharedSelectionHandler) {
            window.removeEventListener(SHARED_SELECTION_EVENT, this.sharedSelectionHandler);
        }
    }

    async initialize() {
        this.loading = true;
        try {
            const effectiveConfigurationId = this.recordId || this.getSharedConfigurationId();
            if (effectiveConfigurationId) {
                await this.loadConfiguration(effectiveConfigurationId);
            }
            await this.loadObjects();
            await this.loadFieldsForSelectedObjects();
        } catch (error) {
            this.showError(error, 'Unable to initialize Configure OOPS.');
        } finally {
            this.loading = false;
        }
    }

    async handleSharedSelectionEvent(event) {
        const nextConfigurationId = event?.detail?.configurationId || this.getSharedConfigurationId();
        if (!nextConfigurationId || nextConfigurationId === this.configurationId || this.loading || this.saving) {
            return;
        }

        await this.loadSelectedConfiguration(nextConfigurationId);
    }

    async loadSelectedConfiguration(configurationId) {
        this.loading = true;
        try {
            this.selectedObjectApiName = null;
            await this.loadConfiguration(configurationId);
            await this.loadObjects();
            await this.loadFieldsForSelectedObjects();
            this.showToast('Configuration Loaded', 'Loaded configuration selected from OOPS Run Console.', 'info');
        } catch (error) {
            this.showError(error, 'Unable to load selected configuration.');
        } finally {
            this.loading = false;
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

    async loadConfiguration(configurationId) {
        const dto = await getConfiguration({ configurationId });
        this.configurationId = dto.configurationId;
        this.configurationName = dto.configurationName || '';
        this.description = dto.description || '';
        this.active = dto.active === true;
        this.defaultBatchSize = dto.defaultBatchSize || 200;
        this.requirePreviewBeforeExecution = dto.requirePreviewBeforeExecution !== false;
        this.recordScope = dto.recordScope || 'All Records';
        this.firstNRecordCount = dto.firstNRecordCount;

        this.existingObjectConfigByApi = {};
        this.existingFieldConfigByObjectApi = {};

        (dto.objectConfigurations || []).forEach((obj) => {
            this.existingObjectConfigByApi[obj.objectApiName] = obj;
            const fields = {};
            (obj.fieldConfigurations || []).forEach((field) => {
                fields[field.fieldApiName] = field;
            });
            this.existingFieldConfigByObjectApi[obj.objectApiName] = fields;
            if (obj.included === true && !this.selectedObjectApiName) {
                this.selectedObjectApiName = obj.objectApiName;
            }
        });
    }

    async loadObjects() {
        const options = await getAvailableObjects();
        this.objectOptions = (options || []).map((opt, index) => {
            const existing = this.existingObjectConfigByApi[opt.apiName];
            const selected = existing ? existing.included === true : false;
            if (selected && !this.selectedObjectApiName) {
                this.selectedObjectApiName = opt.apiName;
            }
            return {
                key: `${opt.apiName}-${index}`,
                label: opt.label,
                apiName: opt.apiName,
                queryable: opt.queryable,
                updateable: opt.updateable,
                supported: opt.supported,
                unsupportedReason: opt.unsupportedReason,
                selected
            };
        });

        if (!this.selectedObjectApiName || !this.objectOptions.some((opt) => opt.apiName === this.selectedObjectApiName && opt.selected)) {
            const firstSelected = this.objectOptions.find((opt) => opt.selected);
            this.selectedObjectApiName = firstSelected ? firstSelected.apiName : null;
        }
    }

    async loadFieldsForSelectedObjects() {
        const existingFieldStateByKey = new Map();
        (this.fieldOptions || []).forEach((field) => {
            if (field?.fieldKey) {
                existingFieldStateByKey.set(field.fieldKey, {
                    selected: field.selected,
                    maskingStrategy: field.maskingStrategy,
                    fixedReplacementValue: field.fixedReplacementValue,
                    displayOrder: field.displayOrder
                });
            }
        });

        const selectedObjects = this.objectOptions.filter((opt) => opt.selected);
        if (selectedObjects.length === 0) {
            this.fieldOptions = [];
            this.selectedObjectApiName = null;
            return;
        }

        if (!this.selectedObjectApiName || !selectedObjects.some((opt) => opt.apiName === this.selectedObjectApiName)) {
            this.selectedObjectApiName = selectedObjects[0].apiName;
        }

        const fieldsByObject = await Promise.all(
            selectedObjects.map(async (selectedObject, objectIndex) => {
                const objectApiName = selectedObject.apiName;
                const options = await getAvailableFields({ objectApiName });
                const existingFields = this.existingFieldConfigByObjectApi[objectApiName] || {};
                const objectLabel = selectedObject.label || objectApiName;
                const shadedClass = selectedObjects.length > 1 && objectIndex % 2 === 1
                    ? 'slds-box slds-m-bottom_small object-shade-alt'
                    : 'slds-box slds-m-bottom_small object-shade-base';

                return (options || []).map((opt, fieldIndex) => {
                    const existing = existingFields[opt.apiName];
                    const fieldKey = `${objectApiName}::${opt.apiName}`;
                    const priorState = existingFieldStateByKey.get(fieldKey);
                    const selected = priorState
                        ? priorState.selected === true
                        : existing
                            ? existing.included === true
                            : false;

                    const maskingStrategy = priorState?.maskingStrategy || existing?.maskingStrategy || 'Do Not Mask';
                    const fixedReplacementValue = priorState?.fixedReplacementValue || existing?.fixedReplacementValue || '';
                    const displayOrder = priorState?.displayOrder || existing?.displayOrder || fieldIndex + 1;

                    return {
                        key: `${objectApiName}::${opt.apiName}::${fieldIndex}`,
                        fieldKey,
                        objectApiName,
                        apiName: opt.apiName,
                        label: opt.label,
                        displayLabel: `${objectLabel} ${opt.label}`,
                        objectLabel,
                        dataType: opt.dataType,
                        updateable: opt.updateable,
                        required: opt.required,
                        supported: opt.supported,
                        unsupportedReason: opt.unsupportedReason,
                        disabledBySupport: !opt.supported,
                        selected,
                        maskingStrategy,
                        fixedReplacementValue,
                        displayOrder,
                        length: opt.length,
                        fieldConfigurationId: existing?.fieldConfigurationId,
                        rowClass: shadedClass
                    };
                });
            })
        );

        this.fieldOptions = fieldsByObject.flat();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this[field] = value;
    }

    handleObjectSelect(event) {
        const apiName = event.target.dataset.apiname;
        const checked = event.target.checked;

        this.objectOptions = this.objectOptions.map((opt) => ({
            ...opt,
            selected: opt.apiName === apiName ? checked : opt.selected
        }));

        if (checked) {
            this.selectedObjectApiName = apiName;
        } else if (this.selectedObjectApiName === apiName) {
            const fallback = this.objectOptions.find((opt) => opt.selected);
            this.selectedObjectApiName = fallback ? fallback.apiName : null;
        }

        this.loadFieldsForSelectedObjects().catch((error) => {
            this.showError(error, 'Unable to load fields.');
        });
    }

    handleObjectIndexClick(event) {
        const letter = event.currentTarget.dataset.letter;
        if (!letter) {
            return;
        }

        const section = this.template.querySelector(`[data-group="${letter}"]`);
        if (section) {
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    handleFieldIndexClick(event) {
        const letter = event.currentTarget.dataset.letter;
        if (!letter) {
            return;
        }

        const section = this.template.querySelector(`[data-field-group="${letter}"]`);
        if (section) {
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    handleFieldSelect(event) {
        const fieldKey = event.target.dataset.fieldkey;
        const checked = event.target.checked;
        this.fieldOptions = this.fieldOptions.map((field) => {
            if (field.fieldKey !== fieldKey) {
                return field;
            }
            return {
                ...field,
                selected: checked
            };
        });
    }

    handleFieldDetailChange(event) {
        const fieldKey = event.target.dataset.fieldkey;
        const fieldName = event.target.dataset.field;
        const value = event.target.value;
        this.fieldOptions = this.fieldOptions.map((field) => {
            if (field.fieldKey !== fieldKey) {
                return field;
            }
            return {
                ...field,
                [fieldName]: value
            };
        });
    }

    handleScopeChange(event) {
        this.recordScope = event.target.value;
        if (this.recordScope === 'All Records') {
            this.firstNRecordCount = null;
        }
    }

    handleFirstNChange(event) {
        const raw = event.target.value;
        this.firstNRecordCount = raw === '' || raw === null ? null : Number(raw);
    }

    goPrevious() {
        if (this.canGoPrevious) {
            this.step -= 1;
        }
    }

    goNext() {
        if (!this.canGoNext) {
            return;
        }

        const validationError = this.validateCurrentStep();
        if (validationError) {
            this.showToast('Validation Error', validationError, 'error');
            return;
        }
        this.step += 1;
    }

    handleProgressStepClick(event) {
        const targetStep = Number(event.currentTarget.dataset.step);
        this.navigateToStep(targetStep);
    }

    handlePathStepClick(event) {
        const targetStep = Number(event.currentTarget.dataset.step);
        this.navigateToStep(targetStep);
    }

    navigateToStep(targetStep) {
        if (this.loading || this.saving || !targetStep || targetStep < 1 || targetStep > 5) {
            return;
        }

        if (targetStep === this.step) {
            return;
        }

        if (targetStep < this.step) {
            this.step = targetStep;
            return;
        }

        let current = this.step;
        while (current < targetStep) {
            this.step = current;
            const validationError = this.validateCurrentStep();
            if (validationError) {
                this.showToast('Validation Error', validationError, 'error');
                this.step = current;
                return;
            }
            current += 1;
        }

        this.step = targetStep;
    }

    validateCurrentStep() {
        if (this.step === 1) {
            if (!this.configurationName || !this.configurationName.trim()) {
                return 'Configuration Name is required.';
            }
            if (!this.defaultBatchSize || Number(this.defaultBatchSize) <= 0) {
                return 'Default Batch Size must be a positive number.';
            }
        }

        if (this.step === 2) {
            if (this.selectedObjectRows.length === 0) {
                return 'Select at least one object.';
            }
        }

        if (this.step === 3) {
            if (this.selectedFieldRows.length === 0) {
                return 'Select at least one field to include.';
            }
        }

        if (this.step === 4) {
            if (this.recordScope === 'First N Records') {
                if (!this.firstNRecordCount || Number(this.firstNRecordCount) <= 0) {
                    return 'First N Record Count must be a positive number.';
                }
            }
        }

        return null;
    }

    async handleSave() {
        const validationError = this.validateCurrentStep();
        if (validationError) {
            this.showToast('Validation Error', validationError, 'error');
            return;
        }

        this.saving = true;
        try {
            const payload = this.buildPayload();
            const savedId = await saveConfiguration({ configuration: payload });
            this.configurationId = savedId;
            this.recordId = savedId;
            this.showToast('Success', 'Configuration saved successfully. Saving this configuration did not modify Salesforce data.', 'success');
            await this.loadConfiguration(savedId);
            await this.loadObjects();
            await this.loadFieldsForSelectedObjects();
        } catch (error) {
            this.showError(error, 'Unable to save configuration.');
        } finally {
            this.saving = false;
        }
    }

    buildPayload() {
        const selectedObjects = this.objectOptions.filter((opt) => opt.selected);
        const selectedFields = this.fieldOptions.filter((field) => field.selected);

        return {
            configurationId: this.configurationId,
            configurationName: this.configurationName,
            description: this.description,
            active: this.active,
            defaultBatchSize: Number(this.defaultBatchSize),
            recordScope: this.recordScope,
            firstNRecordCount: this.recordScope === 'First N Records' ? Number(this.firstNRecordCount) : null,
            requirePreviewBeforeExecution: this.requirePreviewBeforeExecution,
            objectConfigurations: selectedObjects.map((selectedObject, objectIndex) => {
                const existingObject = this.existingObjectConfigByApi[selectedObject.apiName];
                const objectFields = selectedFields.filter((field) => field.objectApiName === selectedObject.apiName);
                return {
                    objectConfigurationId: existingObject?.objectConfigurationId || existingObject?.id,
                    objectApiName: selectedObject.apiName,
                    objectLabel: selectedObject.label,
                    included: true,
                    processingOrder: objectIndex + 1,
                    fieldConfigurations: objectFields.map((field, index) => ({
                        fieldConfigurationId: field.fieldConfigurationId,
                        fieldApiName: field.apiName,
                        fieldLabel: field.label,
                        salesforceDataType: field.dataType,
                        fieldLength: field.length,
                        included: true,
                        updateable: field.updateable,
                        required: field.required,
                        maskingStrategy: field.maskingStrategy || 'Do Not Mask',
                        fixedReplacementValue: field.fixedReplacementValue || null,
                        unsupportedReason: field.unsupportedReason,
                        displayOrder: Number(field.displayOrder) || index + 1
                    }))
                };
            })
        };
    }

    showError(error, fallbackMessage) {
        const message = error?.body?.message || error?.message || fallbackMessage;
        this.showToast('Error', message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getGroupLetter(label) {
        if (!label) {
            return '#';
        }

        const first = label.trim().charAt(0).toUpperCase();
        return ALPHABET.includes(first) ? first : '#';
    }
}
