import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTelemetryEvents from '@salesforce/apex/Data360Controller.getTelemetryEvents';
import logTelemetryEvent from '@salesforce/apex/Data360Controller.logTelemetryEvent';
import updateEvent from '@salesforce/apex/Data360Controller.updateEvent';
import archiveEvent from '@salesforce/apex/Data360Controller.archiveEvent';

export default class Data360Manager extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track allRecords = [];
    @track filteredRecords = [];
    @track isLoading = true;
    @track isSubmitting = false;

    // Metadata banner properties
    rfidTag = 'Loading...';
    facilityIdDisplay = 'N/A';
    defaultRoom = 'Vault';
    recordName = '';
    totalCount = 0;

    // Filter controls
    searchKey = '';
    showArchived = false;

    // Modal controls: Log Event
    isLogModalOpen = false;
    newActionType = 'STAGE_MOVE';
    newRoomLocation = '';
    newMetricReading = null;

    // Modal controls: Edit Event
    isEditModalOpen = false;
    editingEventId = '';
    editRoomLocation = '';
    editMetricReading = null;

    // Picklist options for Action Type
    get actionTypeOptions() {
        return [
            { label: 'STAGE_MOVE (Physical Stage / Bay Relocation)', value: 'STAGE_MOVE' },
            { label: 'RFID_SCAN (State RFID Gate Verification)', value: 'RFID_SCAN' },
            { label: 'SAMPLE_TEST (QC Lab Panel Extraction)', value: 'SAMPLE_TEST' },
            { label: 'DISPENSED (Point-of-Sale Dispense Checkout)', value: 'DISPENSED' }
        ];
    }

    get hasRecords() {
        return this.filteredRecords && this.filteredRecords.length > 0;
    }

    get filteredRecordCount() {
        return this.filteredRecords ? this.filteredRecords.length : 0;
    }

    get pluralS() {
        return this.totalCount === 1 ? '' : 's';
    }

    // Datatable columns definition
    columns = [
        {
            label: 'Event UUID',
            fieldName: 'eventIdSnippet',
            type: 'text',
            initialWidth: 140,
            tooltip: { fieldName: 'eventId' },
            cellAttributes: { class: 'font-mono' }
        },
        {
            label: 'Timestamp (UTC)',
            fieldName: 'formattedTimestamp',
            type: 'text',
            initialWidth: 175
        },
        {
            label: 'Action Type',
            fieldName: 'actionType',
            type: 'text',
            initialWidth: 145,
            cellAttributes: { class: { fieldName: 'actionClass' } }
        },
        {
            label: 'Room / Zone',
            fieldName: 'roomLocation',
            type: 'text',
            initialWidth: 170
        },
        {
            label: 'Metric Reading',
            fieldName: 'metricDisplay',
            type: 'text',
            initialWidth: 130
        },
        {
            label: 'Operator ID',
            fieldName: 'operatorUserId',
            type: 'text',
            initialWidth: 160,
            cellAttributes: { class: 'font-mono' }
        },
        {
            label: 'Status',
            fieldName: 'statusDisplay',
            type: 'text',
            initialWidth: 110,
            cellAttributes: { class: { fieldName: 'statusClass' } }
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: this.getRowActions.bind(this)
            }
        }
    ];

    connectedCallback() {
        this.loadTelemetryData();
    }

    /**
     * Dynamically controls available row actions per record state
     */
    getRowActions(row, doneCallback) {
        const actions = [
            { label: 'Edit Room / Metric', name: 'edit', iconName: 'utility:edit' }
        ];
        if (!row.isArchived) {
            actions.push({
                label: 'Archive Log (Soft-Delete)',
                name: 'archive',
                iconName: 'utility:archive'
            });
        }
        doneCallback(actions);
    }

    /**
     * Fetches telemetry logs from Data 360 controller
     */
    async loadTelemetryData() {
        this.isLoading = true;
        try {
            const data = await getTelemetryEvents({
                recordId: this.recordId,
                pageSize: 100,
                offset: 0
            });

            if (data) {
                this.rfidTag = data.rfidTag || 'N/A';
                this.facilityIdDisplay = data.facilityId || 'N/A';
                this.defaultRoom = data.defaultRoom || 'Vault Storage';
                this.recordName = data.recordName || '';

                const rawList = data.records || [];

                // Retrieve session-stored records for this package
                const sessionKey = `mmap_telemetry_${this.recordId || this.rfidTag}`;
                let sessionRecords = [];
                try {
                    const cached = sessionStorage.getItem(sessionKey);
                    if (cached) {
                        sessionRecords = JSON.parse(cached);
                    }
                } catch (e) {}

                // Merge session records with server records (avoid duplicates by eventId)
                const existingIds = new Set(rawList.map(r => r.eventId));
                const newFromSession = sessionRecords.filter(r => !existingIds.has(r.eventId));
                const combinedList = [...newFromSession, ...rawList];

                this.totalCount = combinedList.length;

                this.allRecords = combinedList.map((rec) => {
                    const formattedDate = rec.eventTimestamp
                        ? new Date(rec.eventTimestamp).toISOString().replace('T', ' ').substring(0, 19) + ' UTC'
                        : 'N/A';

                    const snippet = rec.eventId && rec.eventId.length > 8
                        ? rec.eventId.substring(0, 8) + '...'
                        : rec.eventId;

                    let actionColorClass = 'slds-text-color_default';
                    if (rec.actionType === 'STAGE_MOVE') actionColorClass = 'badge-action-move';
                    else if (rec.actionType === 'RFID_SCAN') actionColorClass = 'badge-action-scan';
                    else if (rec.actionType === 'SAMPLE_TEST') actionColorClass = 'badge-action-sample';
                    else if (rec.actionType === 'DISPENSED') actionColorClass = 'badge-action-dispensed';

                    return {
                        ...rec,
                        eventIdSnippet: snippet,
                        formattedTimestamp: formattedDate,
                        metricDisplay: rec.metricReading != null ? `${rec.metricReading} g` : '--',
                        statusDisplay: rec.isArchived ? 'Archived' : 'Active',
                        statusClass: rec.isArchived ? 'status-archived' : 'status-active',
                        actionClass: actionColorClass
                    };
                });

                this.applyFilters();
            }
        } catch (error) {
            this.showToast('Error Loading Telemetry', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Applies search and active/archived filters client-side
     */
    applyFilters() {
        const query = (this.searchKey || '').toLowerCase().trim();

        this.filteredRecords = this.allRecords.filter((rec) => {
            // Archived filter
            if (!this.showArchived && rec.isArchived) {
                return false;
            }

            // Text search across roomLocation, actionType, eventId, operatorUserId
            if (!query) {
                return true;
            }

            const roomMatch = rec.roomLocation && rec.roomLocation.toLowerCase().includes(query);
            const actionMatch = rec.actionType && rec.actionType.toLowerCase().includes(query);
            const eventMatch = rec.eventId && rec.eventId.toLowerCase().includes(query);
            const operatorMatch = rec.operatorUserId && rec.operatorUserId.toLowerCase().includes(query);

            return roomMatch || actionMatch || eventMatch || operatorMatch;
        });
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.applyFilters();
    }

    handleArchivedToggle(event) {
        this.showArchived = event.target.checked;
        this.applyFilters();
    }

    handleRefresh() {
        this.loadTelemetryData();
        this.showToast('Telemetry Refreshed', 'Lakehouse data re-synchronized.', 'info');
    }

    // =========================================================================
    // ROW ACTIONS: EDIT & ARCHIVE
    // =========================================================================

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.editingEventId = row.eventId;
            this.editRoomLocation = row.roomLocation;
            this.editMetricReading = row.metricReading;
            this.isEditModalOpen = true;
        } else if (actionName === 'archive') {
            this.executeArchive(row.eventId);
        }
    }

    async executeArchive(eventId) {
        this.isLoading = true;
        try {
            const result = await archiveEvent({ eventId });
            if (result && result.status === 'ARCHIVED') {
                this.showToast('Event Archived', `Event ${eventId} soft-deleted for compliance.`, 'success');
                await this.loadTelemetryData();
            }
        } catch (error) {
            this.showToast('Archival Failed', this.reduceError(error), 'error');
            this.isLoading = false;
        }
    }

    // =========================================================================
    // MODAL: LOG NEW EVENT
    // =========================================================================

    handleOpenLogModal() {
        this.newActionType = 'STAGE_MOVE';
        this.newRoomLocation = this.defaultRoom || '';
        this.newMetricReading = 450.00;
        this.isLogModalOpen = true;
    }

    handleCloseLogModal() {
        this.isLogModalOpen = false;
    }

    handleActionTypeChange(event) {
        this.newActionType = event.detail.value;
    }

    handleRoomLocationChange(event) {
        this.newRoomLocation = event.target.value;
    }

    handleMetricReadingChange(event) {
        this.newMetricReading = parseFloat(event.target.value);
    }

    async handleSubmitLogEvent() {
        if (!this.newActionType) {
            this.showToast('Validation Error', 'Please select an Action Type.', 'warning');
            return;
        }
        if (!this.newRoomLocation) {
            this.showToast('Validation Error', 'Please specify a Room / Zone Location.', 'warning');
            return;
        }

        this.isSubmitting = true;
        try {
            const result = await logTelemetryEvent({
                recordId: this.recordId,
                roomLocation: this.newRoomLocation,
                metricReading: this.newMetricReading,
                actionType: this.newActionType
            });

            if (result && result.status === 'SUCCESS') {
                const sessionKey = `mmap_telemetry_${this.recordId || this.rfidTag}`;
                let sessionRecords = [];
                try {
                    const cached = sessionStorage.getItem(sessionKey);
                    if (cached) {
                        sessionRecords = JSON.parse(cached);
                    }
                } catch (e) {}

                const newEvent = {
                    eventId: result.eventId || `EVT-${Date.now()}`,
                    rfidTag: this.rfidTag,
                    facilityId: this.facilityIdDisplay,
                    roomLocation: this.newRoomLocation,
                    metricReading: this.newMetricReading,
                    actionType: this.newActionType,
                    operatorUserId: 'Current User',
                    eventTimestamp: result.timestamp || new Date().toISOString(),
                    isArchived: false
                };

                sessionRecords.unshift(newEvent);
                try {
                    sessionStorage.setItem(sessionKey, JSON.stringify(sessionRecords));
                } catch (e) {}

                this.showToast('Telemetry Streamed', `Event ${newEvent.eventId} ingested into Lakehouse.`, 'success');
                this.isLogModalOpen = false;
                await this.loadTelemetryData();
            }
        } catch (error) {
            this.showToast('Streaming Failed', this.reduceError(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // =========================================================================
    // MODAL: EDIT EVENT
    // =========================================================================

    handleCloseEditModal() {
        this.isEditModalOpen = false;
    }

    handleEditRoomChange(event) {
        this.editRoomLocation = event.target.value;
    }

    handleEditMetricChange(event) {
        this.editMetricReading = parseFloat(event.target.value);
    }

    async handleSaveEditEvent() {
        if (!this.editRoomLocation) {
            this.showToast('Validation Error', 'Room Location cannot be blank.', 'warning');
            return;
        }

        this.isSubmitting = true;
        try {
            const result = await updateEvent({
                eventId: this.editingEventId,
                roomLocation: this.editRoomLocation,
                metricReading: this.editMetricReading
            });

            if (result && result.status === 'UPDATED') {
                this.showToast('Event Updated', `Telemetry event ${this.editingEventId} successfully updated.`, 'success');
                this.isEditModalOpen = false;
                await this.loadTelemetryData();
            }
        } catch (error) {
            this.showToast('Update Failed', this.reduceError(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // =========================================================================
    // UTILITY HELPERS
    // =========================================================================

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
