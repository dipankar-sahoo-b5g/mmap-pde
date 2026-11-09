/**
 * @description Controller for Certifying Physician & Patient Digital Registry Experience.
 *              Provides backend services for digital MMAP card rendering, quota calculation,
 *              and statutory physician recommendation submissions.
 */
public with sharing class PatientPortalController {

    /**
     * @description Retrieves registered patients eligible for certification and digital cards.
     * @return List of Contact records with Stakeholder_Role__c = 'Patient'.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getPatients() {
        return [
            SELECT Id, Name, FirstName, LastName, State_ID_Number__c, Stakeholder_Role__c, Email, Phone
            FROM Contact
            WHERE Stakeholder_Role__c = 'Patient'
            WITH USER_MODE
            ORDER BY LastName ASC, FirstName ASC
        ];
    }

    /**
     * @description Retrieves registered certifying physicians.
     * @return List of Contact records with Stakeholder_Role__c = 'Physician'.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getPhysicians() {
        return [
            SELECT Id, Name, FirstName, LastName, Medical_License_No__c, Stakeholder_Role__c, Email, Phone
            FROM Contact
            WHERE Stakeholder_Role__c = 'Physician'
            WITH USER_MODE
            ORDER BY LastName ASC, FirstName ASC
        ];
    }

    /**
     * @description Retrieves recent physician certifications with patient and doctor details.
     * @return List of Physician_Certification__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Physician_Certification__c> getCertifications() {
        return [
            SELECT Id, Name, Patient__c, Patient__r.Name, Certifying_Physician__c, Certifying_Physician__r.Name,
                   Qualifying_Condition_ICD10__c, Recommended_Daily_Dose_Grams__c,
                   Issue_Date__c, Expiration_Date__c, Doctor_Digital_Signature_Timestamp__c,
                   Status__c, Certification_Notes__c, CreatedDate
            FROM Physician_Certification__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    /**
     * @description Submits a new digital physician certification with cryptographic signature timestamp.
     * @param patientId Contact ID of the registered patient.
     * @param physicianId Contact ID of the certifying doctor.
     * @param condition Qualifying medical condition (ICD-10 category).
     * @param dailyDose Recommended daily dosage in grams.
     * @param issueDate Date of recommendation.
     * @param expirationDate Statutory expiration date (cannot exceed 12 months).
     * @param notes Clinical diagnosis and care notes.
     * @return The created Physician_Certification__c record.
     */
    @AuraEnabled
    public static Physician_Certification__c submitCertification(
        Id patientId,
        Id physicianId,
        String condition,
        Decimal dailyDose,
        Date issueDate,
        Date expirationDate,
        String notes
    ) {
        if (patientId == null) {
            AuraHandledException ahe = new AuraHandledException('Patient is mandatory.');
            ahe.setMessage('Patient is mandatory.');
            throw ahe;
        }
        if (physicianId == null) {
            AuraHandledException ahe = new AuraHandledException('Certifying Physician is mandatory.');
            ahe.setMessage('Certifying Physician is mandatory.');
            throw ahe;
        }
        if (String.isBlank(condition)) {
            AuraHandledException ahe = new AuraHandledException('Qualifying condition is mandatory.');
            ahe.setMessage('Qualifying condition is mandatory.');
            throw ahe;
        }
        if (issueDate == null) {
            issueDate = Date.today();
        }
        if (expirationDate == null) {
            expirationDate = issueDate.addDays(365);
        }

        Physician_Certification__c cert = new Physician_Certification__c(
            Patient__c = patientId,
            Certifying_Physician__c = physicianId,
            Qualifying_Condition_ICD10__c = condition,
            Recommended_Daily_Dose_Grams__c = dailyDose,
            Issue_Date__c = issueDate,
            Expiration_Date__c = expirationDate,
            Doctor_Digital_Signature_Timestamp__c = DateTime.now(),
            Status__c = 'Active',
            Certification_Notes__c = notes
        );

        try {
            insert as user cert;
            return cert;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException(ex.getMessage());
            ahe.setMessage(ex.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Aggregates all card data, purchase limit scorecard, and active clinical certification
     *              for a given patient registration or patient contact.
     * @param patientRegistrationId Id of Patient_Registration__c or Contact. If null, the latest active registration is loaded.
     * @return Map containing all formatted payload data for the patient registration card.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPatientCardData(Id patientRegistrationId) {
        try {
            Patient_Registration__c patientReg = null;

            if (patientRegistrationId != null) {
                String sId = String.valueOf(patientRegistrationId);
                if (sId.startsWith('003')) {
                    // Contact ID passed
                    List<Patient_Registration__c> regs = [
                        SELECT Id, Name, Patient__c, Patient__r.Name, Patient__r.State_ID_Number__c,
                               Certifying_Physician__c, Certifying_Physician__r.Name, Certifying_Physician__r.Medical_License_No__c,
                               Barcode_String__c, Thirty_Day_Limit_Grams__c, Certification_Date__c, Expiration_Date__c, Is_Active__c
                        FROM Patient_Registration__c
                        WHERE Patient__c = :patientRegistrationId
                        WITH USER_MODE
                        ORDER BY Is_Active__c DESC, CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!regs.isEmpty()) {
                        patientReg = regs[0];
                    }
                } else {
                    // Patient_Registration__c ID passed
                    List<Patient_Registration__c> regs = [
                        SELECT Id, Name, Patient__c, Patient__r.Name, Patient__r.State_ID_Number__c,
                               Certifying_Physician__c, Certifying_Physician__r.Name, Certifying_Physician__r.Medical_License_No__c,
                               Barcode_String__c, Thirty_Day_Limit_Grams__c, Certification_Date__c, Expiration_Date__c, Is_Active__c
                        FROM Patient_Registration__c
                        WHERE Id = :patientRegistrationId
                        WITH USER_MODE
                        LIMIT 1
                    ];
                    if (!regs.isEmpty()) {
                        patientReg = regs[0];
                    }
                }
            }

            // Fallback: pick first active registration or any registration
            if (patientReg == null) {
                List<Patient_Registration__c> fallbackRegs = [
                    SELECT Id, Name, Patient__c, Patient__r.Name, Patient__r.State_ID_Number__c,
                           Certifying_Physician__c, Certifying_Physician__r.Name, Certifying_Physician__r.Medical_License_No__c,
                           Barcode_String__c, Thirty_Day_Limit_Grams__c, Certification_Date__c, Expiration_Date__c, Is_Active__c
                    FROM Patient_Registration__c
                    WITH USER_MODE
                    ORDER BY Is_Active__c DESC, CreatedDate DESC
                    LIMIT 1
                ];
                if (!fallbackRegs.isEmpty()) {
                    patientReg = fallbackRegs[0];
                }
            }

            if (patientReg == null) {
                return new Map<String, Object>{
                    'hasRecord' => false,
                    'message' => 'No patient registration records found in the Commonwealth registry.'
                };
            }

            // Find latest active physician certification for this patient
            List<Physician_Certification__c> certList = [
                SELECT Id, Name, Patient__c, Certifying_Physician__c, Certifying_Physician__r.Name,
                       Certifying_Physician__r.Medical_License_No__c, Qualifying_Condition_ICD10__c,
                       Recommended_Daily_Dose_Grams__c, Issue_Date__c, Expiration_Date__c,
                       Doctor_Digital_Signature_Timestamp__c, Status__c, Certification_Notes__c
                FROM Physician_Certification__c
                WHERE Patient__c = :patientReg.Patient__c
                WITH USER_MODE
                ORDER BY Issue_Date__c DESC, CreatedDate DESC
                LIMIT 1
            ];

            Physician_Certification__c activeCert = certList.isEmpty() ? null : certList[0];

            Decimal totalQuota = patientReg.Thirty_Day_Limit_Grams__c != null ? patientReg.Thirty_Day_Limit_Grams__c : 90.00;
            Decimal gramsUsed = PurchaseLimitService.getRolling30DayUsage(patientReg.Id);
            Decimal gramsRemaining = totalQuota - gramsUsed;
            if (gramsRemaining < 0) {
                gramsRemaining = 0.00;
            }

            Decimal percentUsed = totalQuota > 0 ? ((gramsUsed / totalQuota) * 100).setScale(1) : 0.0;

            String condition = (activeCert != null && activeCert.Qualifying_Condition_ICD10__c != null) 
                ? activeCert.Qualifying_Condition_ICD10__c 
                : 'Chronic Pain';

            Decimal dailyDose = (activeCert != null && activeCert.Recommended_Daily_Dose_Grams__c != null)
                ? activeCert.Recommended_Daily_Dose_Grams__c
                : 3.00;

            String doctorName = (activeCert != null && activeCert.Certifying_Physician__c != null)
                ? activeCert.Certifying_Physician__r.Name
                : (patientReg.Certifying_Physician__r != null ? patientReg.Certifying_Physician__r.Name : 'Commonwealth Certified MD');

            String doctorLicense = (activeCert != null && activeCert.Certifying_Physician__c != null)
                ? activeCert.Certifying_Physician__r.Medical_License_No__c
                : (patientReg.Certifying_Physician__r != null ? patientReg.Certifying_Physician__r.Medical_License_No__c : 'MD-98214-PA');

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('hasRecord', true);
            payload.put('patientRegistrationId', patientReg.Id);
            payload.put('registrationNumber', patientReg.Name);
            payload.put('barcodeString', patientReg.Barcode_String__c);
            payload.put('patientContactId', patientReg.Patient__c);
            payload.put('patientName', patientReg.Patient__r != null ? patientReg.Patient__r.Name : 'Patient Record');
            payload.put('stateIdNumber', patientReg.Patient__r != null ? patientReg.Patient__r.State_ID_Number__c : 'N/A');
            payload.put('issueDate', patientReg.Certification_Date__c);
            payload.put('expirationDate', patientReg.Expiration_Date__c);
            payload.put('isActive', patientReg.Is_Active__c);
            payload.put('totalQuotaGrams', totalQuota.setScale(2));
            payload.put('gramsUsed', gramsUsed.setScale(2));
            payload.put('gramsRemaining', gramsRemaining.setScale(2));
            payload.put('percentUsed', percentUsed);
            payload.put('physicianName', doctorName);
            payload.put('physicianLicense', doctorLicense);
            payload.put('hasCertification', activeCert != null);
            payload.put('certificationId', activeCert != null ? activeCert.Id : null);
            payload.put('certificationNumber', activeCert != null ? activeCert.Name : 'N/A');
            payload.put('qualifyingCondition', condition);
            payload.put('recommendedDailyDose', dailyDose.setScale(2));
            payload.put('digitalSignatureTimestamp', activeCert != null ? activeCert.Doctor_Digital_Signature_Timestamp__c : null);
            payload.put('certificationNotes', activeCert != null ? activeCert.Certification_Notes__c : '');
            payload.put('certificationStatus', activeCert != null ? activeCert.Status__c : (patientReg.Is_Active__c ? 'Active' : 'Expired'));

            return payload;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException('Error loading patient card data: ' + ex.getMessage());
            ahe.setMessage('Error loading patient card data: ' + ex.getMessage());
            throw ahe;
        }
    }
}
