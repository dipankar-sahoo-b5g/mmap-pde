/**
 * @description Unit tests for SupplyChainExplorerController
 *              Validates aggregate metrics retrieval and end-to-end traceability chain queries.
 */
@isTest
private class SupplyChainExplorerControllerTest {

    @testSetup
    static void setupTestData() {
        // Facilities
        Account cultivator = new Account(
            Name = 'Keystone Cultivation Labs',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'FAC-TEST-GP-001',
            Compliance_Status__c = 'Compliant'
        );
        Account lab = new Account(
            Name = 'Keystone Testing Labs',
            Facility_Type__c = 'Testing_Laboratory',
            Premise_Registry_ID__c = 'FAC-TEST-TL-002',
            Compliance_Status__c = 'Compliant'
        );
        Account dispensary = new Account(
            Name = 'Keystone Dispensary Hub',
            Facility_Type__c = 'Dispensary',
            Premise_Registry_ID__c = 'FAC-TEST-DP-003',
            Compliance_Status__c = 'Compliant'
        );
        insert new List<Account>{ cultivator, lab, dispensary };

        // License
        Business_License__c license = new Business_License__c(
            Facility__c = cultivator.Id,
            License_Number__c = 'GP-TEST-2026-001',
            License_Tier__c = 'Standard_Commercial',
            Issue_Date__c = Date.today().addMonths(-6),
            Expiration_Date__c = Date.today().addMonths(6),
            Status__c = 'Active'
        );
        insert license;

        // Contacts
        Contact physician = new Contact(
            LastName = 'Dr. Test Physician',
            AccountId = dispensary.Id,
            Stakeholder_Role__c = 'Physician',
            Medical_License_No__c = 'MD-TEST-9999'
        );
        Contact patient = new Contact(
            LastName = 'Test Patient Smith',
            AccountId = dispensary.Id,
            Stakeholder_Role__c = 'Patient'
        );
        insert new List<Contact>{ physician, patient };

        // Patient Registration
        Patient_Registration__c patientReg = new Patient_Registration__c(
            Patient__c = patient.Id,
            Certifying_Physician__c = physician.Id,
            Barcode_String__c = 'PA-TEST-BARCODE-999',
            Thirty_Day_Limit_Grams__c = 90.00,
            Certification_Date__c = Date.today().addMonths(-2),
            Expiration_Date__c = Date.today().addMonths(10)
        );
        insert patientReg;

        // Strain
        Strain__c strain = new Strain__c(
            Name = 'Keystone Haze',
            Classification__c = 'Sativa',
            Target_THC_Percentage__c = 22.50,
            Target_CBD_Percentage__c = 0.25,
            Is_Active__c = true
        );
        insert strain;

        // Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = cultivator.Id,
            Strain__c = strain.Id,
            Growth_Stage__c = 'Harvested',
            Initial_Plant_Count__c = 100,
            Current_Plant_Count__c = 95,
            Room_Location__c = 'Harvest Bay A',
            Planted_Date__c = Date.today().addMonths(-3),
            Harvest_Date__c = Date.today().addDays(-7),
            Wet_Weight_Grams__c = 8500.00,
            Dry_Weight_Grams__c = 2100.00
        );
        insert batch;

        // Product Package 1 (Fully dispensed with lab results)
        Product_Package__c pkg1 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = dispensary.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 45.00,
            RFID_Tag__c = '1A4000312678AA9988112233',
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed'
        );

        // Product Package 2 (In testing)
        Product_Package__c pkg2 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = cultivator.Id,
            Product_Type__c = 'Cannabis_Oil',
            Net_Weight_Grams__c = 1.00,
            Unit_Price__c = 55.00,
            RFID_Tag__c = '1A4000312678BB7766554433',
            Package_Status__c = 'In_Testing',
            Lab_Safety_Status__c = 'Untested'
        );
        insert new List<Product_Package__c>{ pkg1, pkg2 };

        // Lab Test Result for Package 1
        Lab_Test_Result__c labTest = new Lab_Test_Result__c(
            Product_Package__c = pkg1.Id,
            Testing_Laboratory__c = lab.Id,
            Test_Date__c = Date.today().addDays(-3),
            THC_Potency_Pct__c = 22.10,
            CBD_Potency_Pct__c = 0.30,
            Pesticides_Pass__c = true,
            Heavy_Metals_Pass__c = true,
            Mycotoxins_Pass__c = true,
            Residual_Solvents_Pass__c = true,
            Overall_Status__c = 'Passed'
        );
        insert labTest;

        // Dispense Transaction for Package 1
        Dispense_Transaction__c txn = new Dispense_Transaction__c(
            Patient_Registration__c = patientReg.Id,
            Dispensary__c = dispensary.Id,
            Product_Package__c = pkg1.Id,
            Grams_Dispensed__c = 3.50,
            Total_Amount__c = 45.00,
            Transaction_Timestamp__c = DateTime.now()
        );
        insert txn;
    }

    @isTest
    static void testGetProgramMetrics() {
        Test.startTest();
        Map<String, Integer> metrics = SupplyChainExplorerController.getProgramMetrics();
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Metrics map should not be null');
        System.assert(metrics.containsKey('facilities'), 'Should contain facilities count');
        System.assert(metrics.containsKey('licenses'), 'Should contain licenses count');
        System.assert(metrics.containsKey('patients'), 'Should contain patients count');
        System.assert(metrics.containsKey('strains'), 'Should contain strains count');
        System.assert(metrics.containsKey('batches'), 'Should contain batches count');
        System.assert(metrics.containsKey('packages'), 'Should contain packages count');
        System.assert(metrics.containsKey('coas'), 'Should contain coas count');
        System.assert(metrics.containsKey('transactions'), 'Should contain transactions count');

        System.assert(metrics.get('facilities') >= 3, 'Expected at least 3 facilities');
        System.assert(metrics.get('licenses') >= 1, 'Expected at least 1 license');
        System.assert(metrics.get('patients') >= 1, 'Expected at least 1 patient');
        System.assert(metrics.get('strains') >= 1, 'Expected at least 1 strain');
        System.assert(metrics.get('batches') >= 1, 'Expected at least 1 batch');
        System.assert(metrics.get('packages') >= 2, 'Expected at least 2 packages');
        System.assert(metrics.get('coas') >= 1, 'Expected at least 1 COA');
        System.assert(metrics.get('transactions') >= 1, 'Expected at least 1 transaction');
    }

    @isTest
    static void testGetTraceabilityChains() {
        Test.startTest();
        List<Map<String, Object>> chains = SupplyChainExplorerController.getTraceabilityChains();
        Test.stopTest();

        System.assertNotEquals(null, chains, 'Chains list should not be null');
        System.assert(chains.size() >= 2, 'Should return at least 2 packages');

        Boolean foundDispensed = false;
        Boolean foundInTesting = false;

        for (Map<String, Object> chain : chains) {
            System.assert(chain.containsKey('packageRecord'), 'Chain must contain packageRecord');
            System.assert(chain.containsKey('holdingFacility'), 'Chain must contain holdingFacility');
            System.assert(chain.containsKey('batchRecord'), 'Chain must contain batchRecord');
            System.assert(chain.containsKey('strainRecord'), 'Chain must contain strainRecord');
            System.assert(chain.containsKey('cultivatorRecord'), 'Chain must contain cultivatorRecord');
            System.assert(chain.containsKey('lifecycleStage'), 'Chain must contain lifecycleStage');

            String stage = (String) chain.get('lifecycleStage');
            if (stage == 'Dispensed to Patient') {
                foundDispensed = true;
                System.assertEquals(true, chain.get('hasTransaction'), 'Dispensed package should have transaction');
                System.assertEquals(true, chain.get('hasLabTest'), 'Dispensed package should have lab test');
                Map<String, Object> latestLab = (Map<String, Object>) chain.get('latestLabTest');
                System.assertEquals('Passed', latestLab.get('status'), 'COA status should be Passed');
            } else if (stage == 'Laboratory Testing') {
                foundInTesting = true;
                System.assertEquals(false, chain.get('hasTransaction'), 'In-testing package should not have transaction');
            }
        }

        System.assert(foundDispensed, 'Should identify dispensed chain in dataset');
        System.assert(foundInTesting, 'Should identify testing chain in dataset');
    }
}
