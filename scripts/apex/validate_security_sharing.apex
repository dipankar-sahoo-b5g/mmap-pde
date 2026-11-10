/**
 * @description Audit script to verify that external sharing models are configured
 *              as Private across all 14 in-scope MMAP supply chain objects
 *              from docs/PA Seed-to-Sale Demo Plan_7.xlsx.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
List<EntityDefinition> entities = [
    SELECT QualifiedApiName, ExternalSharingModel, InternalSharingModel 
    FROM EntityDefinition 
    WHERE QualifiedApiName IN (
        'Account',
        'Contact',
        'Tracked_Item__c',
        'Lineage_Link__c',
        'Inventory_Event__c',
        'Lab_Result__c',
        'Transfer_Manifest__c',
        'Manifest_Line__c',
        'Patient_Ref__c',
        'Registry_Check__c',
        'Label_Template__c',
        'Label_Print__c',
        'Recall__c',
        'Recall_Exposure__c'
    )
    ORDER BY QualifiedApiName ASC
];

System.debug('====================================================');
System.debug('IN-SCOPE MMAP OBJECTS: EXTERNAL SHARING MODEL AUDIT');
System.debug('Baseline: docs/PA Seed-to-Sale Demo Plan_7.xlsx');
System.debug('====================================================');

Boolean allCompliant = true;
for (EntityDefinition e : entities) {
    Boolean isPrivate = (e.ExternalSharingModel == 'Private' || e.ExternalSharingModel == 'ControlledByParent');
    System.debug('Entity: ' + e.QualifiedApiName + ' | External OWD: ' + e.ExternalSharingModel + ' | Compliant: ' + isPrivate);
    if (!isPrivate) {
        allCompliant = false;
    }
}

System.debug('====================================================');
System.debug('ALL 14 IN-SCOPE OBJECTS PROPERLY ISOLATED (PRIVATE/CONTROLLED): ' + allCompliant);
System.debug('Total Audited: ' + entities.size() + ' of 14');
System.debug('====================================================');
