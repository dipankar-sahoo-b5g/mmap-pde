/**
 * @description Comprehensive unit test suite for DispenseTransactionTrigger,
 *              DispenseTransactionTriggerHandler, PurchaseLimitService,
 *              and Validation Rule VR_PKG_COA_Must_Pass.
 */
@isTest
private class DispenseTransactionTriggerTest {

    @TestSetup
    static void setupTestData() {
        // Create Dispensary Account
        Account dispensary = new Account(
            Name = 'Keystone Dispensary West',
            Premise_Registry_ID__c = 'DISP-TEST-9001',
            Facility_Type__c = 'Dispensary',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 100000.00
        );
        insert dispensary;

        // Create Cultivator Account
        Account grower = new Account(
            Name = 'Keystone Cultivation Facility',
            Premise_Registry_ID__c = 'GROW-TEST-9001',
            Facility_Type__c = 'Grower_Processor',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 500000.00
        );
        insert grower;

        // Create Cannabis Strain
        Strain__c strain = new Strain__c(
            Name = 'Sour Diesel Test',
            Classification__c = 'Sativa',
            Target_THC_Percentage__c = 22.50,
            Target_CBD_Percentage__c = 0.50,
            Is_Active__c = true
        );
        insert strain;

        // Create Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = grower.Id,
            Strain__c = strain.Id,
            Planted_Date__c = Date.today().addDays(-60),
            Harvest_Date__c = Date.today().addDays(-15),
            Growth_Stage__c = 'Harvested',
            Initial_Plant_Count__c = 50,
            Current_Plant_Count__c = 48,
            Dry_Weight_Grams__c = 1250.00,
            Room_Location__c = 'Curing Room 1'
        );
        insert batch;

        // Create Physician Contact
        Contact physician = new Contact(
            FirstName = 'Marcus',
            LastName = 'Welby',
            Stakeholder_Role__c = 'Physician',
            Medical_License_No__c = 'MD-PA-449102'
        );
        insert physician;

        // Create Active Patient Contact
        Contact activePatientContact = new Contact(
            FirstName = 'Alice',
            LastName = 'Walker',
            Stakeholder_Role__c = 'Patient',
            State_ID_Number__c = 'DL-PA-482910'
        );
        insert activePatientContact;

        // Create Expired Patient Contact
        Contact expiredPatientContact = new Contact(
            FirstName = 'Bob',
            LastName = 'Expired',
            Stakeholder_Role__c = 'Patient',
            State_ID_Number__c = 'DL-PA-991122'
        );
        insert expiredPatientContact;

        // Create Active Patient Registration (90g quota)
        Patient_Registration__c activeReg = new Patient_Registration__c(
            Patient__c = activePatientContact.Id,
            Certifying_Physician__c = physician.Id,
            Barcode_String__c = 'PA-BARCODE-ACT-001',
            Thirty_Day_Limit_Grams__c = 90.00,
            Certification_Date__c = Date.today().addDays(-30),
            Expiration_Date__c = Date.today().addDays(335)
        );
        insert activeReg;

        // Create Inactive/Expired Patient Registration
        Patient_Registration__c expiredReg = new Patient_Registration__c(
            Patient__c = expiredPatientContact.Id,
            Certifying_Physician__c = physician.Id,
            Barcode_String__c = 'PA-BARCODE-EXP-002',
            Thirty_Day_Limit_Grams__c = 90.00,
            Certification_Date__c = Date.today().addDays(-400),
            Expiration_Date__c = Date.today().addDays(-35)
        );
        insert expiredReg;

        // Create Product Package (RFID auto-assigned by ProductPackageTrigger)
        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = dispensary.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 45.00
        );
        insert pkg;
    }

    /**
     * @description Scenario 1: Positive Sale Within Quota
     *              Dispensing 30g to a patient with a 90g quota succeeds.
     */
    @isTest
    static void testPositiveSaleWithinQuota() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        Dispense_Transaction__c txn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 30.00,
            Total_Amount__c = 135.00
        );

        Test.startTest();
        insert txn;
        Test.stopTest();

        System.assertNotEquals(null, txn.Id, 'Dispense transaction should insert successfully.');
        Decimal usage = PurchaseLimitService.getRolling30DayUsage(activeReg.Id);
        System.assertEquals(30.00, usage, 'Rolling 30-day usage should reflect exactly 30.00 grams.');
    }

    /**
     * @description Scenario 2: Negative Sale Exceeding Quota
     *              Patient already purchased 70g in the last 30 days.
     *              Attempting to purchase 30g more (70g + 30g = 100g > 90g) must fail.
     *              Error message must state: "Transaction Rejected: Patient has 20.00 grams remaining in their rolling 30-day quota."
     */
    @isTest
    static void testNegativeSaleExceedingQuota() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        // Seed 70g purchase 5 days ago
        Dispense_Transaction__c priorTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 70.00,
            Total_Amount__c = 315.00,
            Transaction_Timestamp__c = Datetime.now().addDays(-5)
        );
        insert priorTxn;

        // Attempt second transaction for 30g (exceeds 90g limit)
        Dispense_Transaction__c excessTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 30.00,
            Total_Amount__c = 135.00
        );

        Test.startTest();
        try {
            insert excessTxn;
            System.assert(false, 'Transaction exceeding rolling 30-day quota must throw DmlException.');
        } catch (DmlException ex) {
            String expectedMsg = 'Transaction Rejected: Patient has 20.00 grams remaining in their rolling 30-day quota.';
            System.assert(ex.getMessage().contains(expectedMsg),
                'Expected error message containing: [' + expectedMsg + '], got: [' + ex.getMessage() + ']');
        }
        Test.stopTest();
    }

    /**
     * @description Scenario 3: Negative Inactive / Expired Patient Card
     *              Attempting a transaction for an expired patient card must be rejected.
     */
    @isTest
    static void testNegativeInactivePatientCard() {
        Patient_Registration__c expiredReg = [SELECT Id, Is_Active__c FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-EXP-002' LIMIT 1];
        System.assertEquals(false, expiredReg.Is_Active__c, 'Expired registration Is_Active__c formula must evaluate to false.');

        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        Dispense_Transaction__c txn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = expiredReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 10.00,
            Total_Amount__c = 50.00
        );

        Test.startTest();
        try {
            insert txn;
            System.assert(false, 'Transaction for expired patient must throw DmlException.');
        } catch (DmlException ex) {
            String expectedMsg = 'Transaction Rejected: Patient registration is inactive or expired.';
            System.assert(ex.getMessage().contains(expectedMsg),
                'Expected error message containing: [' + expectedMsg + '], got: [' + ex.getMessage() + ']');
        }
        Test.stopTest();
    }

    /**
     * @description Scenario 4: Batch State Maintenance Test
     *              Two transactions for the same patient in a single insert list:
     *              - First transaction is 50g (valid, consumes 50g of 90g quota).
     *              - Second transaction is 50g (exceeds remaining 40g quota).
     *              Asserts first succeeds, second fails with 40.00 grams remaining.
     */
    @isTest
    static void testBatchStateTrackingSamePatient() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        Dispense_Transaction__c tx1 = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 50.00,
            Total_Amount__c = 225.00
        );

        Dispense_Transaction__c tx2 = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 50.00,
            Total_Amount__c = 225.00
        );

        Test.startTest();
        Database.SaveResult[] results = Database.insert(new List<Dispense_Transaction__c>{tx1, tx2}, false);
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(), 'First transaction within quota must succeed.');
        System.assertEquals(false, results[1].isSuccess(), 'Second transaction exceeding batch quota must fail.');

        String errorMsg = results[1].getErrors()[0].getMessage();
        String expectedRemaining = 'Transaction Rejected: Patient has 40.00 grams remaining in their rolling 30-day quota.';
        System.assert(errorMsg.contains(expectedRemaining),
            'Expected remaining quota error of 40.00g, got: ' + errorMsg);
    }

    /**
     * @description Scenario 5: Validation Rule VR_PKG_COA_Must_Pass
     *              - Updating package to Ready_for_Sale with Untested lab status fails.
     *              - Updating package to Ready_for_Sale with Passed lab status succeeds.
     */
    @isTest
    static void testValidationRuleCOAMustPass() {
        Product_Package__c pkg = [SELECT Id, Package_Status__c, Lab_Safety_Status__c FROM Product_Package__c LIMIT 1];
        System.assertEquals('Untested', pkg.Lab_Safety_Status__c, 'Initial lab status should be Untested.');

        // 1. Attempt to set Ready_for_Sale while Untested -> Must fail VR_PKG_COA_Must_Pass
        pkg.Package_Status__c = 'Ready_for_Sale';
        try {
            update pkg;
            System.assert(false, 'Validation rule VR_PKG_COA_Must_Pass should block Ready_for_Sale when Untested.');
        } catch (DmlException ex) {
            String expectedMsg = 'Packages cannot be marked Ready for Sale until the laboratory safety status is Passed.';
            System.assert(ex.getMessage().contains(expectedMsg),
                'Expected COA gatekeeper error message, got: ' + ex.getMessage());
        }

        // 2. Set Lab_Safety_Status__c to Passed and Package_Status__c to Ready_for_Sale -> Must succeed
        pkg.Lab_Safety_Status__c = 'Passed';
        pkg.Package_Status__c = 'Ready_for_Sale';
        Test.startTest();
        update pkg;
        Test.stopTest();

        Product_Package__c verifiedPkg = [SELECT Id, Package_Status__c, Lab_Safety_Status__c FROM Product_Package__c WHERE Id = :pkg.Id];
        System.assertEquals('Ready_for_Sale', verifiedPkg.Package_Status__c, 'Package status should now be Ready_for_Sale.');
        System.assertEquals('Passed', verifiedPkg.Lab_Safety_Status__c, 'Lab safety status should now be Passed.');
    }

    /**
     * @description Scenario 6: 30-Day Rolling Window Cutoff Test
     *              Transactions older than 30 days must not count towards active quota.
     */
    @isTest
    static void testRolling30DayWindowCutoff() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        // Transaction completed 35 days ago (outside 30-day rolling window)
        Dispense_Transaction__c expiredWindowTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 70.00,
            Total_Amount__c = 300.00,
            Transaction_Timestamp__c = Datetime.now().addDays(-35)
        );
        insert expiredWindowTxn;

        // Current rolling usage must be 0.00
        Decimal rollingUsage = PurchaseLimitService.getRolling30DayUsage(activeReg.Id);
        System.assertEquals(0.00, rollingUsage, '35-day old transaction should not be included in 30-day rolling usage.');

        // Current transaction for 80.00g should succeed because rolling usage is 0.00 (80 <= 90)
        Dispense_Transaction__c newTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 80.00,
            Total_Amount__c = 360.00
        );

        Test.startTest();
        insert newTxn;
        Test.stopTest();

        Decimal updatedUsage = PurchaseLimitService.getRolling30DayUsage(activeReg.Id);
        System.assertEquals(80.00, updatedUsage, 'Only the recent transaction should count towards the 30-day total.');
    }

    /**
     * @description Scenario 7: Bulk Processing (200 Transactions)
     *              Verifies trigger and service bulkification with 200 transactions.
     */
    @isTest
    static void testBulkDispenseTransactions() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        List<Dispense_Transaction__c> bulkList = new List<Dispense_Transaction__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkList.add(new Dispense_Transaction__c(
                Dispensary__c = dispensary.Id,
                Patient_Registration__c = activeReg.Id,
                Product_Package__c = pkg.Id,
                Grams_Dispensed__c = 0.20, // 200 * 0.20 = 40.00g total (well within 90g limit)
                Total_Amount__c = 5.00
            ));
        }

        Test.startTest();
        insert bulkList;
        Test.stopTest();

        Decimal finalUsage = PurchaseLimitService.getRolling30DayUsage(activeReg.Id);
        System.assertEquals(40.00, finalUsage, 'Bulk 200 transactions should sum exactly to 40.00 grams.');
    }

    /**
     * @description Scenario 8: Edge Cases and Custom Exception Coverage
     */
    @isTest
    static void testEdgeCasesAndException() {
        Patient_Registration__c activeReg = [SELECT Id FROM Patient_Registration__c WHERE Barcode_String__c = 'PA-BARCODE-ACT-001' LIMIT 1];
        Account dispensary = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'DISP-TEST-9001' LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];

        // Null parameter safety checks
        PurchaseLimitService.validateTransactionLimits(null);
        PurchaseLimitService.validateTransactionLimits(new List<Dispense_Transaction__c>());
        DispenseTransactionTriggerHandler.handleBeforeInsert(null);
        DispenseTransactionTriggerHandler.handleBeforeInsert(new List<Dispense_Transaction__c>());

        Decimal nullUsage = PurchaseLimitService.getRolling30DayUsage(null);
        System.assertEquals(0.00, nullUsage, 'Null patient registration should return 0.00.');

        // 1. Transaction with null patient registration
        Dispense_Transaction__c nullPatientTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 10.00
        );
        PurchaseLimitService.validateTransactionLimits(new List<Dispense_Transaction__c>{nullPatientTxn});

        // 2. Transaction with a non-existent patient ID
        String prefix = Patient_Registration__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakePatientId = (Id) (prefix + '000000000001');
        Dispense_Transaction__c fakePatientTxn = new Dispense_Transaction__c(
            Patient_Registration__c = fakePatientId,
            Grams_Dispensed__c = 5.00
        );
        PurchaseLimitService.validateTransactionLimits(new List<Dispense_Transaction__c>{nullPatientTxn, fakePatientTxn});

        // 3. Insert an existing transaction (within 90g limit) and test existingTxIds exclusion
        Dispense_Transaction__c existingTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 60.00,
            Total_Amount__c = 250.00,
            Transaction_Timestamp__c = Datetime.now().addDays(-1)
        );
        insert existingTxn;

        // Call validateTransactionLimits with existingTxn having Id != null to test exclusion
        PurchaseLimitService.validateTransactionLimits(new List<Dispense_Transaction__c>{existingTxn});

        // 4. Reduce patient quota to 50g so current usage (60g) exceeds limit, testing remainingGrams < 0
        activeReg.Thirty_Day_Limit_Grams__c = 50.00;
        update activeReg;

        Dispense_Transaction__c negativeRemainingTxn = new Dispense_Transaction__c(
            Dispensary__c = dispensary.Id,
            Patient_Registration__c = activeReg.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 5.00
        );
        PurchaseLimitService.validateTransactionLimits(new List<Dispense_Transaction__c>{negativeRemainingTxn});

        // Instantiate custom exception
        PurchaseLimitService.LimitExceededException ex = new PurchaseLimitService.LimitExceededException('Quota exceeded test.');
        System.assertEquals('Quota exceeded test.', ex.getMessage(), 'Exception message should match.');
    }
}
