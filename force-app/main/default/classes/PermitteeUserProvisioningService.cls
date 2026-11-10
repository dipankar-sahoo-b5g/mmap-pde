/**
 * @description Service to provision and activate the 5 external login Users on the
 *              Customer Community Plus User profile and assign their corresponding
 *              Persona Permission Sets for Developer Phase 3 (Task T08).
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
public with sharing class PermitteeUserProvisioningService {

    public static final String USERNAME_SUFFIX = '.mmdemo1';

    public class UserProvisioningResult {
        @AuraEnabled public Integer usersCreated;
        @AuraEnabled public Integer usersActivated;
        @AuraEnabled public Integer permSetsAssigned;
        @AuraEnabled public List<String> details;

        public UserProvisioningResult() {
            this.usersCreated = 0;
            this.usersActivated = 0;
            this.permSetsAssigned = 0;
            this.details = new List<String>();
        }
    }

    /**
     * @description Provisions the 5 external Community Plus users and pairs them with their permission sets.
     * @return UserProvisioningResult summary
     */
    public static UserProvisioningResult provisionPermitteeUsers() {
        UserProvisioningResult result = new UserProvisioningResult();

        // 1. Get Profile
        Profile commProfile = [
            SELECT Id, Name 
            FROM Profile 
            WHERE Name = 'Customer Community Plus User' 
            LIMIT 1
        ];

        // 2. Query 5 Contacts
        Map<String, Contact> contactByBadge = new Map<String, Contact>();
        for (Contact c : PermitteeDataFoundationService.getPermitteeContacts()) {
            contactByBadge.put(c.State_ID_Number__c, c);
        }

        // 3. Query Permission Sets
        Map<String, Id> permSetIdMap = new Map<String, Id>();
        for (PermissionSet ps : [
            SELECT Id, Name 
            FROM PermissionSet 
            WHERE Name IN ('MMAP_GP_Cultivation', 'MMAP_GP_Processing', 'MMAP_GP_Compliance', 'MMAP_Lab_Analyst', 'MMAP_Dispensary_Mgr')
        ]) {
            permSetIdMap.put(ps.Name, ps.Id);
        }

        // 4. Query Existing Users by ContactId or Username
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contactByBadge.values()) {
            contactIds.add(c.Id);
        }

        Map<Id, User> existingUsersByContact = new Map<Id, User>();
        for (User u : [
            SELECT Id, ContactId, Username, Email, IsActive 
            FROM User 
            WHERE ContactId IN :contactIds
        ]) {
            existingUsersByContact.put(u.ContactId, u);
        }

        // Persona definitions
        List<PersonaUserConfig> configs = new List<PersonaUserConfig>{
            new PersonaUserConfig('PA-AGT-1001', 'ryan.kowalski.demo@mmap.pa.gov', 'rkowal', 'MMAP_GP_Cultivation'),
            new PersonaUserConfig('PA-AGT-1002', 'megan.schaefer.demo@mmap.pa.gov', 'mschae', 'MMAP_GP_Processing'),
            new PersonaUserConfig('PA-AGT-1003', 'karen.brennan.demo@mmap.pa.gov', 'kbrenn', 'MMAP_GP_Compliance'),
            new PersonaUserConfig('PA-AGT-2001', 'lisa.romano.demo@mmap.pa.gov', 'lroman', 'MMAP_Lab_Analyst'),
            new PersonaUserConfig('PA-AGT-3001', 'brian.gallagher.demo@mmap.pa.gov', 'bgalla', 'MMAP_Dispensary_Mgr')
        };

        List<User> usersToInsert = new List<User>();
        List<User> usersToUpdate = new List<User>();
        Map<String, String> userBadgeToPermSetName = new Map<String, String>();

        for (PersonaUserConfig cfg : configs) {
            Contact c = contactByBadge.get(cfg.badgeId);
            if (c == null) continue;

            String targetUsername = cfg.baseUsername + USERNAME_SUFFIX;
            userBadgeToPermSetName.put(cfg.badgeId, cfg.permSetName);

            if (existingUsersByContact.containsKey(c.Id)) {
                User u = existingUsersByContact.get(c.Id);
                if (!u.IsActive) {
                    u.IsActive = true;
                    usersToUpdate.add(u);
                    result.usersActivated++;
                }
            } else {
                User newUser = new User(
                    ContactId = c.Id,
                    ProfileId = commProfile.Id,
                    Username = targetUsername,
                    Email = c.Email != null ? c.Email : targetUsername,
                    FirstName = c.FirstName,
                    LastName = c.LastName,
                    Alias = cfg.alias,
                    CommunityNickname = cfg.alias + '_' + String.valueOf(Crypto.getRandomInteger()).substring(1, 4),
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'America/New_York',
                    IsActive = true
                );
                usersToInsert.add(newUser);
                result.usersCreated++;
            }
        }

        if (!usersToInsert.isEmpty()) {
            insert usersToInsert;
            for (User u : usersToInsert) {
                existingUsersByContact.put(u.ContactId, u);
            }
        }

        if (!usersToUpdate.isEmpty()) {
            update usersToUpdate;
        }

        // 5. Assign Permission Sets
        Set<Id> allUserIds = new Set<Id>();
        for (User u : existingUsersByContact.values()) {
            allUserIds.add(u.Id);
        }

        Set<String> existingAssignments = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, PermissionSetId 
            FROM PermissionSetAssignment 
            WHERE AssigneeId IN :allUserIds
        ]) {
            existingAssignments.add(psa.AssigneeId + '_' + psa.PermissionSetId);
        }

        List<PermissionSetAssignment> psaToInsert = new List<PermissionSetAssignment>();
        for (PersonaUserConfig cfg : configs) {
            Contact c = contactByBadge.get(cfg.badgeId);
            if (c == null) continue;

            User u = existingUsersByContact.get(c.Id);
            Id permSetId = permSetIdMap.get(cfg.permSetName);

            if (u != null && permSetId != null) {
                String assignmentKey = u.Id + '_' + permSetId;
                if (!existingAssignments.contains(assignmentKey)) {
                    psaToInsert.add(new PermissionSetAssignment(
                        AssigneeId = u.Id,
                        PermissionSetId = permSetId
                    ));
                    result.permSetsAssigned++;
                    result.details.add('Assigned ' + cfg.permSetName + ' to ' + u.Username);
                }
            }
        }

        if (!psaToInsert.isEmpty()) {
            insert psaToInsert;
        }

        return result;
    }

    /**
     * @description Retrieves the 5 provisioned persona users with contact and account details.
     */
    public static List<User> getPermitteeUsers() {
        return [
            SELECT Id, Name, FirstName, LastName, Username, Email, IsActive, Profile.Name, 
                   ContactId, Contact.Name, Contact.Title, Contact.State_ID_Number__c,
                   Contact.AccountId, Contact.Account.Name
            FROM User 
            WHERE Contact.State_ID_Number__c IN ('PA-AGT-1001', 'PA-AGT-1002', 'PA-AGT-1003', 'PA-AGT-2001', 'PA-AGT-3001')
            ORDER BY Contact.State_ID_Number__c ASC
        ];
    }

    private class PersonaUserConfig {
        public String badgeId;
        public String baseUsername;
        public String alias;
        public String permSetName;

        public PersonaUserConfig(String badgeId, String baseUsername, String alias, String permSetName) {
            this.badgeId = badgeId;
            this.baseUsername = baseUsername;
            this.alias = alias;
            this.permSetName = permSetName;
        }
    }
}

