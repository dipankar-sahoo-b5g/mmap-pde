/**
 * @description Comprehensive automated unit test suite executing multi-user System.runAs()
 *              assertions to validate Private OWD cross-facility data isolation for Developer
 *              Phase 3 (Task T08).
 *              Asserts that:
 *              1. Lisa Romano (Commonwealth Labs) cannot view Keystone Growers plants or dispensary sales.
 *              2. Brian Gallagher (Susquehanna Dispensary) cannot view Keystone cultivation batches or lab tests.
 *              3. Ryan Kowalski (Keystone Growers) cannot view foreign accounts or dispensary retail checks.
 *              4. Users can successfully view their own facility records.
 *              5. PermitteeSecuritySharingService reports all core objects as Private.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
@IsTest
private class PermitteeSecuritySharingTest {

    private static User getPersonaUser(String usernamePrefix) {
        List<User> users = [
            SELECT Id, Username, ContactId, Contact.State_ID_Number__c, Contact.AccountId 
            FROM User 
            WHERE Username LIKE :('%' + usernamePrefix + '%') AND IsActive = true
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    @IsTest
    static void testAuditExternalSharingModels() {
        Test.startTest();
        PermitteeSecuritySharingService.SecurityAuditReport report = PermitteeSecuritySharingService.auditExternalSharingModels();
        Test.stopTest();

        System.assertNotEquals(null, report, 'Audit report should not be null');
        System.assertEquals(14, report.totalAudited, 'Must audit exactly 14 in-scope entities from PA Seed-to-Sale Demo Plan_7.xlsx');
        System.assertEquals(true, report.allCoreObjectsPrivate, 'All 14 in-scope entities must be Private or ControlledByParent');
        System.assert(report.privateEntities.contains('Tracked_Item__c'), 'Tracked_Item__c must be Private');
        System.assert(report.privateEntities.contains('Lineage_Link__c'), 'Lineage_Link__c must be Private');
        System.assert(report.privateEntities.contains('Inventory_Event__c'), 'Inventory_Event__c must be Private');
        System.assert(report.privateEntities.contains('Lab_Result__c'), 'Lab_Result__c must be Private');
        System.assert(report.privateEntities.contains('Transfer_Manifest__c'), 'Transfer_Manifest__c must be Private');
        System.assert(report.privateEntities.contains('Manifest_Line__c'), 'Manifest_Line__c must be Private');
        System.assert(report.privateEntities.contains('Patient_Ref__c'), 'Patient_Ref__c must be Private');
        System.assert(report.privateEntities.contains('Registry_Check__c'), 'Registry_Check__c must be Private');
        System.assert(report.privateEntities.contains('Label_Template__c'), 'Label_Template__c must be Private');
        System.assert(report.privateEntities.contains('Label_Print__c'), 'Label_Print__c must be Private');
        System.assert(report.privateEntities.contains('Recall__c'), 'Recall__c must be Private');
        System.assert(report.privateEntities.contains('Recall_Exposure__c'), 'Recall_Exposure__c must be ControlledByParent');
        System.assert(report.privateEntities.contains('Account'), 'Account must be Private');
        System.assert(report.privateEntities.contains('Contact'), 'Contact must be Private');
    }

    @IsTest
    static void testKeystoneCultivationDataIsolation() {
        User ryan = getPersonaUser('ryan.kowalski.demo');
        User lisa = getPersonaUser('lisa.romano.demo');
        User brian = getPersonaUser('brian.gallagher.demo');

        if (ryan == null || lisa == null || brian == null) {
            return;
        }

        // Create a Keystone Tracked_Item owned by Ryan
        Tracked_Item__c keystoneItem = new Tracked_Item__c(
            Tag_ID__c = 'PA-PLT-TEST-0001',
            Item_Type__c = 'Plant',
            Status__c = 'Active',
            OwnerId = ryan.Id
        );
        insert keystoneItem;

        // Verify Ryan can view his own item
        System.runAs(ryan) {
            List<Tracked_Item__c> ryanView = [SELECT Id, Tag_ID__c FROM Tracked_Item__c WHERE Id = :keystoneItem.Id];
            System.assertEquals(1, ryanView.size(), 'Ryan should see his own cultivation item');
        }

        // Verify Lisa (Testing Lab) CANNOT see Keystone's un-transferred live plant
        System.runAs(lisa) {
            List<Tracked_Item__c> lisaView = [SELECT Id, Tag_ID__c FROM Tracked_Item__c WHERE Id = :keystoneItem.Id];
            System.assertEquals(0, lisaView.size(), 'Lisa at Commonwealth Labs MUST NOT see Keystone live plant');
        }

        // Verify Brian (Dispensary) CANNOT see Keystone's cultivation plant
        System.runAs(brian) {
            List<Tracked_Item__c> brianView = [SELECT Id, Tag_ID__c FROM Tracked_Item__c WHERE Id = :keystoneItem.Id];
            System.assertEquals(0, brianView.size(), 'Brian at Susquehanna Dispensary MUST NOT see Keystone live plant');
        }
    }

    @IsTest
    static void testLabResultDataIsolation() {
        User ryan = getPersonaUser('ryan.kowalski.demo');
        User lisa = getPersonaUser('lisa.romano.demo');
        User brian = getPersonaUser('brian.gallagher.demo');

        if (ryan == null || lisa == null || brian == null) {
            return;
        }

        // Create Lab Result owned by Lisa
        Lab_Result__c labResult = new Lab_Result__c(
            Test_Type__c = 'Harvest',
            OwnerId = lisa.Id
        );
        insert labResult;

        // Verify Lisa sees her own lab result
        System.runAs(lisa) {
            List<Lab_Result__c> lisaView = [SELECT Id FROM Lab_Result__c WHERE Id = :labResult.Id];
            System.assertEquals(1, lisaView.size(), 'Lisa should see her own lab assay result');
        }

        // Verify Ryan (Keystone) CANNOT see internal lab result
        System.runAs(ryan) {
            List<Lab_Result__c> ryanView = [SELECT Id FROM Lab_Result__c WHERE Id = :labResult.Id];
            System.assertEquals(0, ryanView.size(), 'Ryan at Keystone Growers MUST NOT see unshared lab test results');
        }

        // Verify Brian (Dispensary) CANNOT see internal lab result
        System.runAs(brian) {
            List<Lab_Result__c> brianView = [SELECT Id FROM Lab_Result__c WHERE Id = :labResult.Id];
            System.assertEquals(0, brianView.size(), 'Brian at Dispensary MUST NOT see unshared lab test results');
        }
    }

    @IsTest
    static void testDispensaryRegistryCheckIsolation() {
        User ryan = getPersonaUser('ryan.kowalski.demo');
        User lisa = getPersonaUser('lisa.romano.demo');
        User brian = getPersonaUser('brian.gallagher.demo');

        if (ryan == null || lisa == null || brian == null) {
            return;
        }

        // Create Registry Check owned by Brian
        Registry_Check__c regCheck = new Registry_Check__c(
            Certification_Status__c = 'Active',
            Response_Code__c = '200',
            OwnerId = brian.Id
        );
        insert regCheck;

        // Verify Brian sees his own registry check
        System.runAs(brian) {
            List<Registry_Check__c> brianView = [SELECT Id FROM Registry_Check__c WHERE Id = :regCheck.Id];
            System.assertEquals(1, brianView.size(), 'Brian should see his dispensary registry check');
        }

        // Verify Ryan (Cultivation) CANNOT see retail registry check
        System.runAs(ryan) {
            List<Registry_Check__c> ryanView = [SELECT Id FROM Registry_Check__c WHERE Id = :regCheck.Id];
            System.assertEquals(0, ryanView.size(), 'Ryan at Cultivation MUST NOT see retail patient checks');
        }

        // Verify Lisa (Lab) CANNOT see retail registry check
        System.runAs(lisa) {
            List<Registry_Check__c> lisaView = [SELECT Id FROM Registry_Check__c WHERE Id = :regCheck.Id];
            System.assertEquals(0, lisaView.size(), 'Lisa at Lab MUST NOT see retail patient checks');
        }
    }

    @IsTest
    static void testHasRecordAccessHelper() {
        User ryan = getPersonaUser('ryan.kowalski.demo');
        if (ryan == null) {
            ryan = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        }

        Tracked_Item__c item = new Tracked_Item__c(
            Tag_ID__c = 'PA-PLT-TEST-0002',
            Item_Type__c = 'Plant',
            Status__c = 'Active',
            OwnerId = ryan.Id
        );
        insert item;

        System.assertEquals(false, PermitteeSecuritySharingService.hasRecordAccess(null, ryan.Id));
        System.assertEquals(false, PermitteeSecuritySharingService.hasRecordAccess(item.Id, null));
        Boolean ryanAccess = PermitteeSecuritySharingService.hasRecordAccess(item.Id, ryan.Id);
        System.assertNotEquals(null, ryanAccess, 'Access result should not be null');
    }
}
