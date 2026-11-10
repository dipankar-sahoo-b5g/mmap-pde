/**
 * @description Unit tests for RegistryServiceCallout Invocable Action.
 *              Validates Flow request processing, eligibility evaluation, and MMU balance reporting.
 *              Target Coverage: >= 90%.
 * @author Dipankar Sahoo
 */
@IsTest
private class RegistryServiceCalloutTest {

    @TestSetup
    static void setupTestData() {
        // 1. Certified Active Patient: Robert Stauffer
        Patient_Ref__c robert = new Patient_Ref__c(
            Name = 'Robert Stauffer',
            Registry_ID__c = 'PA-PAT-77201',
            Person_Type__c = 'Patient',
            Certification_Status__c = 'Active',
            Certification_Expiry__c = Date.today().addYears(1),
            Address__c = '123 Penn Ave, Harrisburg, PA 17101',
            Practitioner_Limits__c = 'No whole flower; vape cartridges and tinctures only',
            MMU_Allowance__c = 192.00,
            MMU_Used_90_Days__c = 140.00
        );
        insert robert;

        // 2. Linked Active Caregiver: Linda Stauffer
        Patient_Ref__c linda = new Patient_Ref__c(
            Name = 'Linda Stauffer',
            Registry_ID__c = 'PA-CG-99104',
            Person_Type__c = 'Caregiver',
            Certification_Status__c = 'Active',
            Certification_Expiry__c = Date.today().addYears(1),
            Address__c = '123 Penn Ave, Harrisburg, PA 17101',
            Linked_Patient__c = robert.Id
        );
        insert linda;

        // 3. Unlinked Caregiver
        Patient_Ref__c unlinked = new Patient_Ref__c(
            Name = 'Unlinked Caregiver',
            Registry_ID__c = 'PA-CG-00000',
            Person_Type__c = 'Caregiver',
            Certification_Status__c = 'Active',
            Certification_Expiry__c = Date.today().addYears(1)
        );
        insert unlinked;

        // 4. Expired Patient
        Patient_Ref__c expiredPat = new Patient_Ref__c(
            Name = 'Expired Patient',
            Registry_ID__c = 'PA-PAT-EXPIRED',
            Person_Type__c = 'Patient',
            Certification_Status__c = 'Expired',
            Certification_Expiry__c = Date.today().addDays(-10),
            Practitioner_Limits__c = 'None',
            MMU_Allowance__c = 192.00,
            MMU_Used_90_Days__c = 0.00
        );
        insert expiredPat;

        // 5. Revoked Caregiver
        Patient_Ref__c revokedCg = new Patient_Ref__c(
            Name = 'Revoked Caregiver',
            Registry_ID__c = 'PA-CG-REVOKED',
            Person_Type__c = 'Caregiver',
            Certification_Status__c = 'Revoked',
            Certification_Expiry__c = Date.today().addYears(1),
            Linked_Patient__c = robert.Id
        );
        insert revokedCg;
    }

    @IsTest
    static void testVerifyEligibility_ActivePatient() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'PA-PAT-77201';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(true, res.isEligible, 'Active patient must be marked eligible');
        System.assertEquals('200', res.statusCode, 'Status code should be 200');
        System.assertEquals('Active', res.status, 'Certification status should be Active');
        System.assertEquals('Robert Stauffer', res.patientName, 'Patient Name mismatch');
        System.assertEquals('PA-PAT-77201', res.patientId, 'Patient ID mismatch');
        System.assertEquals(52.00, res.remainingMMU, 'Remaining balance should be 52 MMUs');
        System.assertNotEquals(null, res.registryCheckId, 'Audit check log ID should be populated');
    }

    @IsTest
    static void testVerifyEligibility_ActiveCaregiver() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'PA-CG-99104';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(true, res.isEligible, 'Linked active caregiver must be marked eligible');
        System.assertEquals('PA-CG-99104', res.caregiverId, 'Caregiver ID mismatch');
        System.assertEquals('Linda Stauffer', res.caregiverName, 'Caregiver Name mismatch');
        System.assertEquals('Robert Stauffer', res.patientName, 'Patient Name mismatch');
        System.assertEquals(52.00, res.remainingMMU, 'Remaining balance should be 52 MMUs');
    }

    @IsTest
    static void testVerifyEligibility_UnlinkedCaregiver() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'PA-CG-00000';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(false, res.isEligible, 'Unlinked caregiver must not be eligible');
        System.assertEquals('400', res.statusCode, 'Status code should be 400');
        System.assertEquals('Unlinked Caregiver', res.status, 'Status mismatch');
    }

    @IsTest
    static void testVerifyEligibility_ExpiredPatient() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'PA-PAT-EXPIRED';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(false, res.isEligible, 'Expired patient must not be eligible');
        System.assertEquals('Expired', res.status, 'Status should be Expired');
    }

    @IsTest
    static void testVerifyEligibility_RevokedCaregiver() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'PA-CG-REVOKED';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(false, res.isEligible, 'Revoked caregiver must not be eligible');
        System.assertEquals('Caregiver Ineligible', res.status, 'Status mismatch');
    }

    @IsTest
    static void testVerifyEligibility_NotFound() {
        RegistryServiceCallout.RegistryRequest req = new RegistryServiceCallout.RegistryRequest();
        req.registryId = 'UNKNOWN-00000';

        Test.startTest();
        List<RegistryServiceCallout.RegistryResult> results = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one result expected');
        RegistryServiceCallout.RegistryResult res = results[0];
        System.assertEquals(false, res.isEligible, 'Non-existent ID must not be eligible');
        System.assertEquals('404', res.statusCode, 'Status code should be 404');
    }

    @IsTest
    static void testVerifyEligibility_EmptyAndNullRequests() {
        Test.startTest();
        // Null list
        List<RegistryServiceCallout.RegistryResult> resNull = RegistryServiceCallout.verifyEligibility(null);
        System.assertEquals(0, resNull.size(), 'Null request list should return empty result list');

        // Empty list
        List<RegistryServiceCallout.RegistryResult> resEmpty = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>()
        );
        System.assertEquals(0, resEmpty.size(), 'Empty request list should return empty result list');

        // Request with null registryId
        RegistryServiceCallout.RegistryRequest reqBlank = new RegistryServiceCallout.RegistryRequest();
        reqBlank.registryId = '';
        List<RegistryServiceCallout.RegistryResult> resBlank = RegistryServiceCallout.verifyEligibility(
            new List<RegistryServiceCallout.RegistryRequest>{ reqBlank }
        );
        System.assertEquals(1, resBlank.size(), 'Blank request should return single result');
        System.assertEquals(false, resBlank[0].isEligible, 'Blank request should not be eligible');
        System.assertEquals('400', resBlank[0].statusCode, 'Blank request should return 400');
        Test.stopTest();
    }
}

