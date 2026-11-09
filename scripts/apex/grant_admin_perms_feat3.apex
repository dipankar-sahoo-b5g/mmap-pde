Id parentId = [SELECT Id FROM PermissionSet WHERE Profile.Name = 'System Administrator' LIMIT 1].Id;

List<FieldPermissions> fps = new List<FieldPermissions>();
List<ObjectPermissions> ops = new List<ObjectPermissions>();

// Object permissions for Feature 3 objects
List<String> objects = new List<String>{
    'Strain__c',
    'Plant_Batch__c',
    'Product_Package__c'
};

for (String obj : objects) {
    ops.add(new ObjectPermissions(
        ParentId = parentId,
        SobjectType = obj,
        PermissionsCreate = true,
        PermissionsRead = true,
        PermissionsEdit = true,
        PermissionsDelete = true,
        PermissionsViewAllRecords = true,
        PermissionsModifyAllRecords = true
    ));
}

// Field permissions on Strain__c
List<String> strainFields = new List<String>{
    'Strain__c.Classification__c',
    'Strain__c.Target_THC_Percentage__c',
    'Strain__c.Target_CBD_Percentage__c',
    'Strain__c.Is_Active__c'
};

for (String fld : strainFields) {
    fps.add(new FieldPermissions(
        ParentId = parentId,
        SobjectType = 'Strain__c',
        Field = fld,
        PermissionsRead = true,
        PermissionsEdit = true
    ));
}

// Field permissions on Plant_Batch__c
List<String> batchFields = new List<String>{
    'Plant_Batch__c.Cultivator__c',
    'Plant_Batch__c.Strain__c',
    'Plant_Batch__c.Growth_Stage__c',
    'Plant_Batch__c.Initial_Plant_Count__c',
    'Plant_Batch__c.Current_Plant_Count__c',
    'Plant_Batch__c.Room_Location__c',
    'Plant_Batch__c.Planted_Date__c',
    'Plant_Batch__c.Harvest_Date__c',
    'Plant_Batch__c.Wet_Weight_Grams__c',
    'Plant_Batch__c.Dry_Weight_Grams__c'
};

for (String fld : batchFields) {
    fps.add(new FieldPermissions(
        ParentId = parentId,
        SobjectType = 'Plant_Batch__c',
        Field = fld,
        PermissionsRead = true,
        PermissionsEdit = true
    ));
}

// Field permissions on Product_Package__c
List<String> pkgFields = new List<String>{
    'Product_Package__c.Plant_Batch__c',
    'Product_Package__c.Holding_Facility__c',
    'Product_Package__c.RFID_Tag__c',
    'Product_Package__c.Product_Type__c',
    'Product_Package__c.Net_Weight_Grams__c',
    'Product_Package__c.Unit_Price__c',
    'Product_Package__c.Package_Status__c',
    'Product_Package__c.Lab_Safety_Status__c'
};

for (String fld : pkgFields) {
    fps.add(new FieldPermissions(
        ParentId = parentId,
        SobjectType = 'Product_Package__c',
        Field = fld,
        PermissionsRead = true,
        PermissionsEdit = true
    ));
}

Database.insert(ops, false);
Database.insert(fps, false);
System.debug('Feature 3 permissions granted successfully to System Administrator');
