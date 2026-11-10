/**
 * @description Anonymous Apex execution script to provision and activate the 5 external
 *              login Users on the Customer Community Plus User profile and pair them with
 *              their operational Persona Permission Sets for Developer Phase 3 (Task T08).
 * @author Dipankar
 */
PermitteeUserProvisioningService.UserProvisioningResult result = PermitteeUserProvisioningService.provisionPermitteeUsers();

System.debug('====================================================');
System.debug('PERMITTEE USER PROVISIONING COMPLETE');
System.debug('Users Created: ' + result.usersCreated);
System.debug('Users Activated: ' + result.usersActivated);
System.debug('Permission Sets Assigned: ' + result.permSetsAssigned);
System.debug('====================================================');

for (String d : result.details) {
    System.debug('Detail: ' + d);
}

for (User u : PermitteeUserProvisioningService.getPermitteeUsers()) {
    System.debug('User: ' + u.Name + ' | Username: ' + u.Username + ' | Active: ' + u.IsActive + ' | Profile: ' + u.Profile.Name + ' | Org: ' + u.Contact.Account.Name + ' | ID: ' + u.Id);
}

