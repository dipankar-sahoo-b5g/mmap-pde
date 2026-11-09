// Feature 2: Patient Registration & Doctor Recommendations Verification
Contact patient = new Contact(
    LastName = 'Doe',
    FirstName = 'Jane',
    Stakeholder_Role__c = 'Patient',
    State_ID_Number__c = 'PA-ID-883921'
);
Contact doctor = new Contact(
    LastName = 'Smith',
    FirstName = 'Robert',
    Stakeholder_Role__c = 'Physician',
    Medical_License_No__c = 'MD-PA-2026-0044'
);
insert new List<Contact>{ patient, doctor };
System.assert(patient.Id != null, 'Patient contact should be inserted');
System.assert(doctor.Id != null, 'Doctor contact should be inserted');

String testBarcode = 'PA-MED-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '').right(8);
Patient_Registration__c validReg = new Patient_Registration__c(
    Patient__c = patient.Id,
    Certifying_Physician__c = doctor.Id,
    Barcode_String__c = testBarcode,
    Certification_Date__c = Date.today(),
    Expiration_Date__c = Date.today().addYears(1),
    Thirty_Day_Limit_Grams__c = 90.00
);
insert validReg;
System.assert(validReg.Id != null, 'Patient Registration should be inserted');

// Query back and verify all fields including AutoNumber and Formula
Patient_Registration__c queriedReg = [
    SELECT Id, Name, Patient__c, Certifying_Physician__c, Barcode_String__c,
           Thirty_Day_Limit_Grams__c, Certification_Date__c, Expiration_Date__c, Is_Active__c
    FROM Patient_Registration__c
    WHERE Id = :validReg.Id
];

System.assertNotEquals(null, queriedReg.Name, 'AutoNumber Name should be generated');
System.assert(queriedReg.Name.startsWith('MMAP-'), 'AutoNumber should match format MMAP-{YYYY}-{000000}: ' + queriedReg.Name);
System.assertEquals(patient.Id, queriedReg.Patient__c, 'Patient__c must match patient Contact Id');
System.assertEquals(doctor.Id, queriedReg.Certifying_Physician__c, 'Certifying_Physician__c must match doctor Contact Id');
System.assertEquals(testBarcode, queriedReg.Barcode_String__c, 'Barcode string must match');
System.assertEquals(90.00, queriedReg.Thirty_Day_Limit_Grams__c, 'Default limit must be 90.00 grams');
System.assertEquals(true, queriedReg.Is_Active__c, 'Is_Active__c formula must evaluate to true');
System.debug('POSITIVE_PASS: Registration ' + queriedReg.Name + ' verified with Is_Active__c = ' + queriedReg.Is_Active__c);

// Negative Test: VR_PAT_Active_Date (Expiration_Date__c <= Certification_Date__c)
Boolean vrFired = false;
String vrMessage = '';
try {
    Patient_Registration__c invalidReg = new Patient_Registration__c(
        Patient__c = patient.Id,
        Certifying_Physician__c = doctor.Id,
        Barcode_String__c = 'PA-MED-INVALID-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '').right(6),
        Certification_Date__c = Date.today(),
        Expiration_Date__c = Date.today(), // Equal to certification date -> MUST FAIL
        Thirty_Day_Limit_Grams__c = 90.00
    );
    insert invalidReg;
} catch (DmlException e) {
    vrMessage = e.getMessage();
    vrFired = vrMessage.contains('Card expiration date must be later than the doctor certification date');
    System.debug('VR_PAT_Active_Date exception caught: ' + vrMessage);
}
System.assert(vrFired, 'Validation rule VR_PAT_Active_Date should have fired. Received: ' + vrMessage);
System.debug('NEGATIVE_PASS: VR_PAT_Active_Date correctly blocked invalid date');

// Clean up
delete validReg;
delete new List<Contact>{ patient, doctor };
System.debug('=== FEATURE 2 VERIFICATION COMPLETED SUCCESSFULLY ===');
