/**
 * @description Audit script to verify that external sharing models are configured
 *              as Private across all core MMAP supply chain objects.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
List<EntityDefinition> entities = [
    SELECT QualifiedApiName, ExternalSharingModel, InternalSharingModel 
    FROM EntityDefinition 
    WHERE QualifiedApiName IN ('Tracked_Item__c', 'Plant_Batch__c', 'Product_Package__c', 'Lab_Result__c', 'Transfer_Manifest__c', 'Dispense_Transaction__c', 'Account', 'Registry_Check__c')
    ORDER BY QualifiedApiName ASC
];

System.debug('====================================================');
System.debug('MMAP COMPLIANCE AUDIT: EXTERNAL SHARING MODEL VERIFICATION');
System.debug('====================================================');

Boolean allPrivate = true;
for (EntityDefinition e : entities) {
    System.debug('Entity: ' + e.QualifiedApiName + ' | External OWD: ' + e.ExternalSharingModel + ' | Internal: ' + e.InternalSharingModel);
    if (e.ExternalSharingModel != 'Private') {
        allPrivate = false;
    }
}

System.debug('====================================================');
System.debug('ALL CORE OBJECTS CONFIGURED TO PRIVATE EXTERNAL OWD: ' + allPrivate);
System.debug('====================================================');
