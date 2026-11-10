/**
 * @description Service to audit and report data isolation across external permittee facilities,
 *              verifying Private Organization-Wide Defaults (OWD) and persona security boundaries
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
     * @description Inspects the live EntityDefinition external sharing models for MMAP supply chain objects.
     * @return SecurityAuditReport with audit verification
     */
    @AuraEnabled(cacheable=true)
    public static SecurityAuditReport auditExternalSharingModels() {
        SecurityAuditReport report = new SecurityAuditReport();
        List<String> targetEntities = new List<String>{
            'Account', 'Tracked_Item__c', 'Plant_Batch__c', 'Product_Package__c',
            'Lab_Result__c', 'Transfer_Manifest__c', 'Dispense_Transaction__c', 'Registry_Check__c'
        };

        for (EntityDefinition entity : [
            SELECT QualifiedApiName, ExternalSharingModel, InternalSharingModel 
            FROM EntityDefinition 
            WHERE QualifiedApiName IN :targetEntities
            ORDER BY QualifiedApiName ASC
        ]) {
            report.totalAudited++;
            if (entity.ExternalSharingModel == 'Private') {
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
