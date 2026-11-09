/**
 * @description Controller for the Commonwealth Medical Marijuana Supply Chain Explorer
 *              Provides executive aggregate KPIs and full seed-to-sale traceability chain lineage.
 */
public with sharing class SupplyChainExplorerController {

    /**
     * @description Returns real-time aggregate KPI counts across all regulatory pipeline entities.
     * @return Map<String, Integer> Mapping entity category to record count
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getProgramMetrics() {
        Map<String, Integer> metrics = new Map<String, Integer>();
        metrics.put('facilities', [SELECT count() FROM Account WHERE Facility_Type__c != null]);
        metrics.put('licenses', [SELECT count() FROM Business_License__c]);
        metrics.put('patients', [SELECT count() FROM Patient_Registration__c]);
        metrics.put('strains', [SELECT count() FROM Strain__c]);
        metrics.put('batches', [SELECT count() FROM Plant_Batch__c]);
        metrics.put('packages', [SELECT count() FROM Product_Package__c]);
        metrics.put('coas', [SELECT count() FROM Lab_Test_Result__c]);
        metrics.put('transactions', [SELECT count() FROM Dispense_Transaction__c]);
        return metrics;
    }

    /**
     * @description Queries product packages with parent plant batches, strains, facilities,
     *              and child lab tests and dispense transactions to construct end-to-end lineage trees.
     * @return List<Map<String, Object>> Structured list of traceability chains
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTraceabilityChains() {
        List<Product_Package__c> packages = [
            SELECT Id, Name, RFID_Tag__c, Product_Type__c, Net_Weight_Grams__c, Unit_Price__c,
                   Package_Status__c, Lab_Safety_Status__c, CreatedDate,
                   Holding_Facility__c, Holding_Facility__r.Name, Holding_Facility__r.Premise_Registry_ID__c,
                   Holding_Facility__r.Facility_Type__c,
                   Plant_Batch__c, Plant_Batch__r.Name, Plant_Batch__r.Growth_Stage__c,
                   Plant_Batch__r.Planted_Date__c, Plant_Batch__r.Harvest_Date__c,
                   Plant_Batch__r.Wet_Weight_Grams__c, Plant_Batch__r.Dry_Weight_Grams__c,
                   Plant_Batch__r.Room_Location__c,
                   Plant_Batch__r.Cultivator__c, Plant_Batch__r.Cultivator__r.Name,
                   Plant_Batch__r.Cultivator__r.Premise_Registry_ID__c,
                   Plant_Batch__r.Strain__c, Plant_Batch__r.Strain__r.Name,
                   Plant_Batch__r.Strain__r.Classification__c,
                   Plant_Batch__r.Strain__r.Target_THC_Percentage__c,
                   Plant_Batch__r.Strain__r.Target_CBD_Percentage__c,
                   (SELECT Id, Name, Testing_Laboratory__c, Testing_Laboratory__r.Name,
                           Test_Date__c, THC_Potency_Pct__c, CBD_Potency_Pct__c,
                           Pesticides_Pass__c, Heavy_Metals_Pass__c, Mycotoxins_Pass__c,
                           Residual_Solvents_Pass__c, Overall_Status__c
                    FROM Lab_Test_Results__r ORDER BY CreatedDate DESC),
                   (SELECT Id, Name, Dispensary__c, Dispensary__r.Name,
                           Patient_Registration__c, Patient_Registration__r.Name,
                           Patient_Registration__r.Patient__r.Name,
                           Patient_Registration__r.Barcode_String__c,
                           Grams_Dispensed__c, Total_Amount__c, Transaction_Timestamp__c
                    FROM Dispense_Transactions__r ORDER BY Transaction_Timestamp__c DESC)
            FROM Product_Package__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        List<Map<String, Object>> chainResults = new List<Map<String, Object>>();

        for (Product_Package__c pkg : packages) {
            Map<String, Object> chain = new Map<String, Object>();
            chain.put('chainId', pkg.Id);

            // Package Details
            Map<String, Object> pkgMap = new Map<String, Object>();
            pkgMap.put('id', pkg.Id);
            pkgMap.put('name', pkg.Name);
            pkgMap.put('rfidTag', pkg.RFID_Tag__c != null ? pkg.RFID_Tag__c : 'N/A');
            pkgMap.put('productType', pkg.Product_Type__c);
            pkgMap.put('netWeight', pkg.Net_Weight_Grams__c);
            pkgMap.put('unitPrice', pkg.Unit_Price__c);
            pkgMap.put('status', pkg.Package_Status__c);
            pkgMap.put('labSafetyStatus', pkg.Lab_Safety_Status__c);
            pkgMap.put('createdDate', pkg.CreatedDate);
            chain.put('packageRecord', pkgMap);

            // Holding Facility Details
            Map<String, Object> holdingFacMap = new Map<String, Object>();
            if (pkg.Holding_Facility__r != null) {
                holdingFacMap.put('id', pkg.Holding_Facility__c);
                holdingFacMap.put('name', pkg.Holding_Facility__r.Name);
                holdingFacMap.put('premiseId', pkg.Holding_Facility__r.Premise_Registry_ID__c);
                holdingFacMap.put('type', pkg.Holding_Facility__r.Facility_Type__c);
            }
            chain.put('holdingFacility', holdingFacMap);

            // Plant Batch Details
            Map<String, Object> batchMap = new Map<String, Object>();
            Map<String, Object> cultivatorMap = new Map<String, Object>();
            Map<String, Object> strainMap = new Map<String, Object>();

            if (pkg.Plant_Batch__r != null) {
                batchMap.put('id', pkg.Plant_Batch__c);
                batchMap.put('name', pkg.Plant_Batch__r.Name);
                batchMap.put('growthStage', pkg.Plant_Batch__r.Growth_Stage__c);
                batchMap.put('plantedDate', pkg.Plant_Batch__r.Planted_Date__c);
                batchMap.put('harvestDate', pkg.Plant_Batch__r.Harvest_Date__c);
                batchMap.put('wetWeight', pkg.Plant_Batch__r.Wet_Weight_Grams__c);
                batchMap.put('dryWeight', pkg.Plant_Batch__r.Dry_Weight_Grams__c);
                batchMap.put('roomLocation', pkg.Plant_Batch__r.Room_Location__c);

                if (pkg.Plant_Batch__r.Cultivator__r != null) {
                    cultivatorMap.put('id', pkg.Plant_Batch__r.Cultivator__c);
                    cultivatorMap.put('name', pkg.Plant_Batch__r.Cultivator__r.Name);
                    cultivatorMap.put('premiseId', pkg.Plant_Batch__r.Cultivator__r.Premise_Registry_ID__c);
                }

                if (pkg.Plant_Batch__r.Strain__r != null) {
                    strainMap.put('id', pkg.Plant_Batch__r.Strain__c);
                    strainMap.put('name', pkg.Plant_Batch__r.Strain__r.Name);
                    strainMap.put('classification', pkg.Plant_Batch__r.Strain__r.Classification__c);
                    strainMap.put('targetThc', pkg.Plant_Batch__r.Strain__r.Target_THC_Percentage__c);
                    strainMap.put('targetCbd', pkg.Plant_Batch__r.Strain__r.Target_CBD_Percentage__c);
                }
            }
            chain.put('batchRecord', batchMap);
            chain.put('cultivatorRecord', cultivatorMap);
            chain.put('strainRecord', strainMap);

            // Lab Tests
            List<Map<String, Object>> labList = new List<Map<String, Object>>();
            Map<String, Object> latestLab = null;
            if (pkg.Lab_Test_Results__r != null && !pkg.Lab_Test_Results__r.isEmpty()) {
                for (Lab_Test_Result__c lab : pkg.Lab_Test_Results__r) {
                    Map<String, Object> labItem = new Map<String, Object>();
                    labItem.put('id', lab.Id);
                    labItem.put('name', lab.Name);
                    labItem.put('labName', lab.Testing_Laboratory__r != null ? lab.Testing_Laboratory__r.Name : 'Certified Lab');
                    labItem.put('labId', lab.Testing_Laboratory__c);
                    labItem.put('testDate', lab.Test_Date__c);
                    labItem.put('thcPotency', lab.THC_Potency_Pct__c);
                    labItem.put('cbdPotency', lab.CBD_Potency_Pct__c);
                    labItem.put('status', lab.Overall_Status__c);
                    labItem.put('pesticidesPass', lab.Pesticides_Pass__c);
                    labItem.put('heavyMetalsPass', lab.Heavy_Metals_Pass__c);
                    labItem.put('mycotoxinsPass', lab.Mycotoxins_Pass__c);
                    labItem.put('residualSolventsPass', lab.Residual_Solvents_Pass__c);
                    labList.add(labItem);
                }
                latestLab = labList[0];
            }
            chain.put('labTests', labList);
            chain.put('hasLabTest', !labList.isEmpty());
            chain.put('latestLabTest', latestLab);

            // Dispense Transactions
            List<Map<String, Object>> txnList = new List<Map<String, Object>>();
            Map<String, Object> latestTxn = null;
            if (pkg.Dispense_Transactions__r != null && !pkg.Dispense_Transactions__r.isEmpty()) {
                for (Dispense_Transaction__c txn : pkg.Dispense_Transactions__r) {
                    Map<String, Object> txnItem = new Map<String, Object>();
                    txnItem.put('id', txn.Id);
                    txnItem.put('name', txn.Name);
                    txnItem.put('dispensaryName', txn.Dispensary__r != null ? txn.Dispensary__r.Name : 'Authorized Dispensary');
                    txnItem.put('dispensaryId', txn.Dispensary__c);
                    txnItem.put('gramsDispensed', txn.Grams_Dispensed__c);
                    txnItem.put('totalAmount', txn.Total_Amount__c);
                    txnItem.put('timestamp', txn.Transaction_Timestamp__c);
                    if (txn.Patient_Registration__r != null) {
                        txnItem.put('patientRegId', txn.Patient_Registration__c);
                        txnItem.put('patientRegNumber', txn.Patient_Registration__r.Name);
                        txnItem.put('patientBarcode', txn.Patient_Registration__r.Barcode_String__c);
                        if (txn.Patient_Registration__r.Patient__r != null) {
                            txnItem.put('patientName', txn.Patient_Registration__r.Patient__r.Name);
                        }
                    }
                    txnList.add(txnItem);
                }
                latestTxn = txnList[0];
            }
            chain.put('transactions', txnList);
            chain.put('hasTransaction', !txnList.isEmpty());
            chain.put('latestTransaction', latestTxn);

            // Determine Pipeline Lifecycle Stage
            String lifecycleStage = 'Cultivation';
            if (!txnList.isEmpty() || pkg.Package_Status__c == 'Sold') {
                lifecycleStage = 'Dispensed to Patient';
            } else if (pkg.Package_Status__c == 'Ready_for_Sale') {
                lifecycleStage = 'Dispensary Retail Ready';
            } else if (latestLab != null && latestLab.get('status') == 'Passed') {
                lifecycleStage = 'Lab Certified Safe';
            } else if (pkg.Package_Status__c == 'In_Testing' || !labList.isEmpty()) {
                lifecycleStage = 'Laboratory Testing';
            } else if (pkg.Plant_Batch__r != null && pkg.Plant_Batch__r.Growth_Stage__c == 'Harvested') {
                lifecycleStage = 'Harvest & Processing';
            }
            chain.put('lifecycleStage', lifecycleStage);

            chainResults.add(chain);
        }

        return chainResults;
    }
}
