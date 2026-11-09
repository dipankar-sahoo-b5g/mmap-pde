import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAudits from '@salesforce/apex/InspectionAuditController.getAudits';
import getAuditDetails from '@salesforce/apex/InspectionAuditController.getAuditDetails';
import createAudit from '@salesforce/apex/InspectionAuditController.createAudit';
import enactStopSale from '@salesforce/apex/InspectionAuditController.enactStopSale';
import liftStopSale from '@salesforce/apex/InspectionAuditController.liftStopSale';
import getFacilities from '@salesforce/apex/InspectionAuditController.getFacilities';
import getInspectors from '@salesforce/apex/InspectionAuditController.getInspectors';

export default class InspectionAuditManager extends LightningElement {
    @track audits = [];
    @track selectedAuditId = null;
    @track selectedAudit = null;
    @track selectedAuditFindings = [];
    @track auditSummaryStats = null;
    @track searchKey = '';
    @track isLoading = false;

    // Modals
    @track isNewAuditModalOpen = false;
    @track isEnactModalOpen = false;
    @track isLiftModalOpen = false;

    // New Audit Form State
    @track newAuditFacilityId = '';
    @track newAuditInspectorId = '';
    @track newAuditType = 'Annual Routine';
    @track newAuditDate = this.getTodayDate();
    @track newAuditScore = 85;
    @track newAuditNotes = '';
    @track newFindings = [];

    // Enact Stop-Sale Modal State
    @track enactReason = '';
    @track enactAttestationChecked = false;

    // Lift Quarantine Modal State
    @track liftReason = '';

    // Dropdown Data
    @track facilityOptions = [];
    @track inspectorOptions = [];

    inspectionTypeOptions = [
        { label: 'Annual Routine', value: 'Annual Routine' },
        { label: 'Unannounced Compliance', value: 'Unannounced Compliance' },
        { label: 'Follow-Up Re-Inspection', value: 'Follow-Up Re-Inspection' },
        { label: 'Adverse Event Investigation', value: 'Adverse Event Investigation' }
    ];

    findingCategoryOptions = [
        { label: 'Security & Surveillance', value: 'Security & Surveillance' },
        { label: 'Vault Scale Calibration', value: 'Vault Scale Calibration' },
        { label: 'Pesticide / Chemical Storage', value: 'Pesticide / Chemical Storage' },
        { label: 'Sanitation & Hygiene', value: 'Sanitation & Hygiene' },
        { label: 'Diversion Discrepancy', value: 'Diversion Discrepancy' }
    ];

    severityOptions = [
        { label: 'Minor', value: 'Minor' },
        { label: 'Major', value: 'Major' },
        { label: 'Critical Violation', value: 'Critical Violation' }
    ];

    wiredAuditsResult;

    @wire(getAudits)
    wiredAudits(result) {
        this.wiredAuditsResult = result;
        const { data, error } = result;
        if (data) {
            this.audits = data;
            // Auto-select first audit if none selected or if previously selected was removed
            if (!this.selectedAuditId && data.length > 0) {
                this.selectAuditById(data[0].Id);
            }
        } else if (error) {
            this.showToast('Error Loading Audits', this.reduceError(error), 'error');
        }
    }

    @wire(getFacilities)
    wiredFacilities({ data, error }) {
        if (data) {
            this.facilityOptions = data.map(f => ({
                label: `${f.Name} (${f.Premise_Registry_ID__c || 'No ID'})`,
                value: f.Id
            }));
        } else if (error) {
            console.error('Error fetching facilities', error);
        }
    }

    @wire(getInspectors)
    wiredInspectors({ data, error }) {
        if (data) {
            this.inspectorOptions = data.map(i => ({
                label: `${i.Name} (${i.Stakeholder_Role__c || 'Inspector'})`,
                value: i.Id
            }));
        } else if (error) {
            console.error('Error fetching inspectors', error);
        }
    }

    getTodayDate() {
        const d = new Date();
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    // Computed Getters for UI
    get auditsCount() {
        return this.audits ? this.audits.length : 0;
    }

    get hasFilteredAudits() {
        return this.filteredAudits && this.filteredAudits.length > 0;
    }

    get noAuditsFound() {
        return !this.isLoading && (!this.filteredAudits || this.filteredAudits.length === 0);
    }

    get filteredAudits() {
        if (!this.audits) return [];
        const query = (this.searchKey || '').toLowerCase();

        return this.audits
            .filter(aud => {
                if (!query) return true;
                const name = (aud.Name || '').toLowerCase();
                const facility = (aud.Facility__r && aud.Facility__r.Name) ? aud.Facility__r.Name.toLowerCase() : '';
                const type = (aud.Inspection_Type__c || '').toLowerCase();
                const grade = (aud.Compliance_Grade__c || '').toLowerCase();
                const status = (aud.Status__c || '').toLowerCase();
                return name.includes(query) || facility.includes(query) || type.includes(query) || grade.includes(query) || status.includes(query);
            })
            .map(aud => {
                const isSelected = aud.Id === this.selectedAuditId;
                let gradeBadgeClass = 'slds-badge ';
                if (aud.Compliance_Grade__c === 'Pass') {
                    gradeBadgeClass += 'grade-badge-pass';
                } else if (aud.Compliance_Grade__c === 'Conditional Pass') {
                    gradeBadgeClass += 'grade-badge-conditional';
                } else {
                    gradeBadgeClass += 'grade-badge-fail';
                }

                return {
                    audit: aud,
                    facilityName: aud.Facility__r ? aud.Facility__r.Name : 'Unassigned Facility',
                    gradeBadgeClass: gradeBadgeClass,
                    cardCssClass: `audit-list-item slds-p-around_small slds-m-bottom_x-small ${isSelected ? 'selected' : ''}`
                };
            });
    }

    get hasSelectedAudit() {
        return this.selectedAudit != null;
    }

    get isQuarantineActive() {
        return this.selectedAudit && this.selectedAudit.Stop_Sale_Enacted__c === true;
    }

    get isFailingAuditNotice() {
        return (
            this.selectedAudit &&
            this.selectedAudit.Compliance_Grade__c === 'Failed - Immediate Revocation' &&
            !this.selectedAudit.Stop_Sale_Enacted__c
        );
    }

    get formattedQuarantineTimestamp() {
        if (!this.selectedAudit || !this.selectedAudit.Stop_Sale_Timestamp__c) return '';
        const dt = new Date(this.selectedAudit.Stop_Sale_Timestamp__c);
        return dt.toLocaleString();
    }

    get selectedAuditFacilityName() {
        return (this.selectedAudit && this.selectedAudit.Facility__r) ? this.selectedAudit.Facility__r.Name : 'N/A';
    }

    get selectedAuditFacilityPremiseId() {
        return (this.selectedAudit && this.selectedAudit.Facility__r && this.selectedAudit.Facility__r.Premise_Registry_ID__c)
            ? this.selectedAudit.Facility__r.Premise_Registry_ID__c
            : 'Unregistered';
    }

    get selectedAuditFacilityCompliance() {
        return (this.selectedAudit && this.selectedAudit.Facility__r && this.selectedAudit.Facility__r.Compliance_Status__c)
            ? this.selectedAudit.Facility__r.Compliance_Status__c
            : 'Unknown';
    }

    get facilityStandingBadgeClass() {
        const status = this.selectedAuditFacilityCompliance;
        if (status === 'Compliant') return 'slds-badge slds-badge_success';
        if (status === 'Suspended' || status === 'Revoked') return 'slds-badge slds-badge_destructive';
        return 'slds-badge slds-badge_warning';
    }

    get selectedAuditInspectorName() {
        return (this.selectedAudit && this.selectedAudit.Inspector__r) ? this.selectedAudit.Inspector__r.Name : 'Unassigned Field Agent';
    }

    get scoreBoxClass() {
        if (!this.selectedAudit) return 'score-box';
        const score = this.selectedAudit.Audit_Score__c || 0;
        if (score >= 85) return 'score-box score-box-pass';
        if (score >= 70) return 'score-box score-box-conditional';
        return 'score-box score-box-fail';
    }

    get totalFindingsCount() {
        return this.auditSummaryStats ? this.auditSummaryStats.totalFindings : 0;
    }

    get criticalFindingsCount() {
        return this.auditSummaryStats ? this.auditSummaryStats.criticalFindings : 0;
    }

    get unresolvedFindingsCount() {
        return this.auditSummaryStats ? this.auditSummaryStats.unresolvedFindings : 0;
    }

    get formattedTotalFines() {
        const fines = this.auditSummaryStats ? (this.auditSummaryStats.totalFinesAssessed || 0) : 0;
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(fines);
    }

    get hasFindings() {
        return this.findingsList && this.findingsList.length > 0;
    }

    get findingsList() {
        if (!this.selectedAuditFindings) return [];
        return this.selectedAuditFindings.map(f => {
            let severityBadge = 'slds-badge ';
            if (f.Severity__c === 'Critical Violation') {
                severityBadge += 'badge-severity-critical';
            } else if (f.Severity__c === 'Major') {
                severityBadge += 'badge-severity-major';
            } else {
                severityBadge += 'badge-severity-minor';
            }

            const fine = f.Statutory_Fine_Amount__c
                ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(f.Statutory_Fine_Amount__c)
                : '$0.00';

            return {
                ...f,
                severityBadgeClass: severityBadge,
                formattedFine: fine
            };
        });
    }

    // Live Grade Calculator for Modal
    get calculatedGradeText() {
        const score = Number(this.newAuditScore);
        if (isNaN(score) || score === null) return 'Pending Score';
        if (score >= 85) return 'Pass';
        if (score >= 70) return 'Conditional Pass';
        return 'Failed - Immediate Revocation';
    }

    get calculatedGradeBadgeClass() {
        const score = Number(this.newAuditScore);
        if (score >= 85) return 'slds-badge grade-badge-pass';
        if (score >= 70) return 'slds-badge grade-badge-conditional';
        return 'slds-badge grade-badge-fail';
    }

    get isSubmitDisabled() {
        return !this.newAuditFacilityId || !this.newAuditType || !this.newAuditDate || this.newAuditScore === null;
    }

    get isEnactButtonDisabled() {
        return !this.enactReason.trim() || !this.enactAttestationChecked;
    }

    get isLiftButtonDisabled() {
        return !this.liftReason.trim();
    }

    get hasNewFindings() {
        return this.newFindings && this.newFindings.length > 0;
    }

    get newFindingsCount() {
        return this.newFindings ? this.newFindings.length : 0;
    }

    // Event Handlers
    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredAuditsResult)
            .then(() => {
                if (this.selectedAuditId) {
                    return this.selectAuditById(this.selectedAuditId);
                }
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSelectAudit(event) {
        const auditId = event.currentTarget.dataset.id;
        this.selectAuditById(auditId);
    }

    selectAuditById(auditId) {
        this.selectedAuditId = auditId;
        this.isLoading = true;
        return getAuditDetails({ auditId })
            .then(wrapper => {
                this.auditSummaryStats = wrapper;
                this.selectedAudit = wrapper.audit;
                this.selectedAuditFindings = wrapper.audit.Audit_Findings__r || [];
            })
            .catch(error => {
                this.showToast('Error Fetching Audit Details', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // New Audit Modal Actions
    openNewAuditModal() {
        this.newAuditFacilityId = '';
        this.newAuditInspectorId = '';
        this.newAuditType = 'Annual Routine';
        this.newAuditDate = this.getTodayDate();
        this.newAuditScore = 85;
        this.newAuditNotes = '';
        this.newFindings = [];
        this.isNewAuditModalOpen = true;
    }

    closeNewAuditModal() {
        this.isNewAuditModalOpen = false;
    }

    handleFacilitySelect(event) {
        this.newAuditFacilityId = event.target.value;
    }

    handleInspectorSelect(event) {
        this.newAuditInspectorId = event.target.value;
    }

    handleAuditTypeSelect(event) {
        this.newAuditType = event.target.value;
    }

    handleAuditDateChange(event) {
        this.newAuditDate = event.target.value;
    }

    handleScoreChange(event) {
        this.newAuditScore = event.target.value ? Number(event.target.value) : null;
    }

    handleNotesChange(event) {
        this.newAuditNotes = event.target.value;
    }

    handleAddFindingRow() {
        const nextIndex = this.newFindings.length + 1;
        this.newFindings = [
            ...this.newFindings,
            {
                key: Date.now() + Math.random(),
                displayIndex: nextIndex,
                Finding_Category__c: 'Security & Surveillance',
                Severity__c: 'Minor',
                Statutory_Fine_Amount__c: 250.00,
                Corrective_Action_Plan__c: '',
                Resolved__c: false
            }
        ];
    }

    handleRemoveFindingRow(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.newFindings = this.newFindings.filter((_, i) => i !== index);
        // Re-index display numbers
        this.newFindings = this.newFindings.map((f, i) => ({
            ...f,
            displayIndex: i + 1
        }));
    }

    handleFindingFieldChange(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.field;
        let val;

        if (event.target.type === 'checkbox') {
            val = event.target.checked;
        } else if (field === 'Statutory_Fine_Amount__c') {
            val = event.target.value ? parseFloat(event.target.value) : 0;
        } else {
            val = event.target.value;
        }

        const updated = [...this.newFindings];
        updated[index] = { ...updated[index], [field]: val };
        this.newFindings = updated;
    }

    submitNewAudit() {
        if (this.newAuditScore < 0 || this.newAuditScore > 100) {
            this.showToast('Validation Error', 'Inspection Audit Score must be between 0 and 100.', 'error');
            return;
        }

        this.isLoading = true;

        // Clean findings list for Apex
        const cleanedFindings = this.newFindings.map(f => ({
            Finding_Category__c: f.Finding_Category__c,
            Severity__c: f.Severity__c,
            Statutory_Fine_Amount__c: f.Statutory_Fine_Amount__c,
            Corrective_Action_Plan__c: f.Corrective_Action_Plan__c,
            Resolved__c: f.Resolved__c
        }));

        createAudit({
            facilityId: this.newAuditFacilityId,
            inspectorId: this.newAuditInspectorId || null,
            auditType: this.newAuditType,
            auditDate: this.newAuditDate,
            score: this.newAuditScore,
            summaryNotes: this.newAuditNotes,
            findings: cleanedFindings
        })
            .then(createdAudit => {
                this.showToast('Success', `Field Inspection Audit ${createdAudit.Name} created successfully.`, 'success');
                this.closeNewAuditModal();
                return refreshApex(this.wiredAuditsResult).then(() => {
                    this.selectAuditById(createdAudit.Id);
                });
            })
            .catch(error => {
                this.showToast('Failed to Create Audit', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Enact Stop-Sale Modal Actions
    openEnactModal() {
        this.enactReason = '';
        this.enactAttestationChecked = false;
        this.isEnactModalOpen = true;
    }

    closeEnactModal() {
        this.isEnactModalOpen = false;
    }

    handleEnactReasonChange(event) {
        this.enactReason = event.target.value;
    }

    handleEnactAttestationChange(event) {
        this.enactAttestationChecked = event.target.checked;
    }

    submitEnactStopSale() {
        if (!this.selectedAuditId) return;
        this.isLoading = true;

        enactStopSale({
            auditId: this.selectedAuditId,
            reason: this.enactReason
        })
            .then(lockedPackagesCount => {
                this.showToast(
                    'Emergency Order Enacted',
                    `Statewide Stop-Sale Enacted. Facility Suspended. ${lockedPackagesCount} inventory packages locked in Quarantine.`,
                    'warning'
                );
                this.closeEnactModal();
                return refreshApex(this.wiredAuditsResult).then(() => {
                    return this.selectAuditById(this.selectedAuditId);
                });
            })
            .catch(error => {
                this.showToast('Stop-Sale Execution Failed', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Lift Quarantine Modal Actions
    openLiftModal() {
        this.liftReason = '';
        this.isLiftModalOpen = true;
    }

    closeLiftModal() {
        this.isLiftModalOpen = false;
    }

    handleLiftReasonChange(event) {
        this.liftReason = event.target.value;
    }

    submitLiftStopSale() {
        if (!this.selectedAuditId) return;
        this.isLoading = true;

        liftStopSale({
            auditId: this.selectedAuditId,
            reason: this.liftReason
        })
            .then(() => {
                this.showToast(
                    'Order Rescinded',
                    'Stop-Sale Quarantine lifted. Facility standing restored to Compliant.',
                    'success'
                );
                this.closeLiftModal();
                return refreshApex(this.wiredAuditsResult).then(() => {
                    return this.selectAuditById(this.selectedAuditId);
                });
            })
            .catch(error => {
                this.showToast('Failed to Lift Quarantine', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Utilities
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
