import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getManifests from '@salesforce/apex/TransferManifestController.getManifests';
import getManifestDetails from '@salesforce/apex/TransferManifestController.getManifestDetails';
import createManifest from '@salesforce/apex/TransferManifestController.createManifest';
import signManifest from '@salesforce/apex/TransferManifestController.signManifest';
import getFacilities from '@salesforce/apex/TransferManifestController.getFacilities';
import getAvailablePackages from '@salesforce/apex/TransferManifestController.getAvailablePackages';

export default class DualSignaturePad extends LightningElement {
    @api recordId;

    @track manifestList = [];
    @track selectedManifestId;
    @track manifest;
    @track lineItems = [];
    @track isLoading = false;

    // Modals
    @track isSignModalOpen = false;
    @track isCreateModalOpen = false;

    // Sign Form
    @track signRole = 'Dispatcher';
    @track signerName = '';
    @track hasAttested = false;

    // Create Form
    @track facilityList = [];
    @track newOriginId = '';
    @track newDestinationId = '';
    @track newTransporterId = '';
    @track newDriverName = '';
    @track newDriverLicense = '';
    @track newVehicleVIN = '';
    @track newVehiclePlate = '';
    @track availablePackages = [];
    @track selectedPackageIds = [];

    connectedCallback() {
        if (this.recordId) {
            this.selectedManifestId = this.recordId;
            this.loadManifestDetails(this.recordId);
        } else {
            this.loadManifests();
        }
        this.loadFacilities();
    }

    get isStandalone() {
        return !this.recordId;
    }

    get hasManifest() {
        return !!this.manifest && !!this.manifest.Id;
    }

    get hasNoManifests() {
        return !this.isLoading && (!this.manifestList || this.manifestList.length === 0) && !this.manifest;
    }

    get manifestOptions() {
        return this.manifestList.map(m => {
            const originName = m.Origin_Facility__r ? m.Origin_Facility__r.Name : 'Origin';
            const destName = m.Destination_Facility__r ? m.Destination_Facility__r.Name : 'Dest';
            return {
                label: `${m.Name} (${originName} ➔ ${destName}) [${m.Status__c}]`,
                value: m.Id
            };
        });
    }

    get facilityOptions() {
        return this.facilityList.map(f => ({
            label: `${f.Name} (${f.Facility_Type__c}) - ${f.Premise_Registry_ID__c || 'N/A'}`,
            value: f.Id
        }));
    }

    get isSignDisabled() {
        if (!this.manifest) return true;
        return this.manifest.Status__c === 'Delivered' || this.manifest.Status__c === 'Rejected';
    }

    get statusBadgeClass() {
        const status = this.manifest?.Status__c;
        if (status === 'Draft') return 'mmap-badge badge-draft';
        if (status === 'Dispatched') return 'mmap-badge badge-dispatched';
        if (status === 'In Transit') return 'mmap-badge badge-in-transit';
        if (status === 'Delivered') return 'mmap-badge badge-delivered';
        if (status === 'Rejected') return 'mmap-badge badge-rejected';
        return 'mmap-badge badge-draft';
    }

    get step1Class() {
        if (!this.manifest) return 'custody-step-card';
        if (this.manifest.Dispatcher_Signature__c) return 'custody-step-card completed';
        if (this.manifest.Status__c === 'Draft') return 'custody-step-card active';
        return 'custody-step-card';
    }

    get step2Class() {
        if (!this.manifest) return 'custody-step-card';
        if (this.manifest.Transporter_Signature__c) return 'custody-step-card completed';
        if (this.manifest.Status__c === 'Dispatched') return 'custody-step-card active';
        return 'custody-step-card';
    }

    get step3Class() {
        if (!this.manifest) return 'custody-step-card';
        if (this.manifest.Receiver_Signature__c) return 'custody-step-card completed';
        if (this.manifest.Status__c === 'In Transit') return 'custody-step-card active';
        return 'custody-step-card';
    }

    get formattedCreatedDate() {
        if (!this.manifest?.CreatedDate) return 'N/A';
        return new Date(this.manifest.CreatedDate).toLocaleString();
    }

    get originFacilityName() {
        return this.manifest?.Origin_Facility__r?.Name || 'N/A';
    }

    get originFacilityRegistryId() {
        return this.manifest?.Origin_Facility__r?.Premise_Registry_ID__c || 'N/A';
    }

    get destinationFacilityName() {
        return this.manifest?.Destination_Facility__r?.Name || 'N/A';
    }

    get destinationFacilityRegistryId() {
        return this.manifest?.Destination_Facility__r?.Premise_Registry_ID__c || 'N/A';
    }

    get transporterFacilityName() {
        return this.manifest?.Transporter_Facility__r?.Name || 'Self-Transported / Direct';
    }

    get driverDisplayName() {
        return this.manifest?.Driver_Name__c || 'Designated Driver Not Assigned';
    }

    get driverLicenseDisplay() {
        return this.manifest?.Driver_License_No__c || 'N/A';
    }

    get vehicleVINDisplay() {
        return this.manifest?.Vehicle_VIN__c || 'N/A';
    }

    get vehiclePlateDisplay() {
        return this.manifest?.Vehicle_License_Plate__c || 'N/A';
    }

    get departureDisplay() {
        if (!this.manifest?.Departure_Timestamp__c) return 'Pending Departure';
        return new Date(this.manifest.Departure_Timestamp__c).toLocaleString();
    }

    get arrivalDisplay() {
        if (this.manifest?.Actual_Arrival__c) {
            return `Delivered: ${new Date(this.manifest.Actual_Arrival__c).toLocaleString()}`;
        }
        if (this.manifest?.Estimated_Arrival__c) {
            return `Est: ${new Date(this.manifest.Estimated_Arrival__c).toLocaleString()}`;
        }
        return 'In Transit';
    }

    get lineItemCount() {
        return this.lineItems ? this.lineItems.length : 0;
    }

    get hasLineItems() {
        return this.lineItemCount > 0;
    }

    get totalGrossWeight() {
        if (!this.lineItems || this.lineItems.length === 0) return '0.00';
        const total = this.lineItems.reduce((sum, item) => sum + (Number(item.Gross_Weight_Grams__c) || 0), 0);
        return total.toFixed(2);
    }

    get roleOptions() {
        return [
            { label: 'Origin Facility Dispatcher', value: 'Dispatcher' },
            { label: 'Authorized Transport Driver', value: 'Transporter' },
            { label: 'Destination Facility Vault Receiver', value: 'Receiver' }
        ];
    }

    get nextStatusLabel() {
        if (this.signRole === 'Dispatcher') return 'Dispatched';
        if (this.signRole === 'Transporter') return 'In Transit';
        if (this.signRole === 'Receiver') return 'Delivered';
        return 'Updated';
    }

    get isSubmitSignDisabled() {
        return !this.signerName || this.signerName.trim() === '' || !this.hasAttested || this.isLoading;
    }

    get isSubmitCreateDisabled() {
        return !this.newOriginId || !this.newDestinationId || (this.newOriginId === this.newDestinationId) || this.isLoading;
    }

    get hasAvailablePackages() {
        return this.availablePackages && this.availablePackages.length > 0;
    }

    // Data Loaders
    async loadManifests() {
        this.isLoading = true;
        try {
            const result = await getManifests();
            this.manifestList = result || [];
            if (this.manifestList.length > 0 && !this.selectedManifestId) {
                this.selectedManifestId = this.manifestList[0].Id;
                await this.loadManifestDetails(this.selectedManifestId);
            }
        } catch (error) {
            this.showToast('Error', error?.body?.message || 'Failed to retrieve manifests', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadManifestDetails(manifestId) {
        if (!manifestId) return;
        this.isLoading = true;
        try {
            const data = await getManifestDetails({ manifestId });
            this.manifest = data;
            const rawLineItems = data?.Manifest_Line_Items__r || [];
            this.lineItems = rawLineItems.map(item => ({
                ...item,
                packageName: item.Product_Package__r ? item.Product_Package__r.Name : 'Package Item',
                productType: item.Product_Package__r ? item.Product_Package__r.Product_Type__c : 'Marijuana Item',
                labStatus: item.Product_Package__r ? item.Product_Package__r.Lab_Safety_Status__c : 'Passed'
            }));
        } catch (error) {
            this.showToast('Error', error?.body?.message || 'Failed to load manifest details', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadFacilities() {
        try {
            const result = await getFacilities();
            this.facilityList = result || [];
        } catch (error) {
            // Non-critical background load
        }
    }

    async loadAvailablePackages(facilityId) {
        if (!facilityId) {
            this.availablePackages = [];
            return;
        }
        try {
            const result = await getAvailablePackages({ facilityId });
            this.availablePackages = (result || []).map(pkg => ({
                ...pkg,
                isSelected: this.selectedPackageIds.includes(pkg.Id)
            }));
        } catch (error) {
            this.availablePackages = [];
        }
    }

    // Event Handlers
    handleManifestChange(event) {
        this.selectedManifestId = event.detail.value;
        this.loadManifestDetails(this.selectedManifestId);
    }

    handleRefresh() {
        if (this.selectedManifestId) {
            this.loadManifestDetails(this.selectedManifestId);
        } else {
            this.loadManifests();
        }
    }

    // Sign Modal Handlers
    openSignModal() {
        if (!this.manifest) return;
        const currentStatus = this.manifest.Status__c;
        if (currentStatus === 'Draft') {
            this.signRole = 'Dispatcher';
        } else if (currentStatus === 'Dispatched') {
            this.signRole = 'Transporter';
        } else if (currentStatus === 'In Transit') {
            this.signRole = 'Receiver';
        } else {
            this.signRole = 'Dispatcher';
        }
        this.signerName = '';
        this.hasAttested = false;
        this.isSignModalOpen = true;
    }

    closeSignModal() {
        this.isSignModalOpen = false;
    }

    handleRoleChange(event) {
        this.signRole = event.detail.value;
    }

    handleSignerNameChange(event) {
        this.signerName = event.detail.value;
    }

    handleAttestationChange(event) {
        this.hasAttested = event.target.checked;
    }

    async submitSignature() {
        if (this.isSubmitSignDisabled) return;

        this.isLoading = true;
        try {
            const updated = await signManifest({
                manifestId: this.manifest.Id,
                role: this.signRole,
                signatureName: this.signerName
            });
            this.showToast('Handshake Verified', `Successfully signed as ${this.signRole}. Manifest is now ${updated.Status__c}.`, 'success');
            this.closeSignModal();
            this.manifest = updated;
            await this.loadManifestDetails(updated.Id);
            if (this.isStandalone) {
                await this.loadManifests();
            }
        } catch (error) {
            this.showToast('Signature Error', error?.body?.message || 'Failed to submit digital signature', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Create Modal Handlers
    openCreateModal() {
        this.newOriginId = '';
        this.newDestinationId = '';
        this.newTransporterId = '';
        this.newDriverName = '';
        this.newDriverLicense = '';
        this.newVehicleVIN = '';
        this.newVehiclePlate = '';
        this.selectedPackageIds = [];
        this.availablePackages = [];
        this.isCreateModalOpen = true;
    }

    closeCreateModal() {
        this.isCreateModalOpen = false;
    }

    handleNewOriginChange(event) {
        this.newOriginId = event.detail.value;
        this.selectedPackageIds = [];
        this.loadAvailablePackages(this.newOriginId);
    }

    handleNewDestinationChange(event) {
        this.newDestinationId = event.detail.value;
    }

    handleNewTransporterChange(event) {
        this.newTransporterId = event.detail.value;
    }

    handleNewDriverNameChange(event) {
        this.newDriverName = event.detail.value;
    }

    handleNewDriverLicenseChange(event) {
        this.newDriverLicense = event.detail.value;
    }

    handleNewVehicleVINChange(event) {
        this.newVehicleVIN = event.detail.value;
    }

    handleNewVehiclePlateChange(event) {
        this.newVehiclePlate = event.detail.value;
    }

    handlePackageSelection(event) {
        const pkgId = event.target.dataset.id;
        const isChecked = event.target.checked;
        if (isChecked) {
            if (!this.selectedPackageIds.includes(pkgId)) {
                this.selectedPackageIds = [...this.selectedPackageIds, pkgId];
            }
        } else {
            this.selectedPackageIds = this.selectedPackageIds.filter(id => id !== pkgId);
        }
    }

    async submitCreateManifest() {
        if (this.isSubmitCreateDisabled) return;

        this.isLoading = true;
        try {
            const created = await createManifest({
                originFacilityId: this.newOriginId,
                destinationFacilityId: this.newDestinationId,
                transporterFacilityId: this.newTransporterId || null,
                driverName: this.newDriverName,
                driverLicense: this.newDriverLicense,
                vehicleVIN: this.newVehicleVIN,
                packageIds: this.selectedPackageIds
            });

            this.showToast('Manifest Created', `Electronic manifest ${created.Name} has been generated with ${created.Manifest_Line_Items__r ? created.Manifest_Line_Items__r.length : 0} line items.`, 'success');
            this.closeCreateModal();
            this.selectedManifestId = created.Id;
            this.manifest = created;
            await this.loadManifestDetails(created.Id);
            await this.loadManifests();
        } catch (error) {
            this.showToast('Creation Error', error?.body?.message || 'Failed to create transfer manifest', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
