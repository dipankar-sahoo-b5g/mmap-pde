// Seed Comprehensive Demo Data for Commonwealth Medical Marijuana Regulatory Platform
System.debug('Starting seed data execution...');

// 1. Create Facilities (Accounts)
Account cultAcc = new Account(
    Name = 'Green Thumb Cultivation Center',
    Facility_Type__c = 'Grower_Processor',
    Premise_Registry_ID__c = 'PR-CULT-001',
    Vault_Capacity_Grams__c = 250000.00,
    Compliance_Status__c = 'Compliant'
);
insert cultAcc;

Account labAcc = new Account(
    Name = 'Keystone State Analytics Lab',
    Facility_Type__c = 'Testing_Laboratory',
    Premise_Registry_ID__c = 'PR-LAB-001',
    Compliance_Status__c = 'Compliant'
);
insert labAcc;

Account dispAcc = new Account(
    Name = 'Healing Leaves Dispensary - Downtown',
    Facility_Type__c = 'Dispensary',
    Premise_Registry_ID__c = 'PR-DISP-001',
    Vault_Capacity_Grams__c = 50000.00,
    Compliance_Status__c = 'Compliant'
);
insert dispAcc;

// 2. Create Key Stakeholders, Doctors, and Patients (Contacts)
Contact docContact = new Contact(
    FirstName = 'Robert',
    LastName = 'Chen',
    AccountId = labAcc.Id,
    Stakeholder_Role__c = 'Physician',
    Medical_License_No__c = 'MD-98214-PA',
    State_ID_Number__c = 'PA-DOC-00918',
    Email = 'dr.chen@keystoneanalytics.state.gov'
);
insert docContact;

Contact patientContact = new Contact(
    FirstName = 'Sarah',
    LastName = 'Jenkins',
    AccountId = dispAcc.Id,
    Stakeholder_Role__c = 'Patient',
    State_ID_Number__c = 'PA-DL-84920194',
    Email = 'sarah.jenkins@example.state.gov'
);
insert patientContact;

Contact growerContact = new Contact(
    FirstName = 'Marcus',
    LastName = 'Vance',
    AccountId = cultAcc.Id,
    Stakeholder_Role__c = 'Facility_Agent',
    State_ID_Number__c = 'PA-EMP-55210',
    Email = 'marcus.vance@greenthumb.state.gov'
);
insert growerContact;

// 3. Create Commercial Licenses (Business_License__c)
List<Business_License__c> licenses = new List<Business_License__c>{
    new Business_License__c(
        Facility__c = cultAcc.Id,
        License_Number__c = 'LIC-CULT-2026-001',
        License_Tier__c = 'Standard_Commercial',
        Issue_Date__c = Date.today().addMonths(-6),
        Expiration_Date__c = Date.today().addMonths(6),
        Status__c = 'Active'
    ),
    new Business_License__c(
        Facility__c = labAcc.Id,
        License_Number__c = 'LIC-LAB-2026-002',
        License_Tier__c = 'Standard_Commercial',
        Issue_Date__c = Date.today().addMonths(-6),
        Expiration_Date__c = Date.today().addMonths(6),
        Status__c = 'Active'
    ),
    new Business_License__c(
        Facility__c = dispAcc.Id,
        License_Number__c = 'LIC-DISP-2026-003',
        License_Tier__c = 'Standard_Commercial',
        Issue_Date__c = Date.today().addMonths(-6),
        Expiration_Date__c = Date.today().addMonths(6),
        Status__c = 'Active'
    )
};
insert licenses;

// 4. Create Patient Registration Card (Patient_Registration__c)
Patient_Registration__c patientCard = new Patient_Registration__c(
    Patient__c = patientContact.Id,
    Certifying_Physician__c = docContact.Id,
    Barcode_String__c = 'PA-MED-84920194',
    Thirty_Day_Limit_Grams__c = 90.00,
    Certification_Date__c = Date.today().addMonths(-2),
    Expiration_Date__c = Date.today().addMonths(10)
);
insert patientCard;

// 5. Create Genetics Catalog (Strain__c)
List<Strain__c> strains = new List<Strain__c>{
    new Strain__c(
        Name = 'Blue Dream',
        Classification__c = 'Hybrid',
        Target_THC_Percentage__c = 21.50,
        Target_CBD_Percentage__c = 0.10,
        Is_Active__c = true
    ),
    new Strain__c(
        Name = 'Granddaddy Purple',
        Classification__c = 'Indica',
        Target_THC_Percentage__c = 23.00,
        Target_CBD_Percentage__c = 0.05,
        Is_Active__c = true
    ),
    new Strain__c(
        Name = 'ACDC Therapy',
        Classification__c = 'Sativa',
        Target_THC_Percentage__c = 1.20,
        Target_CBD_Percentage__c = 18.50,
        Is_Active__c = true
    )
};
insert strains;

// 6. Create Cultivation Batches (Plant_Batch__c)
Plant_Batch__c batchFlowering = new Plant_Batch__c(
    Cultivator__c = cultAcc.Id,
    Strain__c = strains[0].Id,
    Growth_Stage__c = 'Flowering',
    Initial_Plant_Count__c = 500,
    Current_Plant_Count__c = 492,
    Room_Location__c = 'Grow Room 2',
    Planted_Date__c = Date.today().addDays(-45)
);
insert batchFlowering;

Plant_Batch__c batchHarvested = new Plant_Batch__c(
    Cultivator__c = cultAcc.Id,
    Strain__c = strains[1].Id,
    Growth_Stage__c = 'Harvested',
    Initial_Plant_Count__c = 200,
    Current_Plant_Count__c = 198,
    Room_Location__c = 'Drying Bay A',
    Planted_Date__c = Date.today().addDays(-90),
    Harvest_Date__c = Date.today().addDays(-7),
    Wet_Weight_Grams__c = 45000.00,
    Dry_Weight_Grams__c = 9200.00
);
insert batchHarvested;

// 7. Create Packaged Inventory (Product_Package__c)
Product_Package__c pkgReady = new Product_Package__c(
    Plant_Batch__c = batchHarvested.Id,
    Holding_Facility__c = dispAcc.Id,
    Product_Type__c = 'Usable_Marijuana_Flower',
    Net_Weight_Grams__c = 3.50,
    Unit_Price__c = 45.00,
    Package_Status__c = 'In_Testing',
    Lab_Safety_Status__c = 'Passed'
);
insert pkgReady;

Product_Package__c pkgTesting = new Product_Package__c(
    Plant_Batch__c = batchFlowering.Id,
    Holding_Facility__c = cultAcc.Id,
    Product_Type__c = 'Cannabis_Oil',
    Net_Weight_Grams__c = 1.00,
    Unit_Price__c = 60.00,
    Package_Status__c = 'In_Testing',
    Lab_Safety_Status__c = 'Untested'
);
insert pkgTesting;

// 8. Create Lab Test Result Certificate (Lab_Test_Result__c)
Lab_Test_Result__c coa1 = new Lab_Test_Result__c(
    Product_Package__c = pkgReady.Id,
    Testing_Laboratory__c = labAcc.Id,
    Test_Date__c = Date.today().addDays(-2),
    THC_Potency_Pct__c = 22.80,
    CBD_Potency_Pct__c = 0.05,
    Pesticides_Pass__c = true,
    Heavy_Metals_Pass__c = true,
    Mycotoxins_Pass__c = true,
    Residual_Solvents_Pass__c = true,
    Overall_Status__c = 'Passed'
);
insert coa1;

// Now that COA is Passed, mark package Ready for Sale
pkgReady.Package_Status__c = 'Ready_for_Sale';
update pkgReady;

// 9. Create Dispensary Sale Transaction (Dispense_Transaction__c)
Dispense_Transaction__c sale1 = new Dispense_Transaction__c(
    Patient_Registration__c = patientCard.Id,
    Dispensary__c = dispAcc.Id,
    Product_Package__c = pkgReady.Id,
    Transaction_Timestamp__c = Datetime.now().addHours(-3),
    Grams_Dispensed__c = 3.50,
    Total_Amount__c = 45.00
);
insert sale1;

System.debug('SEED_DATA_SUCCESS');
System.debug('Cultivator Account ID: ' + cultAcc.Id);
System.debug('Dispensary Account ID: ' + dispAcc.Id);
System.debug('Patient Card: ' + patientCard.Id);
System.debug('Product Package RFID: ' + [SELECT RFID_Tag__c FROM Product_Package__c WHERE Id = :pkgReady.Id].RFID_Tag__c);
