/**
 * @description Idempotent seed script for PA Seed-to-Sale Demo Scene 9 (Retail Counter).
 *              Populates certified patient Robert Stauffer and verified caregiver Linda Stauffer
 *              with practitioner limits and 90-day MMU quota allowances.
 *              Source Baseline: PA Seed-to-Sale Demo Plan_7.xlsx (Scene 9, Dev Task T26).
 * @author Dipankar Sahoo
 */

System.debug('--- Beginning Demo Registry Data Seed ---');

// 1. Seed or Update Patient: Robert Stauffer (PA-PAT-77201)
Patient_Ref__c robert;
List<Patient_Ref__c> existingRobert = [
    SELECT Id, Name, Registry_ID__c, Person_Type__c, Certification_Status__c,
           Practitioner_Limits__c, MMU_Allowance__c, MMU_Used_90_Days__c, MMU_Remaining__c
    FROM Patient_Ref__c
    WHERE Registry_ID__c = 'PA-PAT-77201'
    LIMIT 1
];

if (existingRobert.isEmpty()) {
    robert = new Patient_Ref__c(
        Registry_ID__c = 'PA-PAT-77201'
    );
} else {
    robert = existingRobert[0];
}

robert.Name = 'Robert Stauffer';
robert.Person_Type__c = 'Patient';
robert.Certification_Status__c = 'Active';
robert.Certification_Expiry__c = Date.today().addYears(1);
robert.Address__c = '123 Penn Ave, Harrisburg, PA 17101';
robert.Practitioner_Limits__c = 'No whole flower; vape cartridges and tinctures only';
robert.MMU_Allowance__c = 192.00;
robert.MMU_Used_90_Days__c = 140.00;

upsert robert Registry_ID__c;
System.debug('Seeded Patient: ' + robert.Name + ' [' + robert.Registry_ID__c + '] Id: ' + robert.Id);

// 2. Seed or Update Caregiver: Linda Stauffer (PA-CG-99104)
Patient_Ref__c linda;
List<Patient_Ref__c> existingLinda = [
    SELECT Id, Name, Registry_ID__c, Person_Type__c, Certification_Status__c, Linked_Patient__c
    FROM Patient_Ref__c
    WHERE Registry_ID__c = 'PA-CG-99104'
    LIMIT 1
];

if (existingLinda.isEmpty()) {
    linda = new Patient_Ref__c(
        Registry_ID__c = 'PA-CG-99104'
    );
} else {
    linda = existingLinda[0];
}

linda.Name = 'Linda Stauffer';
linda.Person_Type__c = 'Caregiver';
linda.Certification_Status__c = 'Active';
linda.Certification_Expiry__c = Date.today().addYears(1);
linda.Address__c = '123 Penn Ave, Harrisburg, PA 17101';
linda.Linked_Patient__c = robert.Id;

upsert linda Registry_ID__c;
System.debug('Seeded Caregiver: ' + linda.Name + ' [' + linda.Registry_ID__c + '] linked to Patient Id: ' + robert.Id);

// 3. Verify via Registry Service Verification
RegistryMockRestService.RegistryResponse verifyResp = RegistryMockRestService.verifyRegistryId('PA-CG-99104');
System.debug('--- Live Registry Verification Test ---');
System.debug('Status Code: ' + verifyResp.statusCode);
System.debug('Status: ' + verifyResp.status);
System.debug('Caregiver: ' + verifyResp.caregiverName + ' (' + verifyResp.caregiverId + ')');
System.debug('Patient: ' + verifyResp.patientName + ' (' + verifyResp.patientId + ')');
System.debug('Limits: ' + verifyResp.practitionerLimits);
System.debug('90-Day Allowance: ' + verifyResp.allowanceMMU + ' MMUs');
System.debug('Consumed (90 Days): ' + verifyResp.consumedMMU + ' MMUs');
System.debug('Remaining Balance: ' + verifyResp.remainingMMU + ' MMUs');
System.debug('Registry_Check__c Audit Log Id: ' + verifyResp.registryCheckId);

if (verifyResp.statusCode == '200' && verifyResp.remainingMMU == 52.00) {
    System.debug('SUCCESS: Demo Registry Seed Data verified with exact 52.00 MMU balance!');
} else {
    System.debug('WARNING: Verification response unexpected: ' + verifyResp);
}

