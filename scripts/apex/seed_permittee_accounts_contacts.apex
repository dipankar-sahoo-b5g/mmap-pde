/**
 * @description Anonymous Apex execution script to initialize the 3 commercial permittee
 *              Accounts and 5 external persona Contacts for Demo Phase 3 (Tasks T07 & T08).
 * @author Dipankar
 */
PermitteeDataFoundationService.FoundationResult result = PermitteeDataFoundationService.initPermitteeFoundation();

System.debug('====================================================');
System.debug('PERMITTEE DATA FOUNDATION INITIALIZATION COMPLETE');
System.debug('Accounts Provisioned: ' + result.accountsProvisioned);
System.debug('Contacts Provisioned: ' + result.contactsProvisioned);
System.debug('====================================================');

for (Account acc : PermitteeDataFoundationService.getPermitteeAccounts()) {
    System.debug('Account: ' + acc.Name + ' | Type: ' + acc.Facility_Type__c + ' | Permit: ' + acc.Permit_Number__c + ' | ID: ' + acc.Id);
}

for (Contact con : PermitteeDataFoundationService.getPermitteeContacts()) {
    System.debug('Contact: ' + con.Name + ' | Title: ' + con.Title + ' | Org: ' + con.Account.Name + ' | State ID: ' + con.State_ID_Number__c + ' | ID: ' + con.Id);
}

