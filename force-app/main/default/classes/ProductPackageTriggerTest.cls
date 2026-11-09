/**
 * @description Comprehensive unit test suite for ProductPackageTrigger,
 *              ProductPackageTriggerHandler, RFIDGeneratorService, and VR_PKG_RFID_Length.
 */
@isTest
private class ProductPackageTriggerTest {

    @TestSetup
    static void setupTestData() {
        // Create test facility Account
        Account facility = new Account(
            Name = 'Alpha Cultivation Facility',
            Premise_Registry_ID__c = 'FAC-TEST-0001',
            Facility_Type__c = 'Grower_Processor',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 250000.00
        );
        insert facility;

        // Create test Cannabis Strain
        Strain__c strain = new Strain__c(
            Name = 'Blueberry Kush Test',
            Classification__c = 'Indica',
            Target_THC_Percentage__c = 21.50,
            Target_CBD_Percentage__c = 0.80,
            Is_Active__c = true
        );
        insert strain;

        // Create test Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = facility.Id,
            Strain__c = strain.Id,
            Planted_Date__c = Date.today().addDays(-45),
            Growth_Stage__c = 'Flowering',
            Initial_Plant_Count__c = 100,
            Current_Plant_Count__c = 98,
            Room_Location__c = 'Bay 1'
        );
        insert batch;
    }

    /**
     * @description Scenario 1: Positive Auto-Generation Test
     *              When a package is inserted without an RFID tag, status, or safety status:
     *              - 24-character RFID tag is auto-assigned
     *              - Tag begins with Commonwealth state prefix '1A4000312678'
     *              - Package_Status__c defaults to 'In_Testing'
     *              - Lab_Safety_Status__c defaults to 'Untested'
     */
    @isTest
    static void testPositiveAutoGeneration() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-0001' LIMIT 1];
        Plant_Batch__c batch = [SELECT Id FROM Plant_Batch__c LIMIT 1];

        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = facility.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 45.00,
            RFID_Tag__c = null,
            Package_Status__c = null,
            Lab_Safety_Status__c = null
        );

        Test.startTest();
        insert pkg;
        Test.stopTest();

        Product_Package__c insertedPkg = [
            SELECT Id, RFID_Tag__c, Package_Status__c, Lab_Safety_Status__c 
            FROM Product_Package__c 
            WHERE Id = :pkg.Id
        ];

        System.assertNotEquals(null, insertedPkg.RFID_Tag__c, 'RFID tag should be automatically populated.');
        System.assertEquals(24, insertedPkg.RFID_Tag__c.length(), 'RFID tag must be exactly 24 characters.');
        System.assert(insertedPkg.RFID_Tag__c.startsWith('1A4000312678'), 'RFID tag must begin with state prefix 1A4000312678.');
        System.assertEquals('In_Testing', insertedPkg.Package_Status__c, 'Package status should default to In_Testing.');
        System.assertEquals('Untested', insertedPkg.Lab_Safety_Status__c, 'Lab safety status should default to Untested.');
    }

    /**
     * @description Scenario 2: Preservation of Custom RFID Test
     *              When a package is inserted with an existing valid 24-char RFID tag:
     *              - Existing tag is preserved unchanged.
     */
    @isTest
    static void testPreservationOfCustomRFID() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-0001' LIMIT 1];
        Plant_Batch__c batch = [SELECT Id FROM Plant_Batch__c LIMIT 1];

        String manualTag = '1A4000312678A1B2C3D4E5F6';

        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = facility.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Cannabis_Oil',
            Net_Weight_Grams__c = 10.00,
            Unit_Price__c = 75.00,
            RFID_Tag__c = manualTag,
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed'
        );

        Test.startTest();
        insert pkg;
        Test.stopTest();

        Product_Package__c insertedPkg = [
            SELECT Id, RFID_Tag__c, Package_Status__c, Lab_Safety_Status__c 
            FROM Product_Package__c 
            WHERE Id = :pkg.Id
        ];

        System.assertEquals(manualTag, insertedPkg.RFID_Tag__c, 'Manual RFID tag should be preserved without overwrite.');
        System.assertEquals('Ready_for_Sale', insertedPkg.Package_Status__c, 'Manual package status should be preserved.');
        System.assertEquals('Passed', insertedPkg.Lab_Safety_Status__c, 'Manual lab safety status should be preserved.');
    }

    /**
     * @description Scenario 3: Validation Rule Test
     *              When a package is inserted with an invalid RFID length (!= 24 chars),
     *              VR_PKG_RFID_Length must reject the record with DMLException.
     */
    @isTest
    static void testValidationRuleInvalidRFIDLength() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-0001' LIMIT 1];
        Plant_Batch__c batch = [SELECT Id FROM Plant_Batch__c LIMIT 1];

        // 20-character invalid RFID
        String invalidShortTag = '1A400031267812345678';

        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = facility.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Edible',
            Net_Weight_Grams__c = 100.00,
            Unit_Price__c = 30.00,
            RFID_Tag__c = invalidShortTag
        );

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            insert pkg;
        } catch (DmlException ex) {
            exceptionThrown = true;
            System.assert(
                ex.getMessage().contains('RFID tracking tag must be exactly 24 characters in length') ||
                ex.getMessage().contains('VR_PKG_RFID_Length'),
                'Exception message should reference VR_PKG_RFID_Length validation rule: ' + ex.getMessage()
            );
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected DmlException due to VR_PKG_RFID_Length violation.');
    }

    /**
     * @description Scenario 4: Bulk Ingestion Test (200 records)
     *              Validates bulk performance, 0 governor limit failures, and that all 200
     *              packages receive strictly unique 24-character tags.
     */
    @isTest
    static void testBulk200PackagesAutoGeneration() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'FAC-TEST-0001' LIMIT 1];
        Plant_Batch__c batch = [SELECT Id FROM Plant_Batch__c LIMIT 1];

        List<Product_Package__c> bulkList = new List<Product_Package__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkList.add(new Product_Package__c(
                Holding_Facility__c = facility.Id,
                Plant_Batch__c = batch.Id,
                Product_Type__c = 'Usable_Marijuana_Flower',
                Net_Weight_Grams__c = 1.00,
                Unit_Price__c = 20.00,
                Package_Status__c = null,
                Lab_Safety_Status__c = null
            ));
        }

        Test.startTest();
        insert bulkList;
        Test.stopTest();

        List<Product_Package__c> insertedList = [
            SELECT Id, RFID_Tag__c, Package_Status__c, Lab_Safety_Status__c 
            FROM Product_Package__c 
            WHERE Id IN :bulkList
        ];

        System.assertEquals(200, insertedList.size(), 'All 200 bulk packages should be inserted.');

        Set<String> uniqueTags = new Set<String>();
        for (Product_Package__c pkg : insertedList) {
            System.assertNotEquals(null, pkg.RFID_Tag__c, 'RFID tag must not be null.');
            System.assertEquals(24, pkg.RFID_Tag__c.length(), 'RFID tag must be 24 characters.');
            System.assert(pkg.RFID_Tag__c.startsWith('1A4000312678'), 'RFID tag must begin with state prefix.');
            System.assertEquals('In_Testing', pkg.Package_Status__c, 'Bulk package status should default to In_Testing.');
            System.assertEquals('Untested', pkg.Lab_Safety_Status__c, 'Bulk lab safety status should default to Untested.');
            uniqueTags.add(pkg.RFID_Tag__c);
        }

        System.assertEquals(200, uniqueTags.size(), 'All 200 generated RFID tags must be completely unique.');
    }

    /**
     * @description Scenario 5: Direct RFIDGeneratorService Unit Test
     *              Validates standalone service methods and edge-case parameter handling.
     */
    @isTest
    static void testRFIDGeneratorServiceDirectMethods() {
        Test.startTest();
        String singleTag = RFIDGeneratorService.generateTag();
        List<String> tenTags = RFIDGeneratorService.generateTags(10);
        List<String> zeroTags = RFIDGeneratorService.generateTags(0);
        List<String> negativeTags = RFIDGeneratorService.generateTags(-5);
        List<String> nullTags = RFIDGeneratorService.generateTags(null);
        Test.stopTest();

        // Validate single tag
        System.assertNotEquals(null, singleTag);
        System.assertEquals(24, singleTag.length());
        System.assert(singleTag.startsWith('1A4000312678'));

        // Validate 10 tags
        System.assertEquals(10, tenTags.size());
        Set<String> tagSet = new Set<String>(tenTags);
        System.assertEquals(10, tagSet.size(), 'All 10 generated tags should be distinct.');

        // Validate edge cases
        System.assertEquals(0, zeroTags.size());
        System.assertEquals(0, negativeTags.size());
        System.assertEquals(0, nullTags.size());

        // Validate handler defensive handling
        ProductPackageTriggerHandler.handleBeforeInsert(null);
        ProductPackageTriggerHandler.handleBeforeInsert(new List<Product_Package__c>());
    }
}
