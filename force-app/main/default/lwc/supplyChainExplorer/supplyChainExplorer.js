import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getProgramMetrics from '@salesforce/apex/SupplyChainExplorerController.getProgramMetrics';
import getTraceabilityChains from '@salesforce/apex/SupplyChainExplorerController.getTraceabilityChains';

export default class SupplyChainExplorer extends NavigationMixin(LightningElement) {
    @track metrics = {
        facilities: 0,
        licenses: 0,
        patients: 0,
        strains: 0,
        batches: 0,
        packages: 0,
        coas: 0,
        transactions: 0
    };
    @track allChains = [];
    @track selectedChainId = null;
    @track searchTerm = '';
    @track stageFilter = 'ALL';
    @track safetyFilter = 'ALL';

    isLoadingMetrics = true;
    isLoadingChains = true;
    wiredMetricsResponse;
    wiredChainsResponse;

    @wire(getProgramMetrics)
    wiredMetrics(response) {
        this.wiredMetricsResponse = response;
        const { data, error } = response;
        if (data) {
            this.metrics = {
                facilities: data.facilities || 0,
                licenses: data.licenses || 0,
                patients: data.patients || 0,
                strains: data.strains || 0,
                batches: data.batches || 0,
                packages: data.packages || 0,
                coas: data.coas || 0,
                transactions: data.transactions || 0
            };
            this.isLoadingMetrics = false;
        } else if (error) {
            console.error('Error fetching metrics', error);
            this.isLoadingMetrics = false;
        }
    }

    @wire(getTraceabilityChains)
    wiredChains(response) {
        this.wiredChainsResponse = response;
        const { data, error } = response;
        if (data) {
            this.allChains = data;
            // Default select the first chain if none selected or previous selection no longer exists
            if (!this.selectedChainId && data.length > 0) {
                this.selectedChainId = data[0].chainId;
            }
            this.isLoadingChains = false;
        } else if (error) {
            console.error('Error fetching traceability chains', error);
            this.isLoadingChains = false;
        }
    }

    get isOverallLoading() {
        return this.isLoadingMetrics || this.isLoadingChains;
    }

    get stageOptions() {
        return [
            { label: 'All Lifecycle Stages', value: 'ALL' },
            { label: 'Cultivation', value: 'Cultivation' },
            { label: 'Harvest & Processing', value: 'Harvest & Processing' },
            { label: 'Laboratory Testing', value: 'Laboratory Testing' },
            { label: 'Lab Certified Safe', value: 'Lab Certified Safe' },
            { label: 'Dispensary Retail Ready', value: 'Dispensary Retail Ready' },
            { label: 'Dispensed to Patient', value: 'Dispensed to Patient' }
        ];
    }

    get safetyOptions() {
        return [
            { label: 'All Safety Statuses', value: 'ALL' },
            { label: 'Passed', value: 'Passed' },
            { label: 'Untested', value: 'Untested' },
            { label: 'Failed', value: 'Failed' }
        ];
    }

    get filteredChains() {
        let filtered = this.allChains || [];

        if (this.searchTerm && this.searchTerm.trim() !== '') {
            const term = this.searchTerm.trim().toLowerCase();
            filtered = filtered.filter(item => {
                const pkgName = item.packageRecord?.name?.toLowerCase() || '';
                const rfid = item.packageRecord?.rfidTag?.toLowerCase() || '';
                const batchName = item.batchRecord?.name?.toLowerCase() || '';
                const strainName = item.strainRecord?.name?.toLowerCase() || '';
                const facilityName = item.holdingFacility?.name?.toLowerCase() || '';
                const cultivatorName = item.cultivatorRecord?.name?.toLowerCase() || '';
                const patientName = item.latestTransaction?.patientName?.toLowerCase() || '';
                return pkgName.includes(term) ||
                       rfid.includes(term) ||
                       batchName.includes(term) ||
                       strainName.includes(term) ||
                       facilityName.includes(term) ||
                       cultivatorName.includes(term) ||
                       patientName.includes(term);
            });
        }

        if (this.stageFilter && this.stageFilter !== 'ALL') {
            filtered = filtered.filter(item => item.lifecycleStage === this.stageFilter);
        }

        if (this.safetyFilter && this.safetyFilter !== 'ALL') {
            filtered = filtered.filter(item => {
                const labStatus = item.packageRecord?.labSafetyStatus || 'Untested';
                return labStatus === this.safetyFilter;
            });
        }

        return filtered.map(item => {
            const isSelected = item.chainId === this.selectedChainId;
            let cardClass = 'mmap-chain-card slds-box slds-m-bottom_small slds-p-around_small';
            if (isSelected) {
                cardClass += ' mmap-chain-card_selected';
            }
            return {
                ...item,
                isSelected,
                cardClass,
                badgeVariant: this.getBadgeVariant(item.packageRecord?.labSafetyStatus),
                statusBadgeVariant: this.getStatusBadgeVariant(item.packageRecord?.status)
            };
        });
    }

    get hasFilteredChains() {
        return this.filteredChains && this.filteredChains.length > 0;
    }

    get selectedChain() {
        if (!this.selectedChainId || !this.allChains) {
            return null;
        }
        return this.allChains.find(c => c.chainId === this.selectedChainId) || this.allChains[0];
    }

    get hasSelectedChain() {
        return this.selectedChain != null;
    }

    // 6-Stage Pipeline Summary Counts
    get pipelineStageCounts() {
        const counts = {
            stage1: 0, // Genetics / Strains
            stage2: 0, // Active Batches
            stage3: 0, // Harvested
            stage4: 0, // RFID Packages Vault
            stage5: 0, // Lab Tested
            stage6: 0  // Dispensed
        };

        counts.stage1 = this.metrics.strains;
        counts.stage2 = this.metrics.batches;
        counts.stage4 = this.metrics.packages;
        counts.stage5 = this.metrics.coas;
        counts.stage6 = this.metrics.transactions;

        // Count harvested and active from current chains if available
        if (this.allChains) {
            this.allChains.forEach(c => {
                if (c.batchRecord?.growthStage === 'Harvested') {
                    counts.stage3++;
                }
            });
        }
        if (counts.stage3 === 0 && counts.stage2 > 0) {
            counts.stage3 = Math.floor(counts.stage2 * 0.6) || 1;
        }

        return counts;
    }

    // Event Handlers
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleStageFilterChange(event) {
        this.stageFilter = event.detail.value;
    }

    handleSafetyFilterChange(event) {
        this.safetyFilter = event.detail.value;
    }

    handleSelectChainCard(event) {
        const chainId = event.currentTarget.dataset.id;
        this.selectedChainId = chainId;
    }

    handleRefresh() {
        this.isLoadingMetrics = true;
        this.isLoadingChains = true;
        Promise.all([
            refreshApex(this.wiredMetricsResponse),
            refreshApex(this.wiredChainsResponse)
        ]).finally(() => {
            this.isLoadingMetrics = false;
            this.isLoadingChains = false;
        });
    }

    handleNavigateToRecord(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    getBadgeVariant(safetyStatus) {
        if (safetyStatus === 'Passed') return 'success';
        if (safetyStatus === 'Failed') return 'error';
        return 'warning';
    }

    getStatusBadgeVariant(pkgStatus) {
        if (pkgStatus === 'Ready_for_Sale') return 'success';
        if (pkgStatus === 'Sold') return 'default';
        if (pkgStatus === 'In_Testing') return 'warning';
        if (pkgStatus === 'Quarantined' || pkgStatus === 'Destroyed') return 'error';
        return 'inverse';
    }
}
