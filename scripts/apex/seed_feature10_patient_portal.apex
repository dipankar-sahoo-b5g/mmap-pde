// Seed Feature 10 Demo Data: Dr. Rachel Chen, Michael Torres, and 2 Active Physician Certifications

// 1. Ensure Dr. Rachel Chen exists
List<Contact> docs = [SELECT Id FROM Contact WHERE LastName = 'Chen' AND FirstName = 'Rachel' LIMIT 1];
Contact docRachel;
if (docs.isEmpty()) {
    docRachel = new Contact(
        FirstName = 'Rachel',
        LastName = 'Chen',
        Stakeholder_Role__c = 'Physician',
        Medical_License_No__c = 'MD-PA-98214',
        Email = 'dr.rachel.chen@health.pa.gov'
    );
    insert docRachel;
    System.debug('Created Dr. Rachel Chen: ' + docRachel.Id);
} else {
    docRachel = docs[0];
    System.debug('Existing Dr. Rachel Chen: ' + docRachel.Id);
}

// 2. Ensure Sarah Jenkins exists
List<Contact> sarahList = [SELECT Id FROM Contact WHERE LastName = 'Jenkins' AND FirstName = 'Sarah' LIMIT 1];
Contact sarahContact = sarahList[0];

// 3. Ensure Michael Torres exists
List<Contact> torresList = [SELECT Id FROM Contact WHERE LastName = 'Torres' AND FirstName = 'Michael' LIMIT 1];
Contact torresContact;
if (torresList.isEmpty()) {
    torresContact = new Contact(
        FirstName = 'Michael',
        LastName = 'Torres',
        Stakeholder_Role__c = 'Patient',
        State_ID_Number__c = 'PA-DL-77391024',
        Email = 'michael.torres@phillymed.org'
    );
    insert torresContact;
    System.debug('Created Michael Torres: ' + torresContact.Id);
} else {
    torresContact = torresList[0];
    System.debug('Existing Michael Torres: ' + torresContact.Id);
}

// 4. Ensure Michael Torres has a Patient_Registration__c
List<Patient_Registration__c> torresRegs = [SELECT Id FROM Patient_Registration__c WHERE Patient__c = :torresContact.Id LIMIT 1];
if (torresRegs.isEmpty()) {
    Patient_Registration__c regTorres = new Patient_Registration__c(
        Patient__c = torresContact.Id,
        Certifying_Physician__c = docRachel.Id,
        Barcode_String__c = 'PA-MED-77391024',
        Thirty_Day_Limit_Grams__c = 60.00,
        Certification_Date__c = Date.today().addDays(-15),
        Expiration_Date__c = Date.today().addDays(350)
    );
    insert regTorres;
    System.debug('Created Patient Registration for Michael Torres: ' + regTorres.Id);
}

// 5. Seed active certification for Sarah Jenkins
List<Physician_Certification__c> sarahCerts = [
    SELECT Id FROM Physician_Certification__c 
    WHERE Patient__c = :sarahContact.Id AND Certifying_Physician__c = :docRachel.Id AND Status__c = 'Active'
];
if (sarahCerts.isEmpty()) {
    Physician_Certification__c certSarah = new Physician_Certification__c(
        Patient__c = sarahContact.Id,
        Certifying_Physician__c = docRachel.Id,
        Qualifying_Condition_ICD10__c = 'Chronic Pain',
        Recommended_Daily_Dose_Grams__c = 3.00,
        Issue_Date__c = Date.today().addDays(-10),
        Expiration_Date__c = Date.today().addDays(355),
        Doctor_Digital_Signature_Timestamp__c = DateTime.now().addDays(-10),
        Status__c = 'Active',
        Certification_Notes__c = 'Patient presents with severe neuropathic chronic pain symptoms. Standard daily dose indicated.'
    );
    insert certSarah;
    System.debug('Created Physician Certification for Sarah Jenkins: ' + certSarah.Id);
}

// 6. Seed active certification for Michael Torres
List<Physician_Certification__c> torresCerts = [
    SELECT Id FROM Physician_Certification__c 
    WHERE Patient__c = :torresContact.Id AND Certifying_Physician__c = :docRachel.Id AND Status__c = 'Active'
];
if (torresCerts.isEmpty()) {
    Physician_Certification__c certTorres = new Physician_Certification__c(
        Patient__c = torresContact.Id,
        Certifying_Physician__c = docRachel.Id,
        Qualifying_Condition_ICD10__c = 'PTSD',
        Recommended_Daily_Dose_Grams__c = 2.50,
        Issue_Date__c = Date.today().addDays(-15),
        Expiration_Date__c = Date.today().addDays(350),
        Doctor_Digital_Signature_Timestamp__c = DateTime.now().addDays(-15),
        Status__c = 'Active',
        Certification_Notes__c = 'Clinical assessment confirms qualifying post-traumatic stress diagnosis. Authorized for medical cannabis registry.'
    );
    insert certTorres;
    System.debug('Created Physician Certification for Michael Torres: ' + certTorres.Id);
}

System.debug('Feature 10 Demo Seed Completed Successfully.');
