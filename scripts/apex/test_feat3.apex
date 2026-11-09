// Feature 3: Cultivation & Seed-to-Sale Data Model Verification
System.debug('=== START FEATURE 3 VERIFICATION ===');

// Setup: Test Facility Account
String facilityCode = 'FAC-TEST-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '').right(6);
Account cultivator = new Account(
    Name = 'Keystone State Cultivation Ltd',
    Facility_Type__c = 'Grower_Processor',
    Premise_Registry_ID__c = facilityCode,
    Compliance_Status__c = 'Compliant',
    Vault_Capacity_Grams__c = 500000.00
);
insert cultivator;
System.assert(cultivator.Id != null, 'Cultivator facility Account should be inserted');

// 1. Positive Test: Insert Strain__c
Strain__c strain = new Strain__c(
    Name = 'Northern Lights Blue',
    Classification__c = 'Indica',
    Target_THC_Percentage__c = 22.50,
    Target_CBD_Percentage__c = 0.85,
    Is_Active__c = true
);
insert strain;
System.assert(strain.Id != null, 'Strain should be inserted');

Strain__c queriedStrain = [
    SELECT Id, Name, Classification__c, Target_THC_Percentage__c, Target_CBD_Percentage__c, Is_Active__c
    FROM Strain__c
    WHERE Id = :strain.Id
];
System.assertEquals('Northern Lights Blue', queriedStrain.Name, 'Strain name must match');
System.assertEquals('Indica', queriedStrain.Classification__c, 'Classification must match');
System.assertEquals(22.50, queriedStrain.Target_THC_Percentage__c, 'Target THC must match');
System.assertEquals(0.85, queriedStrain.Target_CBD_Percentage__c, 'Target CBD must match');
System.assertEquals(true, queriedStrain.Is_Active__c, 'Is_Active__c must be true');
System.debug('POSITIVE_PASS: Strain verified: ' + queriedStrain.Name);

// 2. Positive Test: Insert Plant_Batch__c (Flowering stage)
Plant_Batch__c batch = new Plant_Batch__c(
    Cultivator__c = cultivator.Id,
    Strain__c = strain.Id,
    Growth_Stage__c = 'Flowering',
    Initial_Plant_Count__c = 100,
    Current_Plant_Count__c = 95,
    Room_Location__c = 'Grow Room 3B',
    Planted_Date__c = Date.today().addDays(-40)
);
insert batch;
System.assert(batch.Id != null, 'Plant Batch should be inserted');

Plant_Batch__c queriedBatch = [
    SELECT Id, Name, Cultivator__c, Strain__c, Growth_Stage__c, Initial_Plant_Count__c,
           Current_Plant_Count__c, Room_Location__c, Planted_Date__c, Harvest_Date__c,
           Wet_Weight_Grams__c, Dry_Weight_Grams__c
    FROM Plant_Batch__c
    WHERE Id = :batch.Id
];
System.assert(queriedBatch.Name.startsWith('PB-'), 'Plant Batch AutoNumber should start with PB-: ' + queriedBatch.Name);
System.assertEquals('Flowering', queriedBatch.Growth_Stage__c, 'Growth stage should be Flowering');
System.assertEquals(100, queriedBatch.Initial_Plant_Count__c, 'Initial count should be 100');
System.assertEquals(95, queriedBatch.Current_Plant_Count__c, 'Current count should be 95');
System.assertEquals('Grow Room 3B', queriedBatch.Room_Location__c, 'Room location should match');
System.debug('POSITIVE_PASS: Plant Batch verified: ' + queriedBatch.Name);

// Positive Harvest Transition: Update with valid Dry Weight
batch.Growth_Stage__c = 'Harvested';
batch.Harvest_Date__c = Date.today();
batch.Wet_Weight_Grams__c = 25000.00;
batch.Dry_Weight_Grams__c = 6200.50;
update batch;

Plant_Batch__c harvestedBatch = [
    SELECT Id, Growth_Stage__c, Harvest_Date__c, Wet_Weight_Grams__c, Dry_Weight_Grams__c
    FROM Plant_Batch__c
    WHERE Id = :batch.Id
];
System.assertEquals('Harvested', harvestedBatch.Growth_Stage__c, 'Batch should be transitioned to Harvested');
System.assertEquals(6200.50, harvestedBatch.Dry_Weight_Grams__c, 'Dry weight should be recorded');
System.debug('POSITIVE_PASS: Plant Batch successfully transitioned to Harvested with dry weight: ' + harvestedBatch.Dry_Weight_Grams__c);

// 3. Positive Test: Insert Product_Package__c
String randomNumeric = String.valueOf(Math.abs(Crypto.getRandomLong()));
String rfidTag = ('1A40003' + randomNumeric + '00000000000000000').substring(0, 24);
System.assertEquals(24, rfidTag.length(), 'RFID tag must be 24 characters');

Product_Package__c pkg = new Product_Package__c(
    Plant_Batch__c = batch.Id,
    Holding_Facility__c = cultivator.Id,
    RFID_Tag__c = rfidTag,
    Product_Type__c = 'Usable_Marijuana_Flower',
    Net_Weight_Grams__c = 453.59,
    Unit_Price__c = 2800.00,
    Package_Status__c = 'In_Testing',
    Lab_Safety_Status__c = 'Untested'
);
insert pkg;
System.assert(pkg.Id != null, 'Product Package should be inserted');

Product_Package__c queriedPkg = [
    SELECT Id, Name, Plant_Batch__c, Holding_Facility__c, RFID_Tag__c, Product_Type__c,
           Net_Weight_Grams__c, Unit_Price__c, Package_Status__c, Lab_Safety_Status__c
    FROM Product_Package__c
    WHERE Id = :pkg.Id
];
System.assert(queriedPkg.Name.startsWith('PKG-'), 'Product Package AutoNumber should start with PKG-: ' + queriedPkg.Name);
System.assertEquals(rfidTag, queriedPkg.RFID_Tag__c, 'RFID tag must match');
System.assertEquals('Usable_Marijuana_Flower', queriedPkg.Product_Type__c, 'Product type must match');
System.assertEquals(453.59, queriedPkg.Net_Weight_Grams__c, 'Net weight must match');
System.assertEquals(2800.00, queriedPkg.Unit_Price__c, 'Unit price must match');
System.assertEquals('In_Testing', queriedPkg.Package_Status__c, 'Package status must default to In_Testing');
System.assertEquals('Untested', queriedPkg.Lab_Safety_Status__c, 'Lab safety status must default to Untested');
System.debug('POSITIVE_PASS: Product Package verified: ' + queriedPkg.Name + ' (RFID: ' + queriedPkg.RFID_Tag__c + ')');

// 4. Negative Test: VR_BATCH_Harvest_Weight
// Stage = 'Harvested' but Dry_Weight_Grams__c is null -> MUST FAIL
Boolean vrFired = false;
String vrMessage = '';
try {
    Plant_Batch__c invalidBatch = new Plant_Batch__c(
        Cultivator__c = cultivator.Id,
        Strain__c = strain.Id,
        Growth_Stage__c = 'Harvested',
        Initial_Plant_Count__c = 50,
        Current_Plant_Count__c = 50,
        Room_Location__c = 'Drying Room 1',
        Planted_Date__c = Date.today().addDays(-50),
        Dry_Weight_Grams__c = null
    );
    insert invalidBatch;
} catch (DmlException e) {
    vrMessage = e.getMessage();
    vrFired = vrMessage.contains('You must enter dry harvest weight before setting batch stage to Harvested');
    System.debug('VR_BATCH_Harvest_Weight caught: ' + vrMessage);
}
System.assert(vrFired, 'Validation rule VR_BATCH_Harvest_Weight should have fired. Received: ' + vrMessage);
System.debug('NEGATIVE_PASS: VR_BATCH_Harvest_Weight correctly blocked Harvested stage without dry weight');

// 5. Teardown
delete pkg;
delete batch;
delete strain;
delete cultivator;
System.debug('TEARDOWN_PASS: Scratch test records cleaned up successfully');
System.debug('=== FEATURE 3 VERIFICATION COMPLETED SUCCESSFULLY ===');
