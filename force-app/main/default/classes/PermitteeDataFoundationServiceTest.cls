/**
 * @description Unit tests for PermitteeDataFoundationService ensuring 100% code coverage,
 *              verifying Account and Contact provisioning, record linkage, and idempotent execution.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
@IsTest
private class PermitteeDataFoundationServiceTest {

    @IsTest
    static void testInitPermitteeFoundation() {
        Test.startTest();
        PermitteeDataFoundationService.FoundationResult res1 = PermitteeDataFoundationService.initPermitteeFoundation();
        Test.stopTest();

        System.assertNotEquals(null, res1, 'Result must not be null');
        System.assertEquals(3, res1.accountsProvisioned, 'Must provision 3 accounts');
        System.assertEquals(5, res1.contactsProvisioned, 'Must provision 5 contacts');

        List<Account> accounts = PermitteeDataFoundationService.getPermitteeAccounts();
        System.assertEquals(3, accounts.size(), 'Should return exactly 3 accounts');

        Map<String, Account> accByRegistryId = new Map<String, Account>();
        for (Account a : accounts) {
            accByRegistryId.put(a.Premise_Registry_ID__c, a);
        }

        System.assert(accByRegistryId.containsKey('PR-GP-001'), 'Must include Keystone Growers');
        System.assertEquals('Grower_Processor', accByRegistryId.get('PR-GP-001').Facility_Type__c);
        System.assertEquals('GP-2024-001', accByRegistryId.get('PR-GP-001').Permit_Number__c);

        System.assert(accByRegistryId.containsKey('PR-LAB-002'), 'Must include Commonwealth Labs');
        System.assertEquals('Testing_Laboratory', accByRegistryId.get('PR-LAB-002').Facility_Type__c);
        System.assertEquals('LAB-2024-003', accByRegistryId.get('PR-LAB-002').Permit_Number__c);

        System.assert(accByRegistryId.containsKey('PR-DISP-003'), 'Must include Susquehanna Dispensary');
        System.assertEquals('Dispensary', accByRegistryId.get('PR-DISP-003').Facility_Type__c);
        System.assertEquals('DISP-2024-002', accByRegistryId.get('PR-DISP-003').Permit_Number__c);

        List<Contact> contacts = PermitteeDataFoundationService.getPermitteeContacts();
        System.assertEquals(5, contacts.size(), 'Should return exactly 5 contacts');

        Map<String, Contact> contactByTag = new Map<String, Contact>();
        for (Contact c : contacts) {
            contactByTag.put(c.State_ID_Number__c, c);
        }

        // Validate Ryan Kowalski
        Contact ryan = contactByTag.get('PA-AGT-1001');
        System.assertEquals('Ryan', ryan.FirstName);
        System.assertEquals('Kowalski', ryan.LastName);
        System.assertEquals('Cultivation Lead', ryan.Title);
        System.assertEquals('Facility_Agent', ryan.Stakeholder_Role__c);
        System.assertEquals(accByRegistryId.get('PR-GP-001').Id, ryan.AccountId);

        // Validate Megan Schaefer
        Contact megan = contactByTag.get('PA-AGT-1002');
        System.assertEquals('Megan', megan.FirstName);
        System.assertEquals('Processing Lead', megan.Title);
        System.assertEquals(accByRegistryId.get('PR-GP-001').Id, megan.AccountId);

        // Validate Karen Brennan
        Contact karen = contactByTag.get('PA-AGT-1003');
        System.assertEquals('Karen', karen.FirstName);
        System.assertEquals('Compliance Manager', karen.Title);
        System.assertEquals(accByRegistryId.get('PR-GP-001').Id, karen.AccountId);

        // Validate Lisa Romano
        Contact lisa = contactByTag.get('PA-AGT-2001');
        System.assertEquals('Lisa', lisa.FirstName);
        System.assertEquals('Lab Analyst', lisa.Title);
        System.assertEquals(accByRegistryId.get('PR-LAB-002').Id, lisa.AccountId);

        // Validate Brian Gallagher
        Contact brian = contactByTag.get('PA-AGT-3001');
        System.assertEquals('Brian', brian.FirstName);
        System.assertEquals('Dispensary Manager', brian.Title);
        System.assertEquals(accByRegistryId.get('PR-DISP-003').Id, brian.AccountId);

        // Test Idempotency (running second time should update without duplicating)
        PermitteeDataFoundationService.FoundationResult res2 = PermitteeDataFoundationService.initPermitteeFoundation();
        System.assertEquals(3, res2.accountsProvisioned);
        System.assertEquals(5, res2.contactsProvisioned);
        System.assertEquals(3, PermitteeDataFoundationService.getPermitteeAccounts().size());
        System.assertEquals(5, PermitteeDataFoundationService.getPermitteeContacts().size());
    }
}

