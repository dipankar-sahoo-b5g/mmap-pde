/**
 * @description Comprehensive unit test suite for PatientPortalController.
 *              Validates digital patient card retrieval, 30-day quota metrics,
 *              physician certification workflow, validation rules, and error handling.
 */
@isTest
private class PatientPortalControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Dispensary Account for dispensing
        Account dispensary = new Account(
            Name = 'Healing Leaves Dispensary - Downtown',
            Premise_Registry_ID__c = 'DISP-PA-001',
            Facility_Type__c = 'Dispensary',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 50000.00
        );
        insert dispensary;

        // Create Cultivator Account
        Account grower = new Account(
            Name = 'Green Thumb Cultivation',
            Premise_Registry_ID__c = 'GROW-PA-001',
            Facility_Type__c = 'Grower_Processor',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 250000.00
        );
        insert grower;

        // Create Strain
        Strain__c strain = new Strain__c(
            Name = 'Blue Dream Test',
            Classification__c = 'Hybrid',
            Target_THC_Percentage__c = 21.50,
            Target_CBD_Percentage__c = 0.10,
            Is_Active__c = true
        );
        insert strain;

        // Create Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = grower.Id,
            Strain__c = strain.Id,
            Planted_Date__c = Date.today().addDays(-90),
            Harvest_Date__c = Date.today().addDays(-20),
            Growth_Stage__c = 'Harvested',
            Initial_Plant_Count__c = 100,
            Current_Plant_Count__c = 98,
            Dry_Weight_Grams__c = 5000.00,
            Room_Location__c = 'Bay 1'
        );
        insert batch;

        // Create Package
        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = dispensary.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 45.00
        );
        insert pkg;

        // Create Doctor Contact
        Contact doctor = new Contact(
            FirstName = 'Rachel',
            LastName = 'Chen',
            Stakeholder_Role__c = 'Physician',
            Medical_License_No__c = 'MD-98214-PA',
            Email = 'dr.rachel.chen@health.pa.gov'
        );
        insert doctor;

        // Create Patient Contacts
        Contact patient1 = new Contact(
            FirstName = 'Sarah',
            LastName = 'Jenkins',
            Stakeholder_Role__c = 'Patient',
            State_ID_Number__c = 'PA-DL-84920194',
            Email = 'sarah.jenkins@example.com'
        );
        Contact patient2 = new Contact(
            FirstName = 'Michael',
            LastName = 'Torres',
            Stakeholder_Role__c = 'Patient',
            State_ID_Number__c = 'PA-DL-99210481',
            Email = 'michael.torres@example.com'
        );
        insert new List<Contact>{ patient1, patient2 };

        // Create Patient Registration for Sarah
        Patient_Registration__c regSarah = new Patient_Registration__c(
            Patient__c = patient1.Id,
            Certifying_Physician__c = doctor.Id,
            Barcode_String__c = 'PA-MED-84920194',
            Thirty_Day_Limit_Grams__c = 90.00,
            Certification_Date__c = Date.today().addDays(-10),
            Expiration_Date__c = Date.today().addDays(355)
        );
        insert regSarah;

        // Dispense 10 grams to Sarah
        Dispense_Transaction__c tx = new Dispense_Transaction__c(
            Patient_Registration__c = regSarah.Id,
            Dispensary__c = dispensary.Id,
            Product_Package__c = pkg.Id,
            Grams_Dispensed__c = 10.00,
            Transaction_Timestamp__c = DateTime.now().addDays(-2),
            Total_Amount__c = 120.00
        );
        insert tx;
    }

    @isTest
    static void testGetPatientsAndPhysicians() {
        Test.startTest();
        List<Contact> patients = PatientPortalController.getPatients();
        List<Contact> physicians = PatientPortalController.getPhysicians();
        Test.stopTest();

        System.assertNotEquals(null, patients, 'Patients list should not be null');
        System.assert(patients.size() >= 2, 'Should retrieve at least 2 patients');
        System.assertNotEquals(null, physicians, 'Physicians list should not be null');
        System.assert(physicians.size() >= 1, 'Should retrieve at least 1 physician');
    }

    @isTest
    static void testSubmitCertificationSuccess() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' AND LastName = 'Jenkins' LIMIT 1];

        Date issueDate = Date.today();
        Date expirationDate = Date.today().addDays(180);

        Test.startTest();
        Physician_Certification__c cert = PatientPortalController.submitCertification(
            patient.Id,
            doctor.Id,
            'Chronic Pain',
            3.50,
            issueDate,
            expirationDate,
            'Patient exhibits neuropathic chronic pain symptoms. Standard daily dose indicated.'
        );
        Test.stopTest();

        System.assertNotEquals(null, cert.Id, 'Certification record ID should not be null');
        System.assertEquals('Active', cert.Status__c, 'Certification status should be Active');
        System.assertNotEquals(null, cert.Doctor_Digital_Signature_Timestamp__c, 'Digital signature timestamp must be populated');

        // Verify queried from database
        Physician_Certification__c queried = [
            SELECT Id, Patient__c, Certifying_Physician__c, Qualifying_Condition_ICD10__c,
                   Recommended_Daily_Dose_Grams__c, Issue_Date__c, Expiration_Date__c, Status__c
            FROM Physician_Certification__c
            WHERE Id = :cert.Id
        ];
        System.assertEquals(patient.Id, queried.Patient__c, 'Patient ID must match');
        System.assertEquals(doctor.Id, queried.Certifying_Physician__c, 'Physician ID must match');
        System.assertEquals('Chronic Pain', queried.Qualifying_Condition_ICD10__c, 'Condition must match');
        System.assertEquals(3.50, queried.Recommended_Daily_Dose_Grams__c, 'Daily dose must match');
        System.assertEquals('Active', queried.Status__c, 'Status must be Active');
    }

    @isTest
    static void testSubmitCertificationDefaultDates() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' AND LastName = 'Torres' LIMIT 1];

        Test.startTest();
        Physician_Certification__c cert = PatientPortalController.submitCertification(
            patient.Id,
            doctor.Id,
            'PTSD',
            2.00,
            null,
            null,
            'Default dates test.'
        );
        Test.stopTest();

        System.assertNotEquals(null, cert.Id, 'Certification should insert with default dates');
        Physician_Certification__c queried = [SELECT Issue_Date__c, Expiration_Date__c FROM Physician_Certification__c WHERE Id = :cert.Id];
        System.assertEquals(Date.today(), queried.Issue_Date__c, 'Issue date should default to today');
        System.assertEquals(Date.today().addDays(365), queried.Expiration_Date__c, 'Expiration date should default to +365 days');
    }

    @isTest
    static void testValidationRuleExceeds365Days() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' LIMIT 1];

        Date issueDate = Date.today();
        Date invalidExpDate = Date.today().addDays(366);

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            PatientPortalController.submitCertification(
                patient.Id,
                doctor.Id,
                'Epilepsy',
                4.00,
                issueDate,
                invalidExpDate,
                'Should fail due to statutory duration exceeding 12 months.'
            );
        } catch (AuraHandledException ex) {
            exceptionCaught = true;
            System.assert(ex.getMessage().contains('12 months') || ex.getMessage().contains('Script-thrown exception'), 'Exception message should reflect duration validation');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionCaught, 'Validation rule VR_CERT_Valid_Duration must fire for expiration > issueDate + 365');
    }

    @isTest
    static void testValidationRuleExpirationBeforeIssueDate() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' LIMIT 1];

        Date issueDate = Date.today();
        Date invalidExpDate = Date.today().addDays(-5);

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            PatientPortalController.submitCertification(
                patient.Id,
                doctor.Id,
                'Glaucoma',
                1.50,
                issueDate,
                invalidExpDate,
                'Should fail due to expiration <= issue date.'
            );
        } catch (AuraHandledException ex) {
            exceptionCaught = true;
            System.assert(ex.getMessage().contains('after the issue date') || ex.getMessage().contains('Script-thrown exception'), 'Exception message should reflect duration validation');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionCaught, 'Validation rule VR_CERT_Valid_Duration must fire for expiration <= issueDate');
    }

    @isTest
    static void testSubmitCertificationMissingParams() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' LIMIT 1];

        Test.startTest();
        Boolean patientNullCaught = false;
        try {
            PatientPortalController.submitCertification(null, doctor.Id, 'Cancer', 2.00, Date.today(), Date.today().addDays(90), 'Notes');
        } catch (AuraHandledException ex) {
            patientNullCaught = true;
        }
        System.assertEquals(true, patientNullCaught, 'Should reject null patient');

        Boolean doctorNullCaught = false;
        try {
            PatientPortalController.submitCertification(patient.Id, null, 'Cancer', 2.00, Date.today(), Date.today().addDays(90), 'Notes');
        } catch (AuraHandledException ex) {
            doctorNullCaught = true;
        }
        System.assertEquals(true, doctorNullCaught, 'Should reject null doctor');

        Boolean conditionBlankCaught = false;
        try {
            PatientPortalController.submitCertification(patient.Id, doctor.Id, '', 2.00, Date.today(), Date.today().addDays(90), 'Notes');
        } catch (AuraHandledException ex) {
            conditionBlankCaught = true;
        }
        System.assertEquals(true, conditionBlankCaught, 'Should reject empty condition');
        Test.stopTest();
    }

    @isTest
    static void testGetCertifications() {
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
        Contact patient = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Patient' AND LastName = 'Jenkins' LIMIT 1];

        PatientPortalController.submitCertification(
            patient.Id,
            doctor.Id,
            'Multiple Sclerosis',
            2.50,
            Date.today(),
            Date.today().addDays(300),
            'Diagnosis confirmed by neurology panel.'
        );

        Test.startTest();
        List<Physician_Certification__c> certs = PatientPortalController.getCertifications();
        Test.stopTest();

        System.assertNotEquals(null, certs, 'Certifications list should not be null');
        System.assert(certs.size() >= 1, 'Should return at least 1 certification');
        System.assertEquals('Multiple Sclerosis', certs[0].Qualifying_Condition_ICD10__c, 'First cert should match submitted condition');
    }

    @isTest
    static void testGetPatientCardDataByIdAndFallback() {
        Patient_Registration__c reg = [SELECT Id, Patient__c FROM Patient_Registration__c LIMIT 1];
        Contact doctor = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];

        // Create active certification for this patient
        PatientPortalController.submitCertification(
            reg.Patient__c,
            doctor.Id,
            'Inflammatory Bowel Disease',
            3.00,
            Date.today(),
            Date.today().addDays(180),
            'GI specialist referral.'
        );

        Test.startTest();
        // 1. Fetch by Registration ID
        Map<String, Object> cardDataByRegId = PatientPortalController.getPatientCardData(reg.Id);
        System.assertEquals(true, (Boolean) cardDataByRegId.get('hasRecord'), 'Should find card record by registration ID');
        System.assertEquals('PA-MED-84920194', (String) cardDataByRegId.get('barcodeString'), 'Barcode must match');
        System.assertEquals(90.00, (Decimal) cardDataByRegId.get('totalQuotaGrams'), 'Total quota should be 90g');
        System.assertEquals(10.00, (Decimal) cardDataByRegId.get('gramsUsed'), 'Dispensed grams should be 10g');
        System.assertEquals(80.00, (Decimal) cardDataByRegId.get('gramsRemaining'), 'Remaining quota should be 80g');
        System.assertEquals('Inflammatory Bowel Disease', (String) cardDataByRegId.get('qualifyingCondition'), 'Condition must match active cert');

        // 2. Fetch by Patient Contact ID
        Map<String, Object> cardDataByContactId = PatientPortalController.getPatientCardData(reg.Patient__c);
        System.assertEquals(true, (Boolean) cardDataByContactId.get('hasRecord'), 'Should find card record by contact ID');

        // 3. Fetch with null parameter (defaults to first active registration)
        Map<String, Object> cardDataFallback = PatientPortalController.getPatientCardData(null);
        System.assertEquals(true, (Boolean) cardDataFallback.get('hasRecord'), 'Fallback should find first active card');
        Test.stopTest();
    }

    @isTest
    static void testGetPatientCardDataWithoutCertification() {
        Patient_Registration__c reg = [SELECT Id FROM Patient_Registration__c LIMIT 1];

        Test.startTest();
        Map<String, Object> cardData = PatientPortalController.getPatientCardData(reg.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean) cardData.get('hasRecord'), 'Should find registration record');
        System.assertEquals(false, (Boolean) cardData.get('hasCertification'), 'Should reflect that no certification exists yet');
        System.assertEquals('Chronic Pain', (String) cardData.get('qualifyingCondition'), 'Should default to standard qualifying condition');
    }

    @isTest
    static void testGetPatientCardDataEmpty() {
        // Delete all registrations and dispense transactions to test fallback graceful empty handling
        delete [SELECT Id FROM Dispense_Transaction__c];
        delete [SELECT Id FROM Patient_Registration__c];

        Test.startTest();
        Map<String, Object> emptyData = PatientPortalController.getPatientCardData(null);
        Test.stopTest();

        System.assertEquals(false, (Boolean) emptyData.get('hasRecord'), 'Should report hasRecord false when registry is empty');
    }
}
