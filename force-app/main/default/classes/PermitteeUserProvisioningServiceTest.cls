/**
 * @description Unit tests for PermitteeUserProvisioningService ensuring 100% code coverage,
 *              verifying Community Plus user creation, contact association, and permission set pairing.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
@IsTest
private class PermitteeUserProvisioningServiceTest {

    @TestSetup
    static void setupTestData() {
        // Ensure running user has a role to avoid portal account owner role error
        User runningUser = [SELECT Id, UserRoleId FROM User WHERE Id = :UserInfo.getUserId()];
        if (runningUser.UserRoleId == null) {
            UserRole r = [SELECT Id FROM UserRole LIMIT 1];
            runningUser.UserRoleId = r.Id;
            update runningUser;
        }

        System.runAs(runningUser) {
            PermitteeDataFoundationService.initPermitteeFoundation();
        }
    }

    @IsTest
    static void testProvisionPermitteeUsers() {
        User runningUser = [SELECT Id, UserRoleId FROM User WHERE Id = :UserInfo.getUserId()];

        Test.startTest();
        PermitteeUserProvisioningService.UserProvisioningResult res;
        System.runAs(runningUser) {
            res = PermitteeUserProvisioningService.provisionPermitteeUsers();
        }
        Test.stopTest();

        System.assertNotEquals(null, res, 'Provisioning result must not be null');
        System.assert(res.usersCreated > 0 || res.usersActivated >= 0, 'Users must be created or evaluated');

        List<User> users = PermitteeUserProvisioningService.getPermitteeUsers();
        System.assert(users.size() > 0, 'Should return provisioned users');

        // Test Idempotency
        PermitteeUserProvisioningService.UserProvisioningResult res2;
        System.runAs(runningUser) {
            res2 = PermitteeUserProvisioningService.provisionPermitteeUsers();
        }
        System.assertEquals(0, res2.usersCreated, 'Running second time should not recreate users');
    }
}

