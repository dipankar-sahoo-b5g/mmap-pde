// Script: Seed Realistic Feature 11 Transfer Manifest Records with Line Items
Account greenThumb = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-CULT-001' LIMIT 1];
Account healingLeaves = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-DISP-001' LIMIT 1];
Account pennPure = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-PROC-002' LIMIT 1];
Account keystoneCannaCare = [SELECT Id FROM Account WHERE Premise_Registry_ID__c = 'PR-DISP-002' LIMIT 1];

Plant_Batch__c batch = [SELECT Id FROM Plant_Batch__c LIMIT 1];

// 1. Create dedicated demo packages for manifests
Product_Package__c pkgInTransit = new Product_Package__c(
    Plant_Batch__c = batch.Id,
    Holding_Facility__c = greenThumb.Id,
    Product_Type__c = 'Usable_Marijuana_Flower',
    Net_Weight_Grams__c = 500.00,
    Unit_Price__c = 4500.00,
    Package_Status__c = 'In_Transit',
    Status__c = 'In_Transit',
    Lab_Safety_Status__c = 'Passed',
    RFID_Tag__c = '1A4000312678TRN000000001'
);

Product_Package__c pkgDelivered = new Product_Package__c(
    Plant_Batch__c = batch.Id,
    Holding_Facility__c = keystoneCannaCare.Id,
    Product_Type__c = 'Concentrate',
    Net_Weight_Grams__c = 250.00,
    Unit_Price__c = 3200.00,
    Package_Status__c = 'Ready_for_Sale',
    Status__c = 'In_Stock',
    Lab_Safety_Status__c = 'Passed',
    RFID_Tag__c = '1A4000312678TRN000000002'
);
insert new List<Product_Package__c>{ pkgInTransit, pkgDelivered };

// 2. Manifest 1: Active 'In Transit' Transfer Manifest
Transfer_Manifest__c mnfInTransit = new Transfer_Manifest__c(
    Origin_Facility__c = greenThumb.Id,
    Destination_Facility__c = healingLeaves.Id,
    Transporter_Facility__c = pennPure.Id,
    Driver_Name__c = 'Marcus Vance',
    Driver_License_No__c = 'PA-CDL-994821',
    Vehicle_VIN__c = '1FTFW1ED4NFA98214',
    Vehicle_License_Plate__c = 'PA-COMM-8821',
    Departure_Timestamp__c = System.now().addHours(-2),
    Estimated_Arrival__c = System.now().addHours(2),
    Status__c = 'In Transit',
    Dispatcher_Signature__c = 'Marcus Vance (Lead Cultivator & Shipper) | ' + System.now().addHours(-2).format('yyyy-MM-dd HH:mm:ss') + ' UTC',
    Transporter_Signature__c = 'Gregory Hayes (Secure Logistics Driver) | ' + System.now().addHours(-2).format('yyyy-MM-dd HH:mm:ss') + ' UTC',
    Security_Notes__c = 'Route I-76 Westbound to Downtown Vault. Armed security escort vehicle, unbroken tamper seals #884920 and #884921.'
);

// 3. Manifest 2: Reconciled 'Delivered' Transfer Manifest with Dual-Signature Handshake Completed
Transfer_Manifest__c mnfDelivered = new Transfer_Manifest__c(
    Origin_Facility__c = pennPure.Id,
    Destination_Facility__c = keystoneCannaCare.Id,
    Transporter_Facility__c = greenThumb.Id,
    Driver_Name__c = 'David Miller',
    Driver_License_No__c = 'PA-CDL-441029',
    Vehicle_VIN__c = '1FTRX18W1BKA45102',
    Vehicle_License_Plate__c = 'PA-ARM-3391',
    Departure_Timestamp__c = System.now().addHours(-6),
    Estimated_Arrival__c = System.now().addHours(-3),
    Actual_Arrival__c = System.now().addHours(-3),
    Status__c = 'Delivered',
    Dispatcher_Signature__c = 'Elena Rostova (Extraction Dispatcher) | ' + System.now().addHours(-6).format('yyyy-MM-dd HH:mm:ss') + ' UTC',
    Transporter_Signature__c = 'David Miller (Courier Agent) | ' + System.now().addHours(-6).format('yyyy-MM-dd HH:mm:ss') + ' UTC',
    Receiver_Signature__c = 'Sarah O\'Connor (Vault Intake Officer) | ' + System.now().addHours(-3).format('yyyy-MM-dd HH:mm:ss') + ' UTC',
    Security_Notes__c = 'Direct transport via Route 28 North. Physical inspection confirmed tamper-evident seals intact, zero package discrepancy.'
);

insert new List<Transfer_Manifest__c>{ mnfInTransit, mnfDelivered };

// 4. Line Items for Manifests
Manifest_Line_Item__c item1 = new Manifest_Line_Item__c(
    Transfer_Manifest__c = mnfInTransit.Id,
    Product_Package__c = pkgInTransit.Id,
    Package_RFID__c = pkgInTransit.RFID_Tag__c,
    Gross_Weight_Grams__c = 575.00,
    Item_Count__c = 1
);

Manifest_Line_Item__c item2 = new Manifest_Line_Item__c(
    Transfer_Manifest__c = mnfDelivered.Id,
    Product_Package__c = pkgDelivered.Id,
    Package_RFID__c = pkgDelivered.RFID_Tag__c,
    Gross_Weight_Grams__c = 287.50,
    Item_Count__c = 1
);

insert new List<Manifest_Line_Item__c>{ item1, item2 };

System.debug('Seeded Manifest 1 (In Transit): ' + mnfInTransit.Id);
System.debug('Seeded Manifest 2 (Delivered): ' + mnfDelivered.Id);
