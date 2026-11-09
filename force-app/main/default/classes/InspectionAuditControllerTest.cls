/**
 * @description Comprehensive unit test suite for InspectionAuditController and QuarantineService
 *              validating automated grade calculations, validation rules, emergency stop-sale
 *              quarantine enactments, package lockdowns, and quarantine rescissions.
 */
@isTest
private class InspectionAuditControllerTest {

    @testSetup
    static void setupTestData() {
        // Regulated Facility
        Account facility = new Account(
            Name = 'Keystone Testing Cultivators',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'PR-TEST-AUDIT-01',
            Compliance_Status__c = 'Compliant'
        );
        insert facility;

        // Regulatory Inspector
        Contact inspector = new Contact(
            FirstName = 'Dale',
            LastName = 'Cooper',
            Stakeholder_Role__c = 'Facility_Agent',
            Email = 'dale.cooper@regulatory.state.gov'
        );
        insert inspector;

        // Cannabis Strain
        Strain__c strain = new Strain__c(
            Name = 'Blueberry Muffin',
            Classification__c = 'Hybrid',
            Target_THC_Percentage__c = 21.00,
            Target_CBD_Percentage__c = 0.20,
            Is_Active__c = true
        );
        insert strain;

        // Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = facility.Id,
            Strain__c = strain.Id,
            Growth_Stage__c = 'Harvested',
            Initial_Plant_Count__c = 80,
            Current_Plant_Count__c = 80,
            Planted_Date__c = Date.today().addDays(-100),
            Harvest_Date__c = Date.today().addDays(-15),
            Wet_Weight_Grams__c = 12000,
            Dry_Weight_Grams__c = 2800,
            Room_Location__c = 'Flowering Bay 1'
        );
        insert batch;

        // Product Packages held at facility
        Product_Package__c pkg1 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = facility.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed',
            RFID_Tag__c = '1A4000312678900000000101'
        );
        Product_Package__c pkg2 = new Product_Package__c(
            Plant_Batch__c = batch.Id,
            Holding_Facility__c = facility.Id,
            Product_Type__c = 'Concentrate',
            Net_Weight_Grams__c = 1.00,
            Package_Status__c = 'Ready_for_Sale',
            Lab_Safety_Status__c = 'Passed',
            RFID_Tag__c = '1A4000312678900000000102'
        );
        insert new List<Product_Package__c>{ pkg1, pkg2 };
    }

    @isTest
    static void testCreatePassingAuditWithFindings() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];
        Contact inspector = [SELECT Id FROM Contact WHERE LastName = 'Cooper' LIMIT 1];

        List<Audit_Finding__c> findings = new List<Audit_Finding__c>{
            new Audit_Finding__c(
                Finding_Category__c = 'Vault Scale Calibration',
                Severity__c = 'Minor',
                Statutory_Fine_Amount__c = 250.00,
                Corrective_Action_Plan__c = 'Re-calibrate scale model A-20 within 48 hours.',
                Resolved__c = false
            ),
            new Audit_Finding__c(
                Finding_Category__c = 'Sanitation & Hygiene',
                Severity__c = 'Minor',
                Statutory_Fine_Amount__c = 150.00,
                Corrective_Action_Plan__c = 'Install additional handwashing placards.',
                Resolved__c = true
            )
        };

        Test.startTest();
        Inspection_Audit__c createdAudit = InspectionAuditController.createAudit(
            facility.Id,
            inspector.Id,
            'Annual Routine',
            Date.today(),
            92,
            'Facility demonstrates strong statutory compliance with minor equipment calibration advisories.',
            findings
        );
        Test.stopTest();

        System.assertNotEquals(null, createdAudit.Id, 'Audit should have been successfully created.');
        System.assertEquals('Pass', createdAudit.Compliance_Grade__c, 'Score of 92 must receive a Pass grade.');
        System.assertEquals('Completed', createdAudit.Status__c, 'Scored audit should transition to Completed.');
        System.assertEquals(false, createdAudit.Stop_Sale_Enacted__c, 'Passing audit should not have stop-sale enacted.');

        // Verify child findings attached
        List<Audit_Finding__c> savedFindings = [
            SELECT Id, Finding_Category__c, Severity__c, Statutory_Fine_Amount__c, Resolved__c
            FROM Audit_Finding__c
            WHERE Inspection_Audit__c = :createdAudit.Id
        ];
        System.assertEquals(2, savedFindings.size(), 'Should have inserted 2 child findings.');
    }

    @isTest
    static void testCreateConditionalPassAudit() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Test.startTest();
        Inspection_Audit__c audit = InspectionAuditController.createAudit(
            facility.Id,
            null,
            'Follow-Up Re-Inspection',
            Date.today(),
            78,
            'Conditional pass due to unlogged visitor logs and partial camera blind spots.',
            new List<Audit_Finding__c>()
        );
        Test.stopTest();

        System.assertEquals('Conditional Pass', audit.Compliance_Grade__c, 'Score between 70 and 84 must receive Conditional Pass.');
    }

    @isTest
    static void testCreateFailedAudit() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Test.startTest();
        Inspection_Audit__c audit = InspectionAuditController.createAudit(
            facility.Id,
            null,
            'Unannounced Compliance',
            Date.today(),
            58,
            'Severe infractions detected regarding pesticide storage and product inventory discrepancies.',
            null
        );
        Test.stopTest();

        System.assertEquals('Failed - Immediate Revocation', audit.Compliance_Grade__c, 'Score < 70 must receive Failed grade.');
    }

    @isTest
    static void testValidationRuleScoreNegative() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Inspection_Audit__c audit = new Inspection_Audit__c(
            Facility__c = facility.Id,
            Inspection_Type__c = 'Annual Routine',
            Inspection_Date__c = Date.today(),
            Audit_Score__c = -5
        );

        Test.startTest();
        try {
            insert audit;
            System.assert(false, 'Expected validation rule VR_AUDIT_Valid_Score to fail for negative score.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Inspection Audit Score must be between 0 and 100'), 
                'Validation error message should match expected VR message. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testValidationRuleScoreOver100() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Inspection_Audit__c audit = new Inspection_Audit__c(
            Facility__c = facility.Id,
            Inspection_Type__c = 'Annual Routine',
            Inspection_Date__c = Date.today(),
            Audit_Score__c = 105
        );

        Test.startTest();
        try {
            insert audit;
            System.assert(false, 'Expected validation rule VR_AUDIT_Valid_Score to fail for score > 100.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Inspection Audit Score must be between 0 and 100'), 
                'Validation error message should match expected VR message. Actual: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAuditRequiredFieldValidations() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Test.startTest();
        try {
            InspectionAuditController.createAudit(null, null, 'Annual Routine', Date.today(), 90, 'Test', null);
            System.assert(false, 'Should throw exception on null facilityId');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception for null facility');
        }

        try {
            InspectionAuditController.createAudit(facility.Id, null, '', Date.today(), 90, 'Test', null);
            System.assert(false, 'Should throw exception on blank auditType');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception for blank auditType');
        }

        try {
            InspectionAuditController.createAudit(facility.Id, null, 'Annual Routine', null, 90, 'Test', null);
            System.assert(false, 'Should throw exception on null auditDate');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception for null auditDate');
        }
        Test.stopTest();
    }

    @isTest
    static void testEnactEmergencyQuarantineAndLockdown() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];
        Contact inspector = [SELECT Id FROM Contact WHERE LastName = 'Cooper' LIMIT 1];

        // Create failing audit with critical violations
        List<Audit_Finding__c> findings = new List<Audit_Finding__c>{
            new Audit_Finding__c(
                Finding_Category__c = 'Pesticide / Chemical Storage',
                Severity__c = 'Critical Violation',
                Statutory_Fine_Amount__c = 15000.00,
                Corrective_Action_Plan__c = 'Immediate quarantine of contaminated grow bay.',
                Resolved__c = false
            )
        };

        Inspection_Audit__c audit = InspectionAuditController.createAudit(
            facility.Id,
            inspector.Id,
            'Adverse Event Investigation',
            Date.today(),
            45,
            'Emergency pesticide hazard cited. Immediate stop-sale ordered.',
            findings
        );

        Test.startTest();
        Integer quarantinedPackages = InspectionAuditController.enactStopSale(
            audit.Id,
            'Unapproved synthetic pesticide detected in packaging area. Statewide stop-sale enforced.'
        );
        Test.stopTest();

        System.assertEquals(2, quarantinedPackages, 'Both inventory packages at the facility must be quarantined.');

        // Verify Inspection_Audit__c status
        Inspection_Audit__c reloadedAudit = [
            SELECT Status__c, Stop_Sale_Enacted__c, Stop_Sale_Timestamp__c, Summary_Findings__c
            FROM Inspection_Audit__c
            WHERE Id = :audit.Id
        ];
        System.assertEquals('Quarantine Enacted', reloadedAudit.Status__c, 'Audit status must be Quarantine Enacted.');
        System.assertEquals(true, reloadedAudit.Stop_Sale_Enacted__c, 'Stop-sale flag must be true.');
        System.assertNotEquals(null, reloadedAudit.Stop_Sale_Timestamp__c, 'Stop-sale timestamp must be set.');
        System.assert(reloadedAudit.Summary_Findings__c.contains('EMERGENCY STOP-SALE ORDER ENACTED'), 'Summary should record stop-sale rationale.');

        // Verify Account Compliance Status
        Account reloadedFacility = [
            SELECT Compliance_Status__c
            FROM Account
            WHERE Id = :facility.Id
        ];
        System.assertEquals('Suspended', reloadedFacility.Compliance_Status__c, 'Facility compliance standing must be Suspended.');

        // Verify Product Packages
        List<Product_Package__c> packages = [
            SELECT Status__c, Package_Status__c, Lab_Safety_Status__c
            FROM Product_Package__c
            WHERE Holding_Facility__c = :facility.Id
        ];
        for (Product_Package__c p : packages) {
            System.assertEquals('Quarantined', p.Status__c, 'Package Status__c must be Quarantined.');
            System.assertEquals('Quarantined', p.Package_Status__c, 'Package Package_Status__c must be Quarantined.');
            System.assertEquals('Failed', p.Lab_Safety_Status__c, 'Package Lab_Safety_Status__c must be Failed.');
        }
    }

    @isTest
    static void testLiftQuarantine() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];

        Inspection_Audit__c audit = InspectionAuditController.createAudit(
            facility.Id,
            null,
            'Unannounced Compliance',
            Date.today(),
            40,
            'Initial failed audit.',
            null
        );

        // Enact Quarantine
        InspectionAuditController.enactStopSale(audit.Id, 'Initial contamination issue.');

        Test.startTest();
        Boolean liftSuccess = InspectionAuditController.liftStopSale(
            audit.Id,
            'Independent lab re-testing verified no residual pesticides. Corrective actions inspected.'
        );
        Test.stopTest();

        System.assertEquals(true, liftSuccess, 'Quarantine lift must return true.');

        // Verify Audit restored
        Inspection_Audit__c reloadedAudit = [
            SELECT Status__c, Stop_Sale_Enacted__c, Summary_Findings__c
            FROM Inspection_Audit__c
            WHERE Id = :audit.Id
        ];
        System.assertEquals('Completed', reloadedAudit.Status__c, 'Audit status must revert to Completed.');
        System.assertEquals(false, reloadedAudit.Stop_Sale_Enacted__c, 'Stop-sale flag must revert to false.');
        System.assert(reloadedAudit.Summary_Findings__c.contains('QUARANTINE ORDER RESCINDED/LIFTED'), 'Summary notes must document lift.');

        // Verify Facility restored
        Account reloadedFacility = [
            SELECT Compliance_Status__c
            FROM Account
            WHERE Id = :facility.Id
        ];
        System.assertEquals('Compliant', reloadedFacility.Compliance_Status__c, 'Facility compliance status must revert to Compliant.');
    }

    @isTest
    static void testAuditQueriesAndMetrics() {
        Account facility = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-TEST-AUDIT-01' LIMIT 1];
        Contact inspector = [SELECT Id FROM Contact WHERE LastName = 'Cooper' LIMIT 1];

        List<Audit_Finding__c> findings = new List<Audit_Finding__c>{
            new Audit_Finding__c(
                Finding_Category__c = 'Security & Surveillance',
                Severity__c = 'Critical Violation',
                Statutory_Fine_Amount__c = 5000.00,
                Corrective_Action_Plan__c = 'Restore camera blindspots at bay 4.',
                Resolved__c = false
            ),
            new Audit_Finding__c(
                Finding_Category__c = 'Vault Scale Calibration',
                Severity__c = 'Major',
                Statutory_Fine_Amount__c = 1000.00,
                Corrective_Action_Plan__c = 'Calibrate scale #3.',
                Resolved__c = true
            )
        };

        Inspection_Audit__c audit = InspectionAuditController.createAudit(
            facility.Id,
            inspector.Id,
            'Annual Routine',
            Date.today(),
            72,
            'General audit notes.',
            findings
        );

        Test.startTest();
        List<Inspection_Audit__c> audits = InspectionAuditController.getAudits();
        InspectionAuditController.AuditSummaryWrapper details = InspectionAuditController.getAuditDetails(audit.Id);
        List<Account> facilities = InspectionAuditController.getFacilities();
        List<Contact> inspectors = InspectionAuditController.getInspectors();
        Test.stopTest();

        System.assert(!audits.isEmpty(), 'getAudits must return records.');
        System.assertNotEquals(null, details, 'getAuditDetails must return wrapper.');
        System.assertEquals(2, details.totalFindings, 'Total findings count should match.');
        System.assertEquals(1, details.criticalFindings, 'Critical findings count should match.');
        System.assertEquals(1, details.unresolvedFindings, 'Unresolved findings count should match.');
        System.assertEquals(6000.00, details.totalFinesAssessed, 'Total fines assessed should equal $6,000.00.');
        System.assert(!facilities.isEmpty(), 'getFacilities must return facilities.');
        System.assert(!inspectors.isEmpty(), 'getInspectors must return inspectors.');
    }

    @isTest
    static void testQuarantineErrorScenarios() {
        Test.startTest();
        // Null audit ID for enact
        try {
            InspectionAuditController.enactStopSale(null, 'Reason');
            System.assert(false, 'Should throw exception for null auditId on enact.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception on enactStopSale');
        }

        // Null audit ID for lift
        try {
            InspectionAuditController.liftStopSale(null, 'Reason');
            System.assert(false, 'Should throw exception for null auditId on lift.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception on liftStopSale');
        }

        // Null audit ID for getAuditDetails
        try {
            InspectionAuditController.getAuditDetails(null);
            System.assert(false, 'Should throw exception for null auditId on getAuditDetails.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception on getAuditDetails');
        }
        Test.stopTest();
    }

    /**
     * @description Validates QuarantineService direct edge cases (null ID, non-existent ID, missing facility).
     */
    @isTest
    static void testQuarantineServiceDirectExceptions() {
        Test.startTest();

        // 1. Enact with null ID
        try {
            QuarantineService.enactEmergencyQuarantine(null, 'Test');
            System.assert(false, 'Should throw exception on null ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 2. Enact with non-existent ID
        Inspection_Audit__c dummy = new Inspection_Audit__c();
        Id fakeId = dummy.Id;
        // Generate a fake Id using standard prefix
        Schema.DescribeSObjectResult r = Inspection_Audit__c.sObjectType.getDescribe();
        String fakeAuditId = r.getKeyPrefix() + '000000000001AAA';
        try {
            QuarantineService.enactEmergencyQuarantine(fakeAuditId, 'Test');
            System.assert(false, 'Should throw exception on non-existent ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 3. Lift with null ID
        try {
            QuarantineService.liftQuarantine(null, 'Test');
            System.assert(false, 'Should throw exception on null ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 4. Lift with non-existent ID
        try {
            QuarantineService.liftQuarantine(fakeAuditId, 'Test');
            System.assert(false, 'Should throw exception on non-existent ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Test.stopTest();
    }
}
