/**
 * @description Service to audit and report data isolation across external permittee facilities,
 *              verifying Private Organization-Wide Defaults (OWD) and persona security boundaries
 *              strictly for the 14 in-scope objects defined in docs/PA Seed-to-Sale Demo Plan_7.xlsx
 *              for Developer Phase 3 (Task T08).
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
public with sharing class PermitteeSecuritySharingService {

    public class SecurityAuditReport {
        @AuraEnabled public Boolean allCoreObjectsPrivate;
        @AuraEnabled public List<String> privateEntities;
        @AuraEnabled public List<String> nonPrivateEntities;
        @AuraEnabled public Integer totalAudited;

        public SecurityAuditReport() {
            this.allCoreObjectsPrivate = true;
            this.privateEntities = new List<String>();
            this.nonPrivateEntities = new List<String>();
            this.totalAudited = 0;
        }
    }

    /**
     * @description Inspects the live EntityDefinition external sharing models strictly for the
     *              14 authoritative in-scope MMAP supply chain objects from PA Seed-to-Sale Demo Plan_7.xlsx.
     *              Excludes all legacy/obsolete objects (Plant_Batch__c, Product_Package__c, Dispense_Transaction__c, etc.).
     * @return SecurityAuditReport with audit verification
     */
    @AuraEnabled(cacheable=true)
    public static SecurityAuditReport auditExternalSharingModels() {
        SecurityAuditReport report = new SecurityAuditReport();

        // Sole Authoritative In-Scope Objects from docs/PA Seed-to-Sale Demo Plan_7.xlsx
        List<String> targetEntities = new List<String>{
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
        };

        for (EntityDefinition entity : [
            SELECT QualifiedApiName, ExternalSharingModel, InternalSharingModel 
            FROM EntityDefinition 
            WHERE QualifiedApiName IN :targetEntities
            ORDER BY QualifiedApiName ASC
        ]) {
            report.totalAudited++;
            // Private or ControlledByParent (for Master-Detail like Recall_Exposure__c) enforce strict isolation
            if (entity.ExternalSharingModel == 'Private' || entity.ExternalSharingModel == 'ControlledByParent') {
                report.privateEntities.add(entity.QualifiedApiName);
            } else {
                report.nonPrivateEntities.add(entity.QualifiedApiName + ' (' + entity.ExternalSharingModel + ')');
                report.allCoreObjectsPrivate = false;
            }
        }
        return report;
    }

    /**
     * @description Checks if a user has access to a specific record.
     * @param recordId Record to inspect
     * @param userId User to check access for
     * @return Boolean true if user has read access
     */
    public static Boolean hasRecordAccess(Id recordId, Id userId) {
        if (recordId == null || userId == null) return false;
        List<UserRecordAccess> accessList = [
            SELECT RecordId, HasReadAccess 
            FROM UserRecordAccess 
            WHERE UserId = :userId AND RecordId = :recordId 
            LIMIT 1
        ];
        return !accessList.isEmpty() && accessList[0].HasReadAccess;
    }
}
