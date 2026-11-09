import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPatients from '@salesforce/apex/PatientPortalController.getPatients';
import getPhysicians from '@salesforce/apex/PatientPortalController.getPhysicians';
import getCertifications from '@salesforce/apex/PatientPortalController.getCertifications';
import getPatientCardData from '@salesforce/apex/PatientPortalController.getPatientCardData';
import submitCertification from '@salesforce/apex/PatientPortalController.submitCertification';

export default class PatientRegistrationCard extends LightningElement {
    @api recordId; // Optional record Id when placed on Contact or Patient_Registration__c page

    @track isLoading = true;
    @track isSubmitting = false;
    @track isModalOpen = false;
    @track isAttested = false;

    // Card data payload
    @track cardData = {
        hasRecord: false,
        patientName: 'Loading Patient...',
        registrationNumber: 'MMAP-XXXX-000000',
        barcodeString: 'PA-MED-00000000',
        stateIdNumber: 'PA-DL-000000',
        issueDate: '',
        expirationDate: '',
        isActive: true,
        totalQuotaGrams: 90.00,
        gramsUsed: 0.00,
        gramsRemaining: 90.00,
        percentUsed: 0.0,
        physicianName: 'Commonwealth Certified MD',
        physicianLicense: 'MD-98214-PA',
        hasCertification: false,
        certificationNumber: 'N/A',
        qualifyingCondition: 'Chronic Pain',
        recommendedDailyDose: 3.00,
        digitalSignatureTimestamp: '',
        certificationNotes: '',
        certificationStatus: 'Active'
    };

    // Certifications log
    @track certifications = [];

    // Dropdown options
    @track patientOptions = [];
    @track physicianOptions = [];
    @track selectedPatientId = '';

    // Form inputs for modal
    @track formPatientId = '';
    @track formPhysicianId = '';
    @track formCondition = 'Chronic Pain';
    @track formDailyDose = 3.00;
    @track formIssueDate = '';
    @track formExpirationDate = '';
    @track formNotes = '';

    conditionOptions = [
        { label: 'Chronic Pain', value: 'Chronic Pain' },
        { label: 'Cancer', value: 'Cancer' },
        { label: 'PTSD', value: 'PTSD' },
        { label: 'Epilepsy', value: 'Epilepsy' },
        { label: 'Multiple Sclerosis', value: 'Multiple Sclerosis' },
        { label: 'Glaucoma', value: 'Glaucoma' },
        { label: 'Inflammatory Bowel Disease', value: 'Inflammatory Bowel Disease' }
    ];

    connectedCallback() {
        this.initDefaultDates();
        this.loadInitialData();
    }

    initDefaultDates() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        this.formIssueDate = `${yyyy}-${mm}-${dd}`;

        const nextYear = new Date(today);
        nextYear.setFullYear(today.getFullYear() + 1);
        const expY = nextYear.getFullYear();
        const expM = String(nextYear.getMonth() + 1).padStart(2, '0');
        const expD = String(nextYear.getDate()).padStart(2, '0');
        this.formExpirationDate = `${expY}-${expM}-${expD}`;
    }

    async loadInitialData() {
        this.isLoading = true;
        try {
            // Load patients for switcher
            const patients = await getPatients();
            if (patients && patients.length > 0) {
                this.patientOptions = patients.map(p => ({
                    label: `${p.Name} (${p.State_ID_Number__c || 'Patient'})`,
                    value: p.Id
                }));

                // If recordId is provided, use it; otherwise use first patient
                if (this.recordId) {
                    this.selectedPatientId = this.recordId;
                } else if (!this.selectedPatientId) {
                    this.selectedPatientId = patients[0].Id;
                }
            }

            // Load physicians for modal dropdown
            const physicians = await getPhysicians();
            if (physicians && physicians.length > 0) {
                this.physicianOptions = physicians.map(doc => ({
                    label: `Dr. ${doc.Name} (${doc.Medical_License_No__c || 'MD'})`,
                    value: doc.Id
                }));
                this.formPhysicianId = physicians[0].Id;
            }

            // Load card data
            await this.refreshCardData();

            // Load certification list
            await this.refreshCertifications();
        } catch (error) {
            this.showToast('Error Loading Data', this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshCardData() {
        try {
            const data = await getPatientCardData({ patientRegistrationId: this.selectedPatientId });
            if (data && data.hasRecord) {
                this.cardData = {
                    ...data,
                    percentUsed: data.percentUsed !== undefined ? data.percentUsed : 0
                };
            }
        } catch (error) {
            this.showToast('Error Fetching Card Data', this.reduceErrors(error), 'error');
        }
    }

    async refreshCertifications() {
        try {
            const certs = await getCertifications();
            if (certs) {
                this.certifications = certs.map(c => {
                    let badgeClass = 'slds-badge ';
                    if (c.Status__c === 'Active') {
                        badgeClass += 'slds-theme_success';
                    } else if (c.Status__c === 'Expired') {
                        badgeClass += 'slds-theme_error';
                    } else {
                        badgeClass += 'slds-theme_warning';
                    }
                    return {
                        ...c,
                        statusBadgeClass: badgeClass
                    };
                });
            }
        } catch (error) {
            this.showToast('Error Fetching Certifications', this.reduceErrors(error), 'error');
        }
    }

    handlePatientChange(event) {
        this.selectedPatientId = event.detail.value;
        this.isLoading = true;
        this.refreshCardData().finally(() => {
            this.isLoading = false;
        });
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([this.refreshCardData(), this.refreshCertifications()]).finally(() => {
            this.isLoading = false;
            this.showToast('Ledger Refreshed', 'Patient card and certifications registry synchronized.', 'success');
        });
    }

    // Modal controls
    openNewCertModal() {
        this.formPatientId = this.selectedPatientId || (this.patientOptions.length > 0 ? this.patientOptions[0].value : '');
        this.initDefaultDates();
        this.isAttested = false;
        this.isModalOpen = true;
    }

    closeNewCertModal() {
        this.isModalOpen = false;
    }

    handleFormChange(event) {
        const field = event.target.name;
        const val = event.target.value;
        if (field === 'modalPatient') this.formPatientId = val;
        else if (field === 'modalPhysician') this.formPhysicianId = val;
        else if (field === 'modalCondition') this.formCondition = val;
        else if (field === 'modalDailyDose') this.formDailyDose = parseFloat(val) || 0;
        else if (field === 'modalIssueDate') this.formIssueDate = val;
        else if (field === 'modalExpirationDate') this.formExpirationDate = val;
        else if (field === 'modalNotes') this.formNotes = val;
    }

    handleAttestationChange(event) {
        this.isAttested = event.target.checked;
    }

    get isSubmitDisabled() {
        return !this.isAttested || !this.formPatientId || !this.formPhysicianId || !this.formCondition || this.isSubmitting;
    }

    async handleSubmitCertification() {
        // Validation check
        if (!this.formPatientId || !this.formPhysicianId || !this.formCondition) {
            this.showToast('Validation Error', 'Please complete all required fields.', 'error');
            return;
        }

        if (this.formDailyDose <= 0) {
            this.showToast('Validation Error', 'Daily dose must be greater than zero grams.', 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            const newCert = await submitCertification({
                patientId: this.formPatientId,
                physicianId: this.formPhysicianId,
                condition: this.formCondition,
                dailyDose: this.formDailyDose,
                issueDate: this.formIssueDate,
                expirationDate: this.formExpirationDate,
                notes: this.formNotes
            });

            this.showToast(
                'Recommendation Certified',
                `Physician certification submitted successfully with timestamp signature.`,
                'success'
            );

            this.closeNewCertModal();

            // Refresh card for this patient
            this.selectedPatientId = this.formPatientId;
            await this.refreshCardData();
            await this.refreshCertifications();
        } catch (error) {
            this.showToast('Submission Rejected', this.reduceErrors(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // Getters
    get progressFillClass() {
        const pct = this.cardData.percentUsed || 0;
        if (pct >= 90) return 'progress-fill bg-danger';
        if (pct >= 70) return 'progress-fill bg-warn';
        return 'progress-fill bg-safe';
    }

    get progressFillStyle() {
        const pct = Math.min(100, Math.max(0, this.cardData.percentUsed || 0));
        return `width: ${pct}%;`;
    }

    get certificationsCount() {
        return this.certifications ? this.certifications.length : 0;
    }

    get noCertifications() {
        return !this.certifications || this.certifications.length === 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(errors) {
        if (!errors) return 'Unknown error';
        if (typeof errors === 'string') return errors;
        if (Array.isArray(errors)) return errors.map(e => this.reduceErrors(e)).join(', ');
        if (errors.body && typeof errors.body.message === 'string') return errors.body.message;
        if (errors.message) return errors.message;
        return JSON.stringify(errors);
    }
}
