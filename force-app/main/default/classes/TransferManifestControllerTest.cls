/**
 * @description Comprehensive unit test suite for TransferManifestController
 *              and TransferManifestTriggerHandler validating chain-of-custody handshakes,
 *              trigger-automated package inventory transitions, and validation rules.
 */
@isTest
private class TransferManifestControllerTest {

    @testSetup
    static void setupTestData() {
        // Origin Facility (Grower / Processor)
        Account origin = new Account(
            Name = 'Valley Green Cultivation',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'FAC-TEST-001',
            Compliance_Status__c = 'Compliant'
        );
        // Destination Facility (Dispensary)
        Account destination = new Account(
            Name = 'Capital CannaCare Dispensary',
            Facility_Type__c = 'Dispensary',
            Premise_Registry_ID__c = 'FAC-TEST-002',
            Compliance_Status__c = 'Compliant'
        );
        // Transporter Facility
        Account transporter = new Account(
            Name = 'Secure Route Logistics',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'FAC-TEST-003',
            Compliance_Status__c = 'Compliant'
        );
        insert new List<Account>{ origin, destination, transporter };

        // Strain
        Strain__c strain = new Strain__c(
            Name = 'Keystone Kush',
            Classification__c = 'Indica',
            Target_THC_Percentage__c = 22.50,
            Target_CBD_Percentage__c = 0.10,
            Is_Active__c = true
        );
        insert strain;

        // Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = origin.Id,
            Strain__c = strain.Id,
            Growth_Stage__c = 'Harvested',
            Initial_Plant_Count__c = 100,
            Current_Plant_Count__c = 100,
            Planted_Date__c = Date.today().addDays(-90),
            Harvest_Date__c = Date.today().addDays(-10),
            Wet_Weight_Grams__c = 15000,
            Dry_Weight_Grams__c = 3200,
            Room_Location__c = 'Grow Room 1'
        );
        insert batch;

        // Product Packages
        Product_Package__c pkg1 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = origin.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed',
            RFID_Tag__c = '1A4000312678900000000001'
        );
        Product_Package__c pkg2 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = origin.Id,
            Product_Type__c = 'Cannabis_Oil',
            Net_Weight_Grams__c = 1.00,
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed',
            RFID_Tag__c = '1A4000312678900000000002'
        );
        insert new List<Product_Package__c>{ pkg1, pkg2 };
    }

    @isTest
    static void testCreateManifestSuccess() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];
        Account dest = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-002' LIMIT 1];
        Account trans = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-003' LIMIT 1];
        List<Product_Package__c> pkgs = [SELECT Id FROM Product_Package__c];
        List<Id> pkgIds = new List<Id>{ pkgs[0].Id, pkgs[1].Id };

        Test.startTest();
        Transfer_Manifest__c result = TransferManifestController.createManifest(
            origin.Id,
            dest.Id,
            trans.Id,
            'Johnathan Davis',
            'PA-DL-554210',
            '1HGCR2F83HA001294',
            pkgIds
        );
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Manifest record must be inserted.');
        System.assertEquals('Draft', result.Status__c, 'Newly created manifest should be in Draft status.');
        System.assertEquals(origin.Id, result.Origin_Facility__c, 'Origin facility must match.');
        System.assertEquals(dest.Id, result.Destination_Facility__c, 'Destination facility must match.');
        System.assertEquals(2, result.Manifest_Line_Items__r.size(), 'Should have attached two line items.');
        System.assertNotEquals(null, result.Manifest_Line_Items__r[0].Gross_Weight_Grams__c, 'Gross weight must be calculated.');
    }

    @isTest
    static void testCreateManifestSameFacilityValidation() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];

        Test.startTest();
        try {
            TransferManifestController.createManifest(
                origin.Id,
                origin.Id, // Same facility
                null,
                'Johnathan Davis',
                'PA-DL-554210',
                '1HGCR2F83HA001294',
                new List<Id>()
            );
            System.assert(false, 'Should have thrown AuraHandledException for identical origin and destination.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception must be caught.');
            System.assert(
                e.getMessage().contains('Origin facility and Destination facility cannot be the same') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message must flag identical facilities: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testValidationRuleDirectInsert() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];

        Transfer_Manifest__c invalidMnf = new Transfer_Manifest__c(
            Origin_Facility__c = origin.Id,
            Destination_Facility__c = origin.Id,
            Status__c = 'Draft'
        );

        Test.startTest();
        try {
            insert invalidMnf;
            System.assert(false, 'Database insert should fail validation rule VR_MNF_Different_Facilities.');
        } catch (DmlException de) {
            System.assert(de.getMessage().contains('Origin facility and Destination facility cannot be the same'),
                'Validation rule message should be present: ' + de.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDualSignatureHandshakeAndPackageStatusTransitions() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];
        Account dest = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-002' LIMIT 1];
        Account trans = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-003' LIMIT 1];
        List<Product_Package__c> pkgs = [SELECT Id FROM Product_Package__c];
        List<Id> pkgIds = new List<Id>{ pkgs[0].Id, pkgs[1].Id };

        Transfer_Manifest__c mnf = TransferManifestController.createManifest(
            origin.Id,
            dest.Id,
            trans.Id,
            'Mark Stevens',
            'PA-DL-883921',
            '1FTRX18W1BKA99214',
            pkgIds
        );

        Test.startTest();
        // Handshake 1: Origin Dispatcher Signs Outbound
        Transfer_Manifest__c dispatched = TransferManifestController.signManifest(mnf.Id, 'Dispatcher', 'Alice Walker (Lead Dispatcher)');
        System.assertEquals('Dispatched', dispatched.Status__c, 'Manifest status must be Dispatched.');
        System.assert(dispatched.Dispatcher_Signature__c.contains('Alice Walker'), 'Dispatcher signature must be recorded.');

        // Handshake 2: Transporter Acceptance
        Transfer_Manifest__c inTransit = TransferManifestController.signManifest(mnf.Id, 'Transporter', 'Mark Stevens (Transporter)');
        System.assertEquals('In Transit', inTransit.Status__c, 'Manifest status must advance to In Transit.');
        System.assert(inTransit.Transporter_Signature__c.contains('Mark Stevens'), 'Transporter signature must be recorded.');

        // Verify Trigger executed: child packages should now be In_Transit
        List<Product_Package__c> pkgsInTransit = [SELECT Id, Status__c, Package_Status__c FROM Product_Package__c WHERE Id IN :pkgIds];
        for (Product_Package__c p : pkgsInTransit) {
            System.assertEquals('In_Transit', p.Package_Status__c, 'Package status should be In_Transit.');
            System.assertEquals('In_Transit', p.Status__c, 'Custom status should be In_Transit.');
        }

        // Handshake 3: Destination Receiver Dual-Signature Check-in
        Transfer_Manifest__c delivered = TransferManifestController.signManifest(mnf.Id, 'Receiver', 'David Cohen (Vault Manager)');
        System.assertEquals('Delivered', delivered.Status__c, 'Manifest status must advance to Delivered.');
        System.assert(delivered.Receiver_Signature__c.contains('David Cohen'), 'Receiver signature must be recorded.');
        System.assertNotEquals(null, delivered.Actual_Arrival__c, 'Actual arrival timestamp must be populated upon delivery.');
        Test.stopTest();

        // Verify Trigger executed: child packages should now be In_Stock at the Destination facility
        List<Product_Package__c> pkgsDelivered = [SELECT Id, Holding_Facility__c, Status__c, Package_Status__c FROM Product_Package__c WHERE Id IN :pkgIds];
        for (Product_Package__c p : pkgsDelivered) {
            System.assertEquals(dest.Id, p.Holding_Facility__c, 'Package holding facility must now be the destination facility.');
            System.assertEquals('In_Stock', p.Status__c, 'Custom status should be In_Stock.');
        }
    }

    @isTest
    static void testSignManifestValidationErrors() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];
        Account dest = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-002' LIMIT 1];

        Transfer_Manifest__c mnf = TransferManifestController.createManifest(
            origin.Id,
            dest.Id,
            null,
            'Test Driver',
            'PA-DL-001',
            '1VIN1234567890123',
            new List<Id>()
        );

        Test.startTest();
        // Null manifest ID
        try {
            TransferManifestController.signManifest(null, 'Dispatcher', 'John Doe');
            System.assert(false, 'Should throw exception for null manifestId.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Expected manifest ID error.');
        }

        // Blank signature name
        try {
            TransferManifestController.signManifest(mnf.Id, 'Dispatcher', '');
            System.assert(false, 'Should throw exception for blank signature.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Expected signature name error.');
        }

        // Blank role
        try {
            TransferManifestController.signManifest(mnf.Id, '', 'John Doe');
            System.assert(false, 'Should throw exception for blank role.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Expected role error.');
        }

        // Invalid role
        try {
            TransferManifestController.signManifest(mnf.Id, 'Observer', 'John Doe');
            System.assert(false, 'Should throw exception for invalid role.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Expected invalid role error.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetManifestsAndDetails() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];
        Account dest = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-002' LIMIT 1];
        List<Product_Package__c> pkgs = [SELECT Id FROM Product_Package__c];

        Transfer_Manifest__c mnf = TransferManifestController.createManifest(
            origin.Id,
            dest.Id,
            null,
            'Driver Test',
            'DL-12345',
            'VIN12345678901234',
            new List<Id>{ pkgs[0].Id }
        );

        Test.startTest();
        List<Transfer_Manifest__c> listResults = TransferManifestController.getManifests();
        System.assertNotEquals(0, listResults.size(), 'getManifests should return records.');

        Transfer_Manifest__c details = TransferManifestController.getManifestDetails(mnf.Id);
        System.assertEquals(mnf.Id, details.Id, 'Manifest details should match created manifest.');
        System.assertEquals(1, details.Manifest_Line_Items__r.size(), 'Should return line items.');

        List<Account> facilities = TransferManifestController.getFacilities();
        System.assertNotEquals(0, facilities.size(), 'Facilities list should not be empty.');

        List<Product_Package__c> availablePkgs = TransferManifestController.getAvailablePackages(origin.Id);
        System.assertNotEquals(0, availablePkgs.size(), 'Available packages should not be empty.');

        List<Product_Package__c> emptyPkgs = TransferManifestController.getAvailablePackages(null);
        System.assertEquals(0, emptyPkgs.size(), 'Null facility should return empty list.');

        try {
            TransferManifestController.getManifestDetails(null);
            System.assert(false, 'Should throw exception for null manifestId.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Expected null manifestId error.');
        }
        Test.stopTest();
    }

    @isTest
    static void testBulkTriggerProcessing() {
        Account origin = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-001' LIMIT 1];
        Account dest = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-002' LIMIT 1];

        List<Transfer_Manifest__c> manifests = new List<Transfer_Manifest__c>();
        for (Integer i = 0; i < 10; i++) {
            manifests.add(new Transfer_Manifest__c(
                Origin_Facility__c = origin.Id,
                Destination_Facility__c = dest.Id,
                Status__c = 'Draft',
                Driver_Name__c = 'Bulk Driver ' + i
            ));
        }
        insert manifests;

        Test.startTest();
        for (Transfer_Manifest__c m : manifests) {
            m.Status__c = 'In Transit';
        }
        update manifests;

        for (Transfer_Manifest__c m : manifests) {
            m.Status__c = 'Delivered';
        }
        update manifests;
        Test.stopTest();

        List<Transfer_Manifest__c> deliveredManifests = [SELECT Id, Status__c, Actual_Arrival__c FROM Transfer_Manifest__c WHERE Id IN :manifests];
        for (Transfer_Manifest__c m : deliveredManifests) {
            System.assertEquals('Delivered', m.Status__c, 'Status must be Delivered.');
            System.assertNotEquals(null, m.Actual_Arrival__c, 'Actual_Arrival__c should be auto-set by before-update trigger.');
        }
    }

    /**
     * @description Validates defensive null handling in TransferManifestTriggerHandler.
     */
    @isTest
    static void testTransferManifestTriggerHandlerDefensive() {
        Test.startTest();
        TransferManifestTriggerHandler.handleBeforeUpdate(null, null);
        TransferManifestTriggerHandler.handleAfterUpdate(null, null);
        TransferManifestTriggerHandler.handleAfterUpdate(new List<Transfer_Manifest__c>(), new Map<Id, Transfer_Manifest__c>());
        System.assert(true, 'Defensive null handlers executed without exception.');
        Test.stopTest();
    }
}
