// Expanded Seed Data for Commonwealth Medical Marijuana Regulatory Platform
System.debug('Starting expanded seed data execution...');

// Facilities (Accounts)
Account cultAcc2 = new Account(
    Name = 'Penn Pure Processing & Extraction',
    Facility_Type__c = 'Grower_Processor',
    Premise_Registry_ID__c = 'PR-PROC-002',
    Vault_Capacity_Grams__c = 180000.00,
    Compliance_Status__c = 'Compliant'
);
Account dispAcc2 = new Account(
    Name = 'Keystone CannaCare - North Hills',
    Facility_Type__c = 'Dispensary',
    Premise_Registry_ID__c = 'PR-DISP-002',
    Vault_Capacity_Grams__c = 60000.00,
    Compliance_Status__c = 'Compliant'
);
insert new List<Account>{cultAcc2, dispAcc2};

// Contacts
Contact pat2 = new Contact(
    FirstName = 'Michael',
    LastName = 'O\'Connor',
    AccountId = dispAcc2.Id,
    Stakeholder_Role__c = 'Patient',
    State_ID_Number__c = 'PA-DL-99210481',
    Email = 'michael.oc@example.state.gov'
);
Contact caregiver = new Contact(
    FirstName = 'Elena',
    LastName = 'Rostova',
    AccountId = dispAcc2.Id,
    Stakeholder_Role__c = 'Caregiver',
    State_ID_Number__c = 'PA-CG-48192031',
    Email = 'elena.rostova@example.state.gov'
);
insert new List<Contact>{pat2, caregiver};

// Commercial Licenses
List<Business_License__c> licenses2 = new List<Business_License__c>{
    new Business_License__c(
        Facility__c = cultAcc2.Id,
        License_Number__c = 'LIC-PROC-2026-004',
        License_Tier__c = 'Standard_Commercial',
        Issue_Date__c = Date.today().addMonths(-4),
        Expiration_Date__c = Date.today().addMonths(8),
        Status__c = 'Active'
    ),
    new Business_License__c(
        Facility__c = dispAcc2.Id,
        License_Number__c = 'LIC-DISP-2026-005',
        License_Tier__c = 'Standard_Commercial',
        Issue_Date__c = Date.today().addMonths(-3),
        Expiration_Date__c = Date.today().addMonths(9),
        Status__c = 'Active'
    )
};
insert licenses2;

// Additional Patients
Contact docContact = [SELECT Id FROM Contact WHERE Stakeholder_Role__c = 'Physician' LIMIT 1];
List<Patient_Registration__c> patCards = new List<Patient_Registration__c>{
    new Patient_Registration__c(
        Patient__c = pat2.Id,
        Certifying_Physician__c = docContact.Id,
        Barcode_String__c = 'PA-MED-99210481',
        Thirty_Day_Limit_Grams__c = 60.00,
        Certification_Date__c = Date.today().addMonths(-1),
        Expiration_Date__c = Date.today().addMonths(11)
    )
};
insert patCards;

// Additional Strains
List<Strain__c> newStrains = new List<Strain__c>{
    new Strain__c(
        Name = 'Sour Diesel',
        Classification__c = 'Sativa',
        Target_THC_Percentage__c = 24.50,
        Target_CBD_Percentage__c = 0.08,
        Is_Active__c = true
    ),
    new Strain__c(
        Name = 'Northern Lights',
        Classification__c = 'Indica',
        Target_THC_Percentage__c = 19.80,
        Target_CBD_Percentage__c = 0.15,
        Is_Active__c = true
    )
};
insert newStrains;

// Additional Batches
Plant_Batch__c batchVeg = new Plant_Batch__c(
    Cultivator__c = cultAcc2.Id,
    Strain__c = newStrains[0].Id,
    Growth_Stage__c = 'Vegetative',
    Initial_Plant_Count__c = 300,
    Current_Plant_Count__c = 295,
    Room_Location__c = 'Vegetative Room V-1',
    Planted_Date__c = Date.today().addDays(-20)
);
Plant_Batch__c batchSeedling = new Plant_Batch__c(
    Cultivator__c = cultAcc2.Id,
    Strain__c = newStrains[1].Id,
    Growth_Stage__c = 'Seedling',
    Initial_Plant_Count__c = 400,
    Current_Plant_Count__c = 400,
    Room_Location__c = 'Nursery Bay 3',
    Planted_Date__c = Date.today().addDays(-5)
);
insert new List<Plant_Batch__c>{batchVeg, batchSeedling};

// Additional Product Packages
Product_Package__c pkg3 = new Product_Package__c(
    Plant_Batch__c = batchVeg.Id,
    Holding_Facility__c = dispAcc2.Id,
    Product_Type__c = 'Concentrate',
    Net_Weight_Grams__c = 0.50,
    Unit_Price__c = 40.00,
    Package_Status__c = 'In_Testing',
    Lab_Safety_Status__c = 'Passed'
);
Product_Package__c pkg4 = new Product_Package__c(
    Plant_Batch__c = batchSeedling.Id,
    Holding_Facility__c = cultAcc2.Id,
    Product_Type__c = 'Topical',
    Net_Weight_Grams__c = 50.00,
    Unit_Price__c = 35.00,
    Package_Status__c = 'In_Testing',
    Lab_Safety_Status__c = 'Untested'
);
insert new List<Product_Package__c>{pkg3, pkg4};

// COA for pkg3
Account labAcc = [SELECT Id FROM Account WHERE Facility_Type__c = 'Testing_Laboratory' LIMIT 1];
Lab_Test_Result__c coa2 = new Lab_Test_Result__c(
    Product_Package__c = pkg3.Id,
    Testing_Laboratory__c = labAcc.Id,
    Test_Date__c = Date.today().addDays(-1),
    THC_Potency_Pct__c = 78.50,
    CBD_Potency_Pct__c = 0.45,
    Pesticides_Pass__c = true,
    Heavy_Metals_Pass__c = true,
    Mycotoxins_Pass__c = true,
    Residual_Solvents_Pass__c = true,
    Overall_Status__c = 'Passed'
);
insert coa2;

pkg3.Package_Status__c = 'Ready_for_Sale';
update pkg3;

// Additional Dispense Transactions
Dispense_Transaction__c sale2 = new Dispense_Transaction__c(
    Patient_Registration__c = patCards[0].Id,
    Dispensary__c = dispAcc2.Id,
    Product_Package__c = pkg3.Id,
    Transaction_Timestamp__c = Datetime.now().addHours(-1),
    Grams_Dispensed__c = 0.50,
    Total_Amount__c = 40.00
);
insert sale2;

System.debug('EXPANDED_SEED_SUCCESS');

