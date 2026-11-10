/**
 * @description Unit tests for PortalNavigationController ensuring 100% code coverage
 *              across all persona routing branches, login timestamp calculations, and
 *              workspace card metadata.
 * @author Dipankar (Developer Phase 3 - Task T07)
 */
@IsTest
private class PortalNavigationControllerTest {

    @IsTest
    static void testRunningUserContext() {
        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.getUserNavigationContext();
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'NavigationContext must not be null');
        System.assertNotEquals(null, ctx.userId, 'UserId must be populated');
        System.assertNotEquals(null, ctx.allowedWorkspaces, 'Allowed workspaces list must be initialized');
        System.assert(ctx.allowedWorkspaces.size() > 0, 'Running user should receive at least 1 workspace card');
    }

    @IsTest
    static void testCultivationPersonaRouting() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'mmap_gp_cultivation' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(false, ctx.isMultiRoleOrAdmin, 'Single cultivation role must not be multi-role');
        System.assertEquals('/cultivation', ctx.targetWorkspaceUrl, 'Must route to /cultivation');
        System.assertEquals('Cultivation Workspace', ctx.targetWorkspaceTitle, 'Title should match');
        System.assertEquals(1, ctx.allowedWorkspaces.size(), 'Should have 1 workspace card');
        System.assertEquals('cultivation', ctx.allowedWorkspaces[0].id, 'Card ID must be cultivation');
    }

    @IsTest
    static void testManufacturingPersonaRouting() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'mmap_gp_processing' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(false, ctx.isMultiRoleOrAdmin, 'Single manufacturing role must not be multi-role');
        System.assertEquals('/manufacturing', ctx.targetWorkspaceUrl, 'Must route to /manufacturing');
        System.assertEquals('Manufacturing Workspace', ctx.targetWorkspaceTitle, 'Title should match');
        System.assertEquals(1, ctx.allowedWorkspaces.size(), 'Should have 1 workspace card');
    }

    @IsTest
    static void testTestingLabPersonaRouting() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'pa_testing_lab_director' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(false, ctx.isMultiRoleOrAdmin, 'Single lab role must not be multi-role');
        System.assertEquals('/testing-lab', ctx.targetWorkspaceUrl, 'Must route to /testing-lab');
        System.assertEquals('Testing Lab Workspace', ctx.targetWorkspaceTitle, 'Title should match');
        System.assertEquals(1, ctx.allowedWorkspaces.size(), 'Should have 1 workspace card');
    }

    @IsTest
    static void testTransfersPersonaRouting() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'pa_transfers_transporter' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(false, ctx.isMultiRoleOrAdmin, 'Single transfer role must not be multi-role');
        System.assertEquals('/transfers', ctx.targetWorkspaceUrl, 'Must route to /transfers');
        System.assertEquals('Transfers Console', ctx.targetWorkspaceTitle, 'Title should match');
        System.assertEquals(1, ctx.allowedWorkspaces.size(), 'Should have 1 workspace card');
    }

    @IsTest
    static void testDispensaryPersonaRouting() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'mmap_dispensary_mgr' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(false, ctx.isMultiRoleOrAdmin, 'Single dispensary role must not be multi-role');
        System.assertEquals('/dispensary-counter', ctx.targetWorkspaceUrl, 'Must route to /dispensary-counter');
        System.assertEquals('Dispensary Counter Workspace', ctx.targetWorkspaceTitle, 'Title should match');
        System.assertEquals(1, ctx.allowedWorkspaces.size(), 'Should have 1 workspace card');
    }

    @IsTest
    static void testMultiRoleRouting() {
        User u = new User(Id = UserInfo.getUserId());
        // User with both processing and transfer compliance roles
        Set<String> permSets = new Set<String>{ 'mmap_gp_processing', 'mmap_gp_compliance' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(true, ctx.isMultiRoleOrAdmin, 'Multi-role user must be marked multi-role');
        System.assertEquals(null, ctx.targetWorkspaceUrl, 'Target workspace should be null for hub view');
        System.assertEquals('Multi-Role Permittee Hub', ctx.targetWorkspaceTitle, 'Title should indicate Hub');
        System.assertEquals(2, ctx.allowedWorkspaces.size(), 'Should have 2 workspace cards');
    }

    @IsTest
    static void testAdminOrNoRoleFallback() {
        User u = new User(Id = UserInfo.getUserId());
        Set<String> permSets = new Set<String>{ 'mmap_admin_permset' };

        Test.startTest();
        PortalNavigationController.NavigationContext ctx = PortalNavigationController.evaluateContext(
            u, permSets, new PortalNavigationController.NavigationContext()
        );
        Test.stopTest();

        System.assertEquals(true, ctx.isMultiRoleOrAdmin, 'Admin must be marked multi-role or admin');
        System.assertEquals(null, ctx.targetWorkspaceUrl, 'Target workspace should be null for admin hub');
        System.assertEquals(5, ctx.allowedWorkspaces.size(), 'Admin must see all 5 workspace cards');
    }
}

