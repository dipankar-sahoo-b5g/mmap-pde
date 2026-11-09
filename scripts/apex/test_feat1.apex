Account acc = new Account(
    Name = 'Test Grower Facility',
    Facility_Type__c = 'Grower_Processor',
    Premise_Registry_ID__c = 'FAC-TEST-001',
    Compliance_Status__c = 'Compliant',
    Vault_Capacity_Grams__c = 50000.00
);
insert acc;
System.assert(acc.Id != null, 'Account should be inserted');

Contact con = new Contact(
    LastName = 'Smith',
    AccountId = acc.Id,
    Stakeholder_Role__c = 'Facility_Agent',
    State_ID_Number__c = 'DL12345678',
    Medical_License_No__c = 'MD-998877'
);
insert con;
System.assert(con.Id != null, 'Contact should be inserted');

Business_License__c lic = new Business_License__c(
    Facility__c = acc.Id,
    License_Number__c = 'LIC-GP-001',
    License_Tier__c = 'Standard_Commercial',
    Issue_Date__c = Date.today(),
    Expiration_Date__c = Date.today().addYears(1),
    Status__c = 'Active'
);
insert lic;
System.assert(lic.Id != null, 'Business License should be inserted');

Boolean vrFired = false;
try {
    Business_License__c invalidLic = new Business_License__c(
        Facility__c = acc.Id,
        License_Number__c = 'LIC-GP-002',
        License_Tier__c = 'Microbusiness',
        Issue_Date__c = Date.today(),
        Expiration_Date__c = Date.today().addDays(-1),
        Status__c = 'Active'
    );
    insert invalidLic;
} catch (DmlException e) {
    vrFired = e.getMessage().contains('License expiration date must be after the issue date');
}
System.assert(vrFired, 'Validation rule VR_LIC_Valid_Dates should have fired');

// Clean up
delete acc;
System.debug('=== FEATURE 1 VERIFICATION COMPLETED SUCCESSFULLY ===');
