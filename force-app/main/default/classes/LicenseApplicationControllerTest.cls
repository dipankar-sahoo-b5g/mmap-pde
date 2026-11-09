/**
 * @description Comprehensive unit test suite for LicenseApplicationController and License_Application__c.
 *              Validates statutory fee calculations, application submissions, regulatory validation rules,
 *              AuraHandledException paths, and queries with >= 85% code coverage.
 */
@isTest
private class LicenseApplicationControllerTest {

    @testSetup
    static void setupTestData() {
        Account testFacility = new Account(
            Name = 'Keystone CannaTech Cultivators',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'FAC-TEST-001',
            BillingStreet = '100 Commonwealth Blvd',
            BillingCity = 'Harrisburg',
            BillingState = 'PA',
            BillingPostalCode = '17101',
            Vault_Capacity_Grams__c = 50000,
            Compliance_Status__c = 'Compliant'
        );
        insert testFacility;

        License_Application__c initialApp = new License_Application__c(
            Applicant_Facility__c = testFacility.Id,
            Application_Type__c = 'Grower/Processor',
            Status__c = 'Under Review',
            Premise_Address__c = '100 Commonwealth Blvd, Harrisburg, PA',
            Estimated_Canopy_SqFt__c = 35000,
            Application_Fee__c = 10000.00,
            Submission_Date__c = Datetime.now()
        );
        insert initialApp;
    }

    @isTest
    static void testCalculateStatutoryFeeAllTiers() {
        Test.startTest();
        Decimal growerFee = LicenseApplicationController.calculateStatutoryFee('Grower/Processor');
        Decimal dispensaryFee = LicenseApplicationController.calculateStatutoryFee('Dispensary Retail');
        Decimal labFee = LicenseApplicationController.calculateStatutoryFee('Analytical Lab');
        Decimal researchFee = LicenseApplicationController.calculateStatutoryFee('Academic Research');
        Test.stopTest();

        System.assertEquals(10000.00, growerFee, 'Grower/Processor fee must be $10,000.');
        System.assertEquals(5000.00, dispensaryFee, 'Dispensary Retail fee must be $5,000.');
        System.assertEquals(2000.00, labFee, 'Analytical Lab fee must be $2,000.');
        System.assertEquals(1000.00, researchFee, 'Academic Research fee must be $1,000.');
    }

    @isTest
    static void testCalculateStatutoryFeeInvalidAndBlank() {
        Test.startTest();
        Boolean blankCaught = false;
        try {
            LicenseApplicationController.calculateStatutoryFee('');
        } catch (IllegalArgumentException ex) {
            blankCaught = true;
        }

        Boolean invalidCaught = false;
        try {
            LicenseApplicationController.calculateStatutoryFee('NonExistentType');
        } catch (IllegalArgumentException ex) {
            invalidCaught = true;
        }
        Test.stopTest();

        System.assert(blankCaught, 'Blank application type must throw IllegalArgumentException.');
        System.assert(invalidCaught, 'Invalid application type must throw IllegalArgumentException.');
    }

    @isTest
    static void testGetFeeForTypeSuccessAndFailure() {
        Test.startTest();
        Decimal fee = LicenseApplicationController.getFeeForType('Grower/Processor');
        Boolean auraExceptionCaught = false;
        try {
            LicenseApplicationController.getFeeForType('InvalidType');
        } catch (AuraHandledException ahe) {
            auraExceptionCaught = true;
        }
        Test.stopTest();

        System.assertEquals(10000.00, fee, 'Fee for Grower/Processor should be $10,000.');
        System.assert(auraExceptionCaught, 'Invalid type should throw AuraHandledException.');
    }

    @isTest
    static void testGetFacilitiesAndGetApplications() {
        Test.startTest();
        List<Account> facilities = LicenseApplicationController.getFacilities();
        List<License_Application__c> apps = LicenseApplicationController.getApplications();
        Test.stopTest();

        System.assertNotEquals(0, facilities.size(), 'Should return facility accounts.');
        System.assertEquals('Keystone CannaTech Cultivators', facilities[0].Name, 'Facility name should match setup.');
        System.assertNotEquals(0, apps.size(), 'Should return existing applications.');
        System.assertEquals('Grower/Processor', apps[0].Application_Type__c, 'Application type should match.');
    }

    @isTest
    static void testSubmitApplicationGrowerProcessorSuccess() {
        Account fac = [SELECT Id FROM Account WHERE Name = 'Keystone CannaTech Cultivators' LIMIT 1];

        Test.startTest();
        Id appId = LicenseApplicationController.submitApplication(
            fac.Id,
            'Grower/Processor',
            '500 Industrial Pkwy, York, PA',
            45000
        );
        Test.stopTest();

        System.assertNotEquals(null, appId, 'Application ID should be returned upon success.');
        License_Application__c savedApp = [
            SELECT Id, Application_Type__c, Status__c, Application_Fee__c, Estimated_Canopy_SqFt__c, Premise_Address__c, Submission_Date__c
            FROM License_Application__c
            WHERE Id = :appId
        ];
        System.assertEquals('Grower/Processor', savedApp.Application_Type__c, 'Type must be Grower/Processor.');
        System.assertEquals('Submitted', savedApp.Status__c, 'Status must be Submitted.');
        System.assertEquals(10000.00, savedApp.Application_Fee__c, 'Statutory fee must be $10,000.00.');
        System.assertEquals(45000, savedApp.Estimated_Canopy_SqFt__c, 'Canopy square footage must match.');
        System.assertNotEquals(null, savedApp.Submission_Date__c, 'Submission timestamp should be set.');
    }

    @isTest
    static void testSubmitApplicationOtherTiersSuccess() {
        Account fac = [SELECT Id FROM Account WHERE Name = 'Keystone CannaTech Cultivators' LIMIT 1];

        Test.startTest();
        Id dispensaryAppId = LicenseApplicationController.submitApplication(
            fac.Id,
            'Dispensary Retail',
            '123 Market St, Philadelphia, PA',
            null
        );
        Id labAppId = LicenseApplicationController.submitApplication(
            fac.Id,
            'Analytical Lab',
            '456 Science Way, State College, PA',
            0
        );
        Id researchAppId = LicenseApplicationController.submitApplication(
            fac.Id,
            'Academic Research',
            '789 Campus Rd, Pittsburgh, PA',
            null
        );
        Test.stopTest();

        License_Application__c dispApp = [SELECT Application_Fee__c, Status__c FROM License_Application__c WHERE Id = :dispensaryAppId];
        License_Application__c labApp = [SELECT Application_Fee__c, Status__c FROM License_Application__c WHERE Id = :labAppId];
        License_Application__c researchApp = [SELECT Application_Fee__c, Status__c FROM License_Application__c WHERE Id = :researchAppId];

        System.assertEquals(5000.00, dispApp.Application_Fee__c, 'Dispensary fee must be $5,000.00.');
        System.assertEquals(2000.00, labApp.Application_Fee__c, 'Lab fee must be $2,000.00.');
        System.assertEquals(1000.00, researchApp.Application_Fee__c, 'Research fee must be $1,000.00.');
    }

    @isTest
    static void testSubmitApplicationValidationFailures() {
        Account fac = [SELECT Id FROM Account WHERE Name = 'Keystone CannaTech Cultivators' LIMIT 1];

        Test.startTest();
        // 1. Missing facility
        Boolean missingFacilityCaught = false;
        try {
            LicenseApplicationController.submitApplication(null, 'Grower/Processor', 'Address', 5000);
        } catch (AuraHandledException ahe) {
            missingFacilityCaught = true;
        }

        // 2. Missing appType
        Boolean missingTypeCaught = false;
        try {
            LicenseApplicationController.submitApplication(fac.Id, '', 'Address', 5000);
        } catch (AuraHandledException ahe) {
            missingTypeCaught = true;
        }

        // 3. Grower missing canopy (null)
        Boolean missingCanopyCaught = false;
        try {
            LicenseApplicationController.submitApplication(fac.Id, 'Grower/Processor', 'Address', null);
        } catch (AuraHandledException ahe) {
            missingCanopyCaught = true;
        }

        // 4. Grower zero canopy
        Boolean zeroCanopyCaught = false;
        try {
            LicenseApplicationController.submitApplication(fac.Id, 'Grower/Processor', 'Address', 0);
        } catch (AuraHandledException ahe) {
            zeroCanopyCaught = true;
        }

        // 5. Invalid type
        Boolean invalidTypeCaught = false;
        try {
            LicenseApplicationController.submitApplication(fac.Id, 'Bogus Type', 'Address', 5000);
        } catch (AuraHandledException ahe) {
            invalidTypeCaught = true;
        }

        // 6. Fake account ID triggering DmlException
        Boolean dmlHandled = false;
        try {
            Id fakeAccountId = Id.valueOf('001000000000000AAA');
            LicenseApplicationController.submitApplication(fakeAccountId, 'Dispensary Retail', '123 Fake St', null);
        } catch (AuraHandledException ahe) {
            dmlHandled = true;
        }
        Test.stopTest();

        System.assert(missingFacilityCaught, 'Null facilityId must be caught.');
        System.assert(missingTypeCaught, 'Empty appType must be caught.');
        System.assert(missingCanopyCaught, 'Null canopy for Grower/Processor must be caught.');
        System.assert(zeroCanopyCaught, 'Zero canopy for Grower/Processor must be caught.');
        System.assert(invalidTypeCaught, 'Invalid type must be caught.');
        System.assert(dmlHandled, 'Foreign key failure should trigger DmlException handled as AuraHandledException.');
    }

    @isTest
    static void testValidationRuleVR_APP_Canopy_Required_For_Grower() {
        Account fac = [SELECT Id FROM Account WHERE Name = 'Keystone CannaTech Cultivators' LIMIT 1];

        License_Application__c invalidApp = new License_Application__c(
            Applicant_Facility__c = fac.Id,
            Application_Type__c = 'Grower/Processor',
            Status__c = 'Draft',
            Premise_Address__c = '123 Cultivation Rd',
            Estimated_Canopy_SqFt__c = 0,
            Application_Fee__c = 10000.00
        );

        Test.startTest();
        Boolean dmlExceptionThrown = false;
        try {
            insert invalidApp;
        } catch (DmlException de) {
            dmlExceptionThrown = true;
            System.assert(
                de.getMessage().contains('Estimated canopy square footage is mandatory') ||
                de.getMessage().contains('VR_APP_Canopy_Required_For_Grower'),
                'Validation rule message should be present: ' + de.getMessage()
            );
        }
        Test.stopTest();

        System.assert(dmlExceptionThrown, 'Validation rule VR_APP_Canopy_Required_For_Grower must block insert when canopy is 0.');
    }
}
