/**
 * @description Controller for On-Site Regulatory Auditing, Field Inspection Scorecards,
 *              and Statewide Emergency Stop-Sale Quarantine actions.
 */
public with sharing class InspectionAuditController {

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
     * @description DTO wrapper for Audit details including aggregated finding statistics.
     */
    public class AuditSummaryWrapper {
        @AuraEnabled public Inspection_Audit__c audit { get; set; }
        @AuraEnabled public Integer totalFindings { get; set; }
        @AuraEnabled public Integer criticalFindings { get; set; }
        @AuraEnabled public Integer unresolvedFindings { get; set; }
        @AuraEnabled public Decimal totalFinesAssessed { get; set; }
    }

    /**
     * @description Retrieves recent Inspection Audit records with facility, inspector, and child findings.
     * @return List of Inspection_Audit__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Inspection_Audit__c> getAudits() {
        return [
            SELECT Id, Name, Facility__c, Facility__r.Name, Facility__r.Premise_Registry_ID__c, Facility__r.Compliance_Status__c,
                   Inspector__c, Inspector__r.Name, Inspection_Date__c, Inspection_Type__c,
                   Audit_Score__c, Compliance_Grade__c, Status__c,
                   Stop_Sale_Enacted__c, Stop_Sale_Timestamp__c, Summary_Findings__c, CreatedDate,
                   (SELECT Id, Name, Finding_Category__c, Severity__c, Statutory_Fine_Amount__c, Corrective_Action_Plan__c, Resolved__c 
                    FROM Audit_Findings__r ORDER BY CreatedDate ASC)
            FROM Inspection_Audit__c
            WITH USER_MODE
            ORDER BY Inspection_Date__c DESC, CreatedDate DESC
            LIMIT 100
        ];
    }

    /**
     * @description Retrieves detailed information for a specific audit along with its findings.
     * @param auditId The ID of the Inspection_Audit__c record.
     * @return AuditSummaryWrapper containing full audit record and aggregated metrics.
     */
    @AuraEnabled
    public static AuditSummaryWrapper getAuditDetails(Id auditId) {
        if (auditId == null) {
            throw createAuraException('Inspection Audit ID cannot be null.');
        }

        List<Inspection_Audit__c> audits = [
            SELECT Id, Name, Facility__c, Facility__r.Name, Facility__r.Premise_Registry_ID__c, Facility__r.Compliance_Status__c,
                   Inspector__c, Inspector__r.Name, Inspection_Date__c, Inspection_Type__c,
                   Audit_Score__c, Compliance_Grade__c, Status__c,
                   Stop_Sale_Enacted__c, Stop_Sale_Timestamp__c, Summary_Findings__c, CreatedDate,
                   (SELECT Id, Name, Finding_Category__c, Severity__c, Statutory_Fine_Amount__c, Corrective_Action_Plan__c, Resolved__c, CreatedDate 
                    FROM Audit_Findings__r ORDER BY CreatedDate ASC)
            FROM Inspection_Audit__c
            WHERE Id = :auditId
            WITH USER_MODE
            LIMIT 1
        ];

        if (audits.isEmpty()) {
            throw createAuraException('Inspection Audit not found with ID: ' + auditId);
        }

        Inspection_Audit__c aud = audits[0];
        AuditSummaryWrapper summary = new AuditSummaryWrapper();
        summary.audit = aud;
        summary.totalFindings = aud.Audit_Findings__r != null ? aud.Audit_Findings__r.size() : 0;
        summary.criticalFindings = 0;
        summary.unresolvedFindings = 0;
        summary.totalFinesAssessed = 0.00;

        if (aud.Audit_Findings__r != null) {
            for (Audit_Finding__c f : aud.Audit_Findings__r) {
                if (f.Severity__c == 'Critical Violation') {
                    summary.criticalFindings++;
                }
                if (!f.Resolved__c) {
                    summary.unresolvedFindings++;
                }
                if (f.Statutory_Fine_Amount__c != null) {
                    summary.totalFinesAssessed += f.Statutory_Fine_Amount__c;
                }
            }
        }

        return summary;
    }

    /**
     * @description Creates a new Inspection Audit record with calculated grade and associated findings.
     * @param facilityId Regulated facility Account ID.
     * @param inspectorId Regulatory inspector Contact ID.
     * @param auditType Categorical classification of the inspection.
     * @param auditDate Calendar date of inspection.
     * @param score Overall audit compliance score (0-100).
     * @param summaryNotes Executive summary narrative.
     * @param findings List of child Audit_Finding__c records to associate.
     * @return The newly created Inspection_Audit__c record.
     */
    @AuraEnabled
    public static Inspection_Audit__c createAudit(
        Id facilityId,
        Id inspectorId,
        String auditType,
        Date auditDate,
        Decimal score,
        String summaryNotes,
        List<Audit_Finding__c> findings
    ) {
        if (facilityId == null) {
            throw createAuraException('Regulated Facility is mandatory.');
        }
        if (String.isBlank(auditType)) {
            throw createAuraException('Inspection Type is mandatory.');
        }
        if (auditDate == null) {
            throw createAuraException('Inspection Date is mandatory.');
        }

        // Determine Compliance Grade automatically based on score
        String complianceGrade = null;
        if (score != null) {
            if (score >= 85) {
                complianceGrade = 'Pass';
            } else if (score >= 70) {
                complianceGrade = 'Conditional Pass';
            } else {
                complianceGrade = 'Failed - Immediate Revocation';
            }
        }

        Inspection_Audit__c newAudit = new Inspection_Audit__c(
            Facility__c = facilityId,
            Inspector__c = inspectorId,
            Inspection_Type__c = auditType,
            Inspection_Date__c = auditDate,
            Audit_Score__c = score,
            Compliance_Grade__c = complianceGrade,
            Status__c = (score != null ? 'Completed' : 'Scheduled'),
            Stop_Sale_Enacted__c = false,
            Summary_Findings__c = summaryNotes
        );

        insert as user newAudit;

        // Insert child findings if present
        if (findings != null && !findings.isEmpty()) {
            List<Audit_Finding__c> findingsToInsert = new List<Audit_Finding__c>();
            for (Audit_Finding__c f : findings) {
                Audit_Finding__c child = new Audit_Finding__c(
                    Inspection_Audit__c = newAudit.Id,
                    Finding_Category__c = f.Finding_Category__c,
                    Severity__c = f.Severity__c,
                    Statutory_Fine_Amount__c = f.Statutory_Fine_Amount__c,
                    Corrective_Action_Plan__c = f.Corrective_Action_Plan__c,
                    Resolved__c = (f.Resolved__c == true)
                );
                findingsToInsert.add(child);
            }
            insert as user findingsToInsert;
        }

        return [
            SELECT Id, Name, Facility__c, Facility__r.Name, Inspector__c, Inspector__r.Name,
                   Inspection_Date__c, Inspection_Type__c, Audit_Score__c, Compliance_Grade__c,
                   Status__c, Stop_Sale_Enacted__c, Stop_Sale_Timestamp__c, Summary_Findings__c
            FROM Inspection_Audit__c
            WHERE Id = :newAudit.Id
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /**
     * @description Enacts an emergency statewide stop-sale order via QuarantineService.
     * @param auditId The ID of the Inspection_Audit__c.
     * @param reason The statutory rationale for the quarantine order.
     * @return Integer count of quarantined packages.
     */
    @AuraEnabled
    public static Integer enactStopSale(Id auditId, String reason) {
        return QuarantineService.enactEmergencyQuarantine(auditId, reason);
    }

    /**
     * @description Rescinds an emergency statewide stop-sale order via QuarantineService.
     * @param auditId The ID of the Inspection_Audit__c.
     * @param reason The verified corrective justification.
     * @return Boolean true if quarantine lifted.
     */
    @AuraEnabled
    public static Boolean liftStopSale(Id auditId, String reason) {
        return QuarantineService.liftQuarantine(auditId, reason);
    }

    /**
     * @description Retrieves licensed commercial facilities for dropdown selection.
     * @return List of Account facilities.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getFacilities() {
        return [
            SELECT Id, Name, Facility_Type__c, Premise_Registry_ID__c, Compliance_Status__c
            FROM Account
            WHERE Facility_Type__c != null
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    /**
     * @description Retrieves available regulatory inspectors and facility agents for dropdown selection.
     * @return List of Contact records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getInspectors() {
        return [
            SELECT Id, Name, Stakeholder_Role__c, Email
            FROM Contact
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 200
        ];
    }
}
