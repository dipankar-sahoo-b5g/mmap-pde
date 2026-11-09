import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getFacilities from '@salesforce/apex/LicenseApplicationController.getFacilities';
import getApplications from '@salesforce/apex/LicenseApplicationController.getApplications';
import submitApplication from '@salesforce/apex/LicenseApplicationController.submitApplication';

const STEPS = [
    { label: 'Facility & Category', value: '1' },
    { label: 'Premise & Capacity', value: '2' },
    { label: 'Fee Review & Submission', value: '3' }
];

const FEE_MAP = {
    'Grower/Processor': 10000.00,
    'Dispensary Retail': 5000.00,
    'Analytical Lab': 2000.00,
    'Academic Research': 1000.00
};

export default class LicenseApplicationWizard extends NavigationMixin(LightningElement) {
    steps = STEPS;
    @track currentStep = '1';

    // Form inputs
    @track selectedFacilityId = '';
    @track selectedAppType = '';
    @track premiseAddress = '';
    @track canopySqFt = null;
    @track attestationAccepted = false;

    // State & loading
    @track isLoading = false;
    @track isSubmitting = false;
    @track errorMessage = '';
    @track submittedRecordId = null;
    @track submittedRecordName = '';

    // Data lists
    @track rawFacilities = [];
    @track facilityOptions = [];
    @track rawApplications = [];
    @track filteredApplications = [];
    @track searchTerm = '';

    appTypeOptions = [
        { label: 'Grower/Processor ($10,000 statutory fee)', value: 'Grower/Processor' },
        { label: 'Dispensary Retail ($5,000 statutory fee)', value: 'Dispensary Retail' },
        { label: 'Analytical Lab ($2,000 statutory fee)', value: 'Analytical Lab' },
        { label: 'Academic Research ($1,000 statutory fee)', value: 'Academic Research' }
    ];

    connectedCallback() {
        this.loadFacilities();
        this.loadApplications();
    }

    async loadFacilities() {
        try {
            const data = await getFacilities();
            this.rawFacilities = data || [];
            this.facilityOptions = this.rawFacilities.map(fac => {
                const reg = fac.Premise_Registry_ID__c ? ` (${fac.Premise_Registry_ID__c})` : '';
                const type = fac.Facility_Type__c ? ` - ${fac.Facility_Type__c}` : '';
                return {
                    label: `${fac.Name}${reg}${type}`,
                    value: fac.Id
                };
            });
        } catch (error) {
            this.showToast('Error Loading Facilities', this.reduceErrors(error), 'error');
        }
    }

    async loadApplications() {
        this.isLoading = true;
        try {
            const data = await getApplications();
            this.rawApplications = (data || []).map(app => {
                return {
                    ...app,
                    facilityName: app.Applicant_Facility__r ? app.Applicant_Facility__r.Name : 'N/A',
                    facilityRegId: app.Applicant_Facility__r ? app.Applicant_Facility__r.Premise_Registry_ID__c : '',
                    statusClass: this.computeStatusBadge(app.Status__c),
                    formattedFee: app.Application_Fee__c != null ? `$${Number(app.Application_Fee__c).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '$0.00',
                    formattedCanopy: app.Estimated_Canopy_SqFt__c != null ? `${Number(app.Estimated_Canopy_SqFt__c).toLocaleString('en-US')} sq ft` : 'N/A'
                };
            });
            this.applyFilter();
        } catch (error) {
            this.showToast('Error Loading Applications', this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    computeStatusBadge(status) {
        switch (status) {
            case 'Submitted':
                return 'status-badge status-submitted';
            case 'Under Review':
                return 'status-badge status-under-review';
            case 'Inspection Scheduled':
                return 'status-badge status-inspection-scheduled';
            case 'Approved':
                return 'status-badge status-approved';
            case 'Rejected':
                return 'status-badge status-rejected';
            default:
                return 'status-badge status-draft';
        }
    }

    // Wizard Step Getters
    get isStep1() {
        return this.currentStep === '1';
    }

    get isStep2() {
        return this.currentStep === '2';
    }

    get isStep3() {
        return this.currentStep === '3';
    }

    get isSubmitted() {
        return !!this.submittedRecordId;
    }

    get isGrowerProcessor() {
        return this.selectedAppType === 'Grower/Processor';
    }

    get calculatedFee() {
        return FEE_MAP[this.selectedAppType] || 0.00;
    }

    get formattedCalculatedFee() {
        return `$${Number(this.calculatedFee).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    }

    get selectedFacilityObject() {
        return this.rawFacilities.find(f => f.Id === this.selectedFacilityId) || null;
    }

    get selectedFacilityName() {
        const fac = this.selectedFacilityObject;
        return fac ? fac.Name : 'None Selected';
    }

    get selectedFacilityRegistryId() {
        const fac = this.selectedFacilityObject;
        return fac && fac.Premise_Registry_ID__c ? fac.Premise_Registry_ID__c : 'N/A';
    }

    get isStep1NextDisabled() {
        return !this.selectedFacilityId || !this.selectedAppType;
    }

    get isSubmitDisabled() {
        return !this.attestationAccepted || this.isSubmitting;
    }

    // Handlers
    handleFacilityChange(event) {
        this.selectedFacilityId = event.detail.value;
        this.errorMessage = '';
        // Auto-fill premise address from Account address if available and blank
        const fac = this.selectedFacilityObject;
        if (fac && !this.premiseAddress) {
            const parts = [fac.BillingStreet, fac.BillingCity, fac.BillingState, fac.BillingPostalCode].filter(Boolean);
            if (parts.length > 0) {
                this.premiseAddress = parts.join(', ');
            }
        }
    }

    handleAppTypeChange(event) {
        this.selectedAppType = event.detail.value;
        this.errorMessage = '';
        if (!this.isGrowerProcessor) {
            this.canopySqFt = null;
        }
    }

    handleAddressChange(event) {
        this.premiseAddress = event.detail.value;
        this.errorMessage = '';
    }

    handleCanopyChange(event) {
        const val = event.detail.value;
        this.canopySqFt = val ? Number(val) : null;
        this.errorMessage = '';
    }

    handleAttestationChange(event) {
        this.attestationAccepted = event.target.checked;
    }

    handleNext() {
        this.errorMessage = '';
        if (this.isStep1) {
            if (!this.selectedFacilityId || !this.selectedAppType) {
                this.errorMessage = 'Please select a facility applicant and operating license category.';
                return;
            }
            this.currentStep = '2';
        } else if (this.isStep2) {
            if (!this.premiseAddress || this.premiseAddress.trim() === '') {
                this.errorMessage = 'Premise operational address is mandatory.';
                return;
            }
            if (this.isGrowerProcessor) {
                if (this.canopySqFt == null || this.canopySqFt <= 0) {
                    this.errorMessage = 'Estimated canopy square footage is mandatory and must be greater than zero for Grower/Processor applications.';
                    return;
                }
            }
            this.currentStep = '3';
        }
    }

    handleBack() {
        this.errorMessage = '';
        if (this.isStep3) {
            this.currentStep = '2';
        } else if (this.isStep2) {
            this.currentStep = '1';
        }
    }

    async handleSubmit() {
        this.errorMessage = '';
        if (!this.attestationAccepted) {
            this.errorMessage = 'You must acknowledge and certify the legal attestation before submitting.';
            return;
        }

        this.isSubmitting = true;
        this.isLoading = true;
        try {
            const newAppId = await submitApplication({
                facilityId: this.selectedFacilityId,
                appType: this.selectedAppType,
                premiseAddress: this.premiseAddress,
                canopySqFt: this.canopySqFt
            });

            this.submittedRecordId = newAppId;
            this.showToast('Application Submitted Successfully', `Application filed under review with statutory fee of ${this.formattedCalculatedFee}.`, 'success');
            await this.loadApplications();
        } catch (error) {
            const msg = this.reduceErrors(error);
            this.errorMessage = msg;
            this.showToast('Submission Rejected', msg, 'error');
        } finally {
            this.isSubmitting = false;
            this.isLoading = false;
        }
    }

    handleReset() {
        this.currentStep = '1';
        this.selectedFacilityId = '';
        this.selectedAppType = '';
        this.premiseAddress = '';
        this.canopySqFt = null;
        this.attestationAccepted = false;
        this.submittedRecordId = null;
        this.errorMessage = '';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilter();
    }

    applyFilter() {
        if (!this.searchTerm) {
            this.filteredApplications = [...this.rawApplications];
        } else {
            this.filteredApplications = this.rawApplications.filter(app => {
                const name = (app.Name || '').toLowerCase();
                const fac = (app.facilityName || '').toLowerCase();
                const type = (app.Application_Type__c || '').toLowerCase();
                const status = (app.Status__c || '').toLowerCase();
                return name.includes(this.searchTerm) ||
                       fac.includes(this.searchTerm) ||
                       type.includes(this.searchTerm) ||
                       status.includes(this.searchTerm);
            });
        }
    }

    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(errors) {
        if (!errors) return 'Unknown error occurred.';
        if (typeof errors === 'string') return errors;
        if (errors.body && errors.body.message) return errors.body.message;
        if (errors.message) return errors.message;
        return JSON.stringify(errors);
    }
}
