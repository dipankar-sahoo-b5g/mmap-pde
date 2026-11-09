/**
 * @description Seed script for Feature 12: On-Site Regulatory Auditing & Statewide Stop-Sale Quarantine Engine.
 *              Generates:
 *              1. One passing routine audit for Green Thumb Cultivation Center (Score 94, Grade: Pass).
 *              2. One failed unannounced audit for Penn Pure Processing & Extraction enacting an emergency statewide stop-sale order.
 */

// 1. Locate Facilities
Account greenThumb = [
    SELECT Id, Name, Premise_Registry_ID__c, Compliance_Status__c 
    FROM Account 
    WHERE Premise_Registry_ID__c = 'PR-CULT-001' OR Name LIKE '%Green Thumb%' 
    LIMIT 1
];

Account pennPure = [
    SELECT Id, Name, Premise_Registry_ID__c, Compliance_Status__c 
    FROM Account 
    WHERE Premise_Registry_ID__c = 'PR-PROC-002' OR Name LIKE '%Penn Pure%' 
    LIMIT 1
];

// 2. Locate or Create Regulatory Inspector Contact
List<Contact> inspectors = [
    SELECT Id, Name, Email 
    FROM Contact 
    WHERE Stakeholder_Role__c = 'Facility_Agent' OR LastName = 'Cooper' 
    LIMIT 1
];

Contact inspector;
if (!inspectors.isEmpty()) {
    inspector = inspectors[0];
} else {
    inspector = new Contact(
        FirstName = 'Dale',
        LastName = 'Cooper',
        Stakeholder_Role__c = 'Facility_Agent',
        Email = 'dale.cooper@regulatory.state.gov'
    );
    insert inspector;
}

// Clean up any existing audits for clean seeding
delete [SELECT Id FROM Inspection_Audit__c WHERE Facility__c IN (:greenThumb.Id, :pennPure.Id)];

// 3. Create Passing Audit for Green Thumb Cultivation Center
Inspection_Audit__c auditPass = new Inspection_Audit__c(
    Facility__c = greenThumb.Id,
    Inspector__c = inspector.Id,
    Inspection_Type__c = 'Annual Routine',
    Inspection_Date__c = Date.today().addDays(-5),
    Audit_Score__c = 94,
    Compliance_Grade__c = 'Pass',
    Status__c = 'Completed',
    Stop_Sale_Enacted__c = false,
    Summary_Findings__c = 'Full annual routine compliance audit completed. Green Thumb Cultivation Center maintains rigorous statutory controls, RFID inventory reconciliation, and clean lab safety standards. Minor advisories issued regarding scale calibration documentation.'
);
insert auditPass;

List<Audit_Finding__c> passFindings = new List<Audit_Finding__c>{
    new Audit_Finding__c(
        Inspection_Audit__c = auditPass.Id,
        Finding_Category__c = 'Vault Scale Calibration',
        Severity__c = 'Minor',
        Statutory_Fine_Amount__c = 250.00,
        Corrective_Action_Plan__c = 'Re-calibrate vault bench scale #2 with certified Class F calibration mass within 48 hours.',
        Resolved__c = true
    ),
    new Audit_Finding__c(
        Inspection_Audit__c = auditPass.Id,
        Finding_Category__c = 'Sanitation & Hygiene',
        Severity__c = 'Minor',
        Statutory_Fine_Amount__c = 150.00,
        Corrective_Action_Plan__c = 'Post updated biosecurity foot-bath maintenance logs at Grow Bay 3 entryway.',
        Resolved__c = true
    )
};
insert passFindings;

System.debug('Pass Audit Created: ' + auditPass.Id + ' with ' + passFindings.size() + ' findings.');

// 4. Create Failing Audit for Penn Pure Processing & Extraction
Inspection_Audit__c auditFail = new Inspection_Audit__c(
    Facility__c = pennPure.Id,
    Inspector__c = inspector.Id,
    Inspection_Type__c = 'Unannounced Compliance',
    Inspection_Date__c = Date.today(),
    Audit_Score__c = 48,
    Compliance_Grade__c = 'Failed - Immediate Revocation',
    Status__c = 'Completed',
    Stop_Sale_Enacted__c = false,
    Summary_Findings__c = 'Unannounced field compliance inspection conducted following anonymous safety tip. Severe chemical hazards observed: unregistered organophosphate pesticides stored adjacent to commercial extraction equipment. Physical inventory weight reconciliation revealed 1,450.00g unaccounted bulk extract.'
);
insert auditFail;

List<Audit_Finding__c> failFindings = new List<Audit_Finding__c>{
    new Audit_Finding__c(
        Inspection_Audit__c = auditFail.Id,
        Finding_Category__c = 'Pesticide / Chemical Storage',
        Severity__c = 'Critical Violation',
        Statutory_Fine_Amount__c = 25000.00,
        Corrective_Action_Plan__c = 'Immediate hazardous materials quarantine and third-party decontamination of extraction room. Surrender all non-compliant chemicals to State Department of Agriculture.',
        Resolved__c = false
    ),
    new Audit_Finding__c(
        Inspection_Audit__c = auditFail.Id,
        Finding_Category__c = 'Diversion Discrepancy',
        Severity__c = 'Critical Violation',
        Statutory_Fine_Amount__c = 15000.00,
        Corrective_Action_Plan__c = 'Perform full physical vault inventory count with state enforcement officers and provide 30-day uninterrupted NVR video surveillance footage.',
        Resolved__c = false
    ),
    new Audit_Finding__c(
        Inspection_Audit__c = auditFail.Id,
        Finding_Category__c = 'Security & Surveillance',
        Severity__c = 'Major',
        Statutory_Fine_Amount__c = 5000.00,
        Corrective_Action_Plan__c = 'Restore camera blind spot over secondary chemical loading dock within 24 hours.',
        Resolved__c = false
    )
};
insert failFindings;

// 5. Enact Emergency Stop-Sale Quarantine via QuarantineService
Integer quarantinedCount = QuarantineService.enactEmergencyQuarantine(
    auditFail.Id,
    'Immediate life-safety hazard: unregistered organophosphate pesticides stored near extraction bay and critical 1,450g inventory discrepancy.'
);

System.debug('Quarantine Enacted on ' + pennPure.Name + '. Quarantined packages count: ' + quarantinedCount);
System.debug('Feature 12 Demo Seeding Completed Successfully.');
