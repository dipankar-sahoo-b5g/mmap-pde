/**
 * @description Comprehensive unit tests for RegistryMockRestService.
 *              Validates direct patient eligibility, caregiver linkage, inactive caregiver handling,
 *              expired patient handling, not-found scenarios, and automated audit logging to Registry_Check__c.
 *              Target Coverage: >= 90%.
 * @author Dipankar Sahoo
 */
@IsTest
private class RegistryMockRestServiceTest {

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

        // 5. Revoked Caregiver linked to active patient
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
    static void testDirectPatientQuery_Success() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/PA-PAT-77201';
        req.httpMethod = 'GET';
        RestContext.request = req;

        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.doGet();
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('200', resp.statusCode, 'Status code should be 200');
        System.assertEquals('Active', resp.status, 'Certification should be Active');
        System.assertEquals('PA-PAT-77201', resp.patientId, 'Patient ID mismatch');
        System.assertEquals('Robert Stauffer', resp.patientName, 'Patient Name mismatch');
        System.assertEquals(192.00, resp.allowanceMMU, 'Allowance MMU mismatch');
        System.assertEquals(140.00, resp.consumedMMU, 'Consumed MMU mismatch');
        System.assertEquals(52.00, resp.remainingMMU, 'Remaining MMU mismatch');

        // Verify Audit Log insertion (TR009)
        List<Registry_Check__c> logs = [
            SELECT Id, Patient_Ref__c, Caregiver_Ref__c, Certification_Status__c,
                   Practitioner_Limits__c, Response_Code__c, MMU_Remaining__c
            FROM Registry_Check__c
            WHERE Patient_Ref__r.Registry_ID__c = 'PA-PAT-77201'
        ];
        System.assertEquals(1, logs.size(), 'Audit record should have been inserted');
        System.assertEquals('200 OK', logs[0].Response_Code__c, 'Response code in audit log mismatch');
        System.assertEquals(52.00, logs[0].MMU_Remaining__c, 'Remaining balance in audit log mismatch');
    }

    @IsTest
    static void testCaregiverQuery_Success() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/PA-CG-99104';
        req.httpMethod = 'GET';
        RestContext.request = req;

        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.doGet();
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('200', resp.statusCode, 'Status code should be 200');
        System.assertEquals('PA-CG-99104', resp.caregiverId, 'Caregiver ID mismatch');
        System.assertEquals('Linda Stauffer', resp.caregiverName, 'Caregiver Name mismatch');
        System.assertEquals('PA-PAT-77201', resp.patientId, 'Patient ID mismatch');
        System.assertEquals('Robert Stauffer', resp.patientName, 'Patient Name mismatch');
        System.assertEquals(52.00, resp.remainingMMU, 'Remaining MMU should be 52');

        // Verify Audit Log has both Patient and Caregiver linked
        List<Registry_Check__c> logs = [
            SELECT Id, Patient_Ref__c, Caregiver_Ref__c, Response_Code__c
            FROM Registry_Check__c
            WHERE Caregiver_Ref__r.Registry_ID__c = 'PA-CG-99104'
        ];
        System.assertEquals(1, logs.size(), 'Caregiver audit record should be logged');
        System.assertNotEquals(null, logs[0].Patient_Ref__c, 'Patient lookup should be populated');
        System.assertEquals('200 OK', logs[0].Response_Code__c, 'Response code should be 200 OK');
    }

    @IsTest
    static void testUnlinkedCaregiver_Fails() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/PA-CG-00000';
        req.httpMethod = 'GET';
        RestContext.request = req;

        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.doGet();
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('400', resp.statusCode, 'Unlinked caregiver should return 400');
        System.assertEquals('Unlinked Caregiver', resp.status, 'Status mismatch');

        // Verify audit log captured unlinked attempt
        List<Registry_Check__c> logs = [
            SELECT Id, Response_Code__c
            FROM Registry_Check__c
            WHERE Caregiver_Ref__r.Registry_ID__c = 'PA-CG-00000'
        ];
        System.assertEquals(1, logs.size(), 'Audit log should record unlinked caregiver inquiry');
        System.assert(logs[0].Response_Code__c.contains('ELIG-02'), 'Audit code should reflect ELIG-02');
    }

    @IsTest
    static void testInactiveCaregiver_Fails() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/PA-CG-REVOKED';
        req.httpMethod = 'GET';
        RestContext.request = req;

        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.doGet();
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('400', resp.statusCode, 'Revoked caregiver should return 400');
        System.assertEquals('Caregiver Ineligible', resp.status, 'Status should be Caregiver Ineligible');

        // Verify audit log captured inactive caregiver attempt (ELIG-03)
        List<Registry_Check__c> logs = [
            SELECT Id, Response_Code__c, Certification_Status__c
            FROM Registry_Check__c
            WHERE Caregiver_Ref__r.Registry_ID__c = 'PA-CG-REVOKED'
        ];
        System.assertEquals(1, logs.size(), 'Audit record should be logged for revoked caregiver');
        System.assert(logs[0].Response_Code__c.contains('ELIG-03'), 'Response code should contain ELIG-03');
    }

    @IsTest
    static void testExpiredPatient_Fails() {
        Test.startTest();
        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.verifyRegistryId('PA-PAT-EXPIRED');
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('400', resp.statusCode, 'Expired patient should return 400');
        System.assertEquals('Expired', resp.status, 'Status should be Expired');

        List<Registry_Check__c> logs = [
            SELECT Id, Response_Code__c, Certification_Status__c
            FROM Registry_Check__c
            WHERE Patient_Ref__r.Registry_ID__c = 'PA-PAT-EXPIRED'
        ];
        System.assertEquals(1, logs.size(), 'Audit record should be logged for expired patient');
        System.assertEquals('Expired', logs[0].Certification_Status__c, 'Status in audit log mismatch');
    }

    @IsTest
    static void testNotFound_Fails() {
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/UNKNOWN-99999';
        req.httpMethod = 'GET';
        RestContext.request = req;

        RegistryMockRestService.RegistryResponse resp = RegistryMockRestService.doGet();
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertEquals('404', resp.statusCode, 'Non-existent ID should return 404');

        // Verify audit log captured not found attempt
        List<Registry_Check__c> logs = [
            SELECT Id, Response_Code__c
            FROM Registry_Check__c
            WHERE Response_Code__c = '404 NOT_FOUND'
        ];
        System.assertEquals(1, logs.size(), 'Audit log should record 404 lookup');
    }

    @IsTest
    static void testInvalidRequestUris() {
        Test.startTest();
        // Null request
        RestContext.request = null;
        RegistryMockRestService.RegistryResponse respNull = RegistryMockRestService.doGet();
        System.assertEquals('400', respNull.statusCode, 'Null request should return 400');

        // Empty ID
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/registry/check/';
        RestContext.request = req;
        RegistryMockRestService.RegistryResponse respEmpty = RegistryMockRestService.doGet();
        System.assertEquals('400', respEmpty.statusCode, 'Empty ID should return 400');

        // Direct method call with blank string
        RegistryMockRestService.RegistryResponse respBlank = RegistryMockRestService.verifyRegistryId('');
        System.assertEquals('400', respBlank.statusCode, 'Blank registry ID should return 400');
        Test.stopTest();
    }
}
