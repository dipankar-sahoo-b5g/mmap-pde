/**
 * @description Foundation service to provision, link, and audit authoritative commercial
 *              permittee Accounts and external Contacts for Developer Phase 3 (Tasks T07 & T08).
 *              Establishes the data foundation required for Community Plus user licensing,
 *              private OWD record ownership, and persona workspace isolation.
 * @author Dipankar (Developer Phase 3 - Task T08)
 */
public with sharing class PermitteeDataFoundationService {

    public static final String KEYSTONE_REGISTRY_ID = 'PR-GP-001';
    public static final String COMMONWEALTH_LABS_REGISTRY_ID = 'PR-LAB-002';
    public static final String SUSQUEHANNA_DISP_REGISTRY_ID = 'PR-DISP-003';

    public class FoundationResult {
        @AuraEnabled public Integer accountsProvisioned;
        @AuraEnabled public Integer contactsProvisioned;
        @AuraEnabled public Map<String, Id> accountMap;
        @AuraEnabled public Map<String, Id> contactMap;

        public FoundationResult() {
            this.accountMap = new Map<String, Id>();
            this.contactMap = new Map<String, Id>();
        }
    }

    /**
     * @description Provisions or updates the 3 primary permittee Accounts and 5 external Contacts.
     * @return FoundationResult summary containing generated IDs
     */
    public static FoundationResult initPermitteeFoundation() {
        FoundationResult result = new FoundationResult();

        // 1. Provision / Upsert Accounts
        List<Account> accountsToUpsert = new List<Account>();

        Account keystone = new Account(
            Name = 'Keystone Growers',
            Facility_Type__c = 'Grower_Processor',
            Permit_Number__c = 'GP-2024-001',
            Premise_Registry_ID__c = KEYSTONE_REGISTRY_ID,
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 500000.00,
            BillingStreet = '100 Industrial Parkway',
            BillingCity = 'Harrisburg',
            BillingState = 'PA',
            BillingPostalCode = '17101',
            BillingCountry = 'USA'
        );
        accountsToUpsert.add(keystone);

        Account lab = new Account(
            Name = 'Commonwealth Labs',
            Facility_Type__c = 'Testing_Laboratory',
            Permit_Number__c = 'LAB-2024-003',
            Premise_Registry_ID__c = COMMONWEALTH_LABS_REGISTRY_ID,
            Compliance_Status__c = 'Compliant',
            BillingStreet = '250 Science Center Blvd',
            BillingCity = 'State College',
            BillingState = 'PA',
            BillingPostalCode = '16801',
            BillingCountry = 'USA'
        );
        accountsToUpsert.add(lab);

        Account dispensary = new Account(
            Name = 'Susquehanna Dispensary',
            Facility_Type__c = 'Dispensary',
            Permit_Number__c = 'DISP-2024-002',
            Premise_Registry_ID__c = SUSQUEHANNA_DISP_REGISTRY_ID,
            Compliance_Status__c = 'Compliant',
            BillingStreet = '400 Market Street',
            BillingCity = 'York',
            BillingState = 'PA',
            BillingPostalCode = '17401',
            BillingCountry = 'USA'
        );
        accountsToUpsert.add(dispensary);

        upsert accountsToUpsert Premise_Registry_ID__c;

        for (Account a : accountsToUpsert) {
            result.accountMap.put(a.Premise_Registry_ID__c, a.Id);
        }
        result.accountsProvisioned = accountsToUpsert.size();

        // 2. Provision / Upsert 5 External Contacts
        Id keystoneId = result.accountMap.get(KEYSTONE_REGISTRY_ID);
        Id labId = result.accountMap.get(COMMONWEALTH_LABS_REGISTRY_ID);
        Id dispId = result.accountMap.get(SUSQUEHANNA_DISP_REGISTRY_ID);

        Map<String, Contact> existingContactsMap = new Map<String, Contact>();
        for (Contact c : [
            SELECT Id, FirstName, LastName, Email, State_ID_Number__c 
            FROM Contact 
            WHERE State_ID_Number__c IN ('PA-AGT-1001', 'PA-AGT-1002', 'PA-AGT-1003', 'PA-AGT-2001', 'PA-AGT-3001')
        ]) {
            existingContactsMap.put(c.State_ID_Number__c, c);
        }

        List<Contact> contactsToUpsert = new List<Contact>();

        // Persona 1: Ryan Kowalski (Cultivation Lead)
        Contact ryan = existingContactsMap.containsKey('PA-AGT-1001') 
            ? existingContactsMap.get('PA-AGT-1001') 
            : new Contact(State_ID_Number__c = 'PA-AGT-1001');
        ryan.FirstName = 'Ryan';
        ryan.LastName = 'Kowalski';
        ryan.AccountId = keystoneId;
        ryan.Title = 'Cultivation Lead';
        ryan.Email = 'ryan.kowalski@keystonegrowers.pa.demo';
        ryan.Stakeholder_Role__c = 'Facility_Agent';
        contactsToUpsert.add(ryan);

        // Persona 2: Megan Schaefer (Processing Lead)
        Contact megan = existingContactsMap.containsKey('PA-AGT-1002') 
            ? existingContactsMap.get('PA-AGT-1002') 
            : new Contact(State_ID_Number__c = 'PA-AGT-1002');
        megan.FirstName = 'Megan';
        megan.LastName = 'Schaefer';
        megan.AccountId = keystoneId;
        megan.Title = 'Processing Lead';
        megan.Email = 'megan.schaefer@keystonegrowers.pa.demo';
        megan.Stakeholder_Role__c = 'Facility_Agent';
        contactsToUpsert.add(megan);

        // Persona 3: Karen Brennan (Compliance Manager)
        Contact karen = existingContactsMap.containsKey('PA-AGT-1003') 
            ? existingContactsMap.get('PA-AGT-1003') 
            : new Contact(State_ID_Number__c = 'PA-AGT-1003');
        karen.FirstName = 'Karen';
        karen.LastName = 'Brennan';
        karen.AccountId = keystoneId;
        karen.Title = 'Compliance Manager';
        karen.Email = 'karen.brennan@keystonegrowers.pa.demo';
        karen.Stakeholder_Role__c = 'Facility_Agent';
        contactsToUpsert.add(karen);

        // Persona 4: Lisa Romano (Lab Analyst)
        Contact lisa = existingContactsMap.containsKey('PA-AGT-2001') 
            ? existingContactsMap.get('PA-AGT-2001') 
            : new Contact(State_ID_Number__c = 'PA-AGT-2001');
        lisa.FirstName = 'Lisa';
        lisa.LastName = 'Romano';
        lisa.AccountId = labId;
        lisa.Title = 'Lab Analyst';
        lisa.Email = 'lisa.romano@commonwealthlabs.pa.demo';
        lisa.Stakeholder_Role__c = 'Facility_Agent';
        contactsToUpsert.add(lisa);

        // Persona 5: Brian Gallagher (Dispensary Manager)
        Contact brian = existingContactsMap.containsKey('PA-AGT-3001') 
            ? existingContactsMap.get('PA-AGT-3001') 
            : new Contact(State_ID_Number__c = 'PA-AGT-3001');
        brian.FirstName = 'Brian';
        brian.LastName = 'Gallagher';
        brian.AccountId = dispId;
        brian.Title = 'Dispensary Manager';
        brian.Email = 'brian.gallagher@susquehannadisp.pa.demo';
        brian.Stakeholder_Role__c = 'Facility_Agent';
        contactsToUpsert.add(brian);

        upsert contactsToUpsert;

        for (Contact c : contactsToUpsert) {
            result.contactMap.put(c.State_ID_Number__c, c.Id);
        }
        result.contactsProvisioned = contactsToUpsert.size();

        return result;
    }

    /**
     * @description Retrieves the 3 authoritative commercial permittee accounts.
     */
    public static List<Account> getPermitteeAccounts() {
        return [
            SELECT Id, Name, Facility_Type__c, Permit_Number__c, Premise_Registry_ID__c, Compliance_Status__c 
            FROM Account 
            WHERE Premise_Registry_ID__c IN (:KEYSTONE_REGISTRY_ID, :COMMONWEALTH_LABS_REGISTRY_ID, :SUSQUEHANNA_DISP_REGISTRY_ID)
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Retrieves the 5 persona contacts with account details.
     */
    public static List<Contact> getPermitteeContacts() {
        return [
            SELECT Id, FirstName, LastName, Name, Email, Title, AccountId, Account.Name, Stakeholder_Role__c, State_ID_Number__c 
            FROM Contact 
            WHERE State_ID_Number__c IN ('PA-AGT-1001', 'PA-AGT-1002', 'PA-AGT-1003', 'PA-AGT-2001', 'PA-AGT-3001')
            ORDER BY State_ID_Number__c ASC
        ];
    }
}

