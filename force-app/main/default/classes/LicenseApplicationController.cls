/**
 * @description Controller for Commercial Facility Licensing & Application Intake Wizard.
 *              Provides AuraEnabled methods to retrieve facility options, calculate statutory fees,
 *              validate regulatory criteria, and submit new license applications.
 */
public with sharing class LicenseApplicationController {

    /**
     * @description Calculates the statutory administrative fee based on license category.
     * @param appType Commercial license application type.
     * @return Statutory fee amount in USD.
     */
    public static Decimal calculateStatutoryFee(String appType) {
        if (String.isBlank(appType)) {
            throw new IllegalArgumentException('Application type cannot be blank.');
        }
        switch on appType {
            when 'Grower/Processor' {
                return 10000.00;
            }
            when 'Dispensary Retail' {
                return 5000.00;
            }
            when 'Analytical Lab' {
                return 2000.00;
            }
            when 'Academic Research' {
                return 1000.00;
            }
            when else {
                throw new IllegalArgumentException('Invalid application type: ' + appType);
            }
        }
    }

    /**
     * @description Exposes fee tier calculation to client components.
     * @param appType Commercial license application type.
     * @return Statutory fee amount in USD.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getFeeForType(String appType) {
        try {
            return calculateStatutoryFee(appType);
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException(ex.getMessage());
            ahe.setMessage(ex.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Retrieves active facilities for intake selection.
     * @return List of Account facility records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getFacilities() {
        return [
            SELECT Id,
                   Name,
                   Facility_Type__c,
                   Premise_Registry_ID__c,
                   BillingStreet,
                   BillingCity,
                   BillingState,
                   BillingPostalCode
            FROM Account
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    /**
     * @description Retrieves recently submitted license applications.
     * @return List of License_Application__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<License_Application__c> getApplications() {
        return [
            SELECT Id,
                   Name,
                   Applicant_Facility__c,
                   Applicant_Facility__r.Name,
                   Applicant_Facility__r.Premise_Registry_ID__c,
                   Application_Type__c,
                   Status__c,
                   Premise_Address__c,
                   Estimated_Canopy_SqFt__c,
                   Application_Fee__c,
                   Submission_Date__c,
                   Review_Notes__c,
                   CreatedDate
            FROM License_Application__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    /**
     * @description Submits a new commercial license application into the regulatory review queue.
     * @param facilityId Commercial Facility Account Id.
     * @param appType Operating license category.
     * @param premiseAddress Physical operational address.
     * @param canopySqFt Estimated plant canopy footprint in square feet.
     * @return Id of the created License_Application__c record.
     */
    @AuraEnabled
    public static Id submitApplication(Id facilityId, String appType, String premiseAddress, Decimal canopySqFt) {
        if (facilityId == null) {
            AuraHandledException ahe = new AuraHandledException('Facility Applicant is mandatory.');
            ahe.setMessage('Facility Applicant is mandatory.');
            throw ahe;
        }
        if (String.isBlank(appType)) {
            AuraHandledException ahe = new AuraHandledException('Application Type is mandatory.');
            ahe.setMessage('Application Type is mandatory.');
            throw ahe;
        }
        if (appType == 'Grower/Processor') {
            if (canopySqFt == null || canopySqFt <= 0) {
                AuraHandledException ahe = new AuraHandledException('Estimated canopy square footage is mandatory and must be greater than zero for Grower/Processor applications.');
                ahe.setMessage('Estimated canopy square footage is mandatory and must be greater than zero for Grower/Processor applications.');
                throw ahe;
            }
        }

        Decimal fee;
        try {
            fee = calculateStatutoryFee(appType);
        } catch (IllegalArgumentException iae) {
            AuraHandledException ahe = new AuraHandledException(iae.getMessage());
            ahe.setMessage(iae.getMessage());
            throw ahe;
        }

        License_Application__c app = new License_Application__c();
        app.Applicant_Facility__c = facilityId;
        app.Application_Type__c = appType;
        app.Status__c = 'Submitted';
        app.Premise_Address__c = premiseAddress;
        app.Estimated_Canopy_SqFt__c = canopySqFt;
        app.Application_Fee__c = fee;
        app.Submission_Date__c = Datetime.now();

        try {
            insert as user app;
            return app.Id;
        } catch (DmlException de) {
            AuraHandledException ahe = new AuraHandledException(de.getDmlMessage(0));
            ahe.setMessage(de.getDmlMessage(0));
            throw ahe;
        }
    }
}
