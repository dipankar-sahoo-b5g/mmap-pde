/**
 * @description Regulatory service governing statewide emergency stop-sale quarantine orders,
 *              facility compliance status suspensions, and batch/package lockouts.
 */
public with sharing class QuarantineService {

    /**
     * @description Helper to construct AuraHandledException with explicit message.
     * @param message Error message text.
     * @return AuraHandledException instance.
     */
    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * @description Enacts an emergency statewide stop-sale quarantine order on a licensed facility following an inspection audit.
     *              1. Updates Inspection_Audit__c: Status = 'Quarantine Enacted', Stop_Sale_Enacted = true, Stop_Sale_Timestamp = now.
     *              2. Updates Account: Compliance_Status__c = 'Suspended'.
     *              3. Updates all Product_Package__c held by the facility: Status__c = 'Quarantined', Package_Status__c = 'Quarantined', Lab_Safety_Status__c = 'Failed'.
     * @param auditId The ID of the Inspection_Audit__c record.
     * @param reason Mandatory or statutory rationale explaining the emergency stop-sale order.
     * @return Integer number of inventory product packages locked down and quarantined.
     */
    public static Integer enactEmergencyQuarantine(Id auditId, String reason) {
        if (auditId == null) {
            throw createAuraException('Inspection Audit ID is required to enact an emergency stop-sale order.');
        }

        List<Inspection_Audit__c> audits = [
            SELECT Id, Facility__c, Facility__r.Name, Status__c, Stop_Sale_Enacted__c, 
                   Stop_Sale_Timestamp__c, Summary_Findings__c
            FROM Inspection_Audit__c
            WHERE Id = :auditId
            WITH USER_MODE
            LIMIT 1
        ];

        if (audits.isEmpty()) {
            throw createAuraException('Inspection Audit record not found with ID: ' + auditId);
        }

        Inspection_Audit__c audit = audits[0];
        Id facilityId = audit.Facility__c;
        if (facilityId == null) {
            throw createAuraException('No regulated facility is associated with this inspection audit.');
        }

        // 1. Update Inspection_Audit__c record
        audit.Status__c = 'Quarantine Enacted';
        audit.Stop_Sale_Enacted__c = true;
        audit.Stop_Sale_Timestamp__c = DateTime.now();

        String quarantineNote = '[' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + ' EMERGENCY STOP-SALE ORDER ENACTED] ' + 
            (String.isNotBlank(reason) ? reason : 'Immediate health and safety hazard identified.');
        
        audit.Summary_Findings__c = String.isNotBlank(audit.Summary_Findings__c) 
            ? audit.Summary_Findings__c + '\n\n' + quarantineNote 
            : quarantineNote;

        update as user audit;

        // 2. Suspend commercial facility compliance standing
        List<Account> facilities = [
            SELECT Id, Name, Compliance_Status__c
            FROM Account
            WHERE Id = :facilityId
            WITH USER_MODE
            LIMIT 1
        ];

        if (!facilities.isEmpty()) {
            facilities[0].Compliance_Status__c = 'Suspended';
            update as user facilities[0];
        }

        // 3. Lock down all commercial inventory packages at facility
        List<Product_Package__c> packagesToQuarantine = [
            SELECT Id, Status__c, Package_Status__c, Lab_Safety_Status__c, Holding_Facility__c
            FROM Product_Package__c
            WHERE Holding_Facility__c = :facilityId
            WITH USER_MODE
        ];

        for (Product_Package__c pkg : packagesToQuarantine) {
            pkg.Status__c = 'Quarantined';
            pkg.Package_Status__c = 'Quarantined';
            pkg.Lab_Safety_Status__c = 'Failed';
        }

        if (!packagesToQuarantine.isEmpty()) {
            update as user packagesToQuarantine;
        }

        return packagesToQuarantine.size();
    }

    /**
     * @description Lifts an emergency stop-sale quarantine order following satisfactory remediation.
     *              1. Restores Inspection_Audit__c: Status = 'Completed', Stop_Sale_Enacted = false.
     *              2. Restores Account: Compliance_Status__c = 'Compliant'.
     * @param auditId The ID of the Inspection_Audit__c record.
     * @param reason The verified statutory remediation justification.
     * @return Boolean true if the order was successfully lifted.
     */
    public static Boolean liftQuarantine(Id auditId, String reason) {
        if (auditId == null) {
            throw createAuraException('Inspection Audit ID is required to lift an emergency stop-sale order.');
        }

        List<Inspection_Audit__c> audits = [
            SELECT Id, Facility__c, Status__c, Stop_Sale_Enacted__c, Summary_Findings__c
            FROM Inspection_Audit__c
            WHERE Id = :auditId
            WITH USER_MODE
            LIMIT 1
        ];

        if (audits.isEmpty()) {
            throw createAuraException('Inspection Audit record not found with ID: ' + auditId);
        }

        Inspection_Audit__c audit = audits[0];
        Id facilityId = audit.Facility__c;

        audit.Status__c = 'Completed';
        audit.Stop_Sale_Enacted__c = false;

        String liftNote = '[' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + ' QUARANTINE ORDER RESCINDED/LIFTED] ' +
            (String.isNotBlank(reason) ? reason : 'Corrective action plan verified by Commonwealth regulators.');

        audit.Summary_Findings__c = String.isNotBlank(audit.Summary_Findings__c) 
            ? audit.Summary_Findings__c + '\n\n' + liftNote 
            : liftNote;

        update as user audit;

        // Restore facility standing to Compliant
        if (facilityId != null) {
            List<Account> facilities = [
                SELECT Id, Name, Compliance_Status__c
                FROM Account
                WHERE Id = :facilityId
                WITH USER_MODE
                LIMIT 1
            ];

            if (!facilities.isEmpty()) {
                facilities[0].Compliance_Status__c = 'Compliant';
                update as user facilities[0];
            }
        }

        return true;
    }
}
