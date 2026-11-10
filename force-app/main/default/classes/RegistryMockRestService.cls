/**
 * @description Mock Registry REST endpoint simulating the PA Medical Marijuana Registry.
 *              Returns certification status, linked caregiver details, practitioner limits,
 *              and 90-day MMU quota allowances. Automatically logs every inquiry to Registry_Check__c.
 *              Source Baseline: PA Seed-to-Sale Demo Plan_7.xlsx (Dev Tasks T26, Scene 9, Rules BR052, BR053, BR102, BR103, TR009).
 * @author Dipankar Sahoo
 */
@RestResource(urlMapping='/registry/check/*')
global with sharing class RegistryMockRestService {

    /**
     * @description Data Transfer Object for Registry API responses.
     */
    global class RegistryResponse {
        global String statusCode;
        global String status;
        global String message;
        global String patientId;
        global String patientName;
        global String caregiverId;
        global String caregiverName;
        global Date certificationExpiry;
        global String practitionerLimits;
        global Decimal allowanceMMU;
        global Decimal consumedMMU;
        global Decimal remainingMMU;
        global Id registryCheckId;
    }

    /**
     * @description HTTP GET handler accepting Registry ID in URL path.
     *              Example: GET /services/apexrest/registry/check/PA-CG-99104
     */
    @HttpGet
    global static RegistryResponse doGet() {
        RestRequest req = RestContext.request;
        RegistryResponse resp;

        if (req == null || String.isBlank(req.requestURI)) {
            resp = createErrorResponse('400', 'Bad Request', 'Missing request URI');
        } else {
            String requestUri = req.requestURI;
            String registryId = requestUri.substring(requestUri.lastIndexOf('/') + 1).trim();

            if (String.isBlank(registryId)) {
                resp = createErrorResponse('400', 'Bad Request', 'Registry ID is required');
            } else {
                resp = verifyRegistryId(registryId);
            }
        }

        // Defensively assign HTTP transport status code
        if (RestContext.response != null && String.isNotBlank(resp.statusCode)) {
            try {
                RestContext.response.statusCode = Integer.valueOf(resp.statusCode);
            } catch (Exception ex) {
                RestContext.response.statusCode = 500;
            }
        }

        return resp;
    }

    /**
     * @description Core verification logic callable directly by Apex services, flows, or REST.
     *              Performs query, resolves caregiver links, inserts audit record, and returns response.
     * @param registryId Registry ID string (e.g. PA-PAT-77201 or PA-CG-99104)
     * @return RegistryResponse DTO
     */
    public static RegistryResponse verifyRegistryId(String registryId) {
        if (String.isBlank(registryId)) {
            return createErrorResponse('400', 'Bad Request', 'Registry ID cannot be empty');
        }

        // Query Patient_Ref__c with potential caregiver parent linkage
        List<Patient_Ref__c> records = [
            SELECT Id, Name, Registry_ID__c, Person_Type__c, Certification_Status__c,
                   Certification_Expiry__c, Practitioner_Limits__c, MMU_Allowance__c,
                   MMU_Used_90_Days__c, MMU_Remaining__c, Linked_Patient__c,
                   Linked_Patient__r.Id, Linked_Patient__r.Name, Linked_Patient__r.Registry_ID__c,
                   Linked_Patient__r.Certification_Status__c, Linked_Patient__r.Certification_Expiry__c,
                   Linked_Patient__r.Practitioner_Limits__c, Linked_Patient__r.MMU_Allowance__c,
                   Linked_Patient__r.MMU_Used_90_Days__c, Linked_Patient__r.MMU_Remaining__c
            FROM Patient_Ref__c
            WHERE Registry_ID__c = :registryId
            WITH USER_MODE
            LIMIT 1
        ];

        if (records.isEmpty()) {
            // Log unmatched lookup audit record (Rule TR009)
            Registry_Check__c auditLog = new Registry_Check__c(
                Called_At__c = Datetime.now(),
                Certification_Status__c = 'Unknown',
                Response_Code__c = '404 NOT_FOUND'
            );
            insertSecurityEnforced(auditLog);

            RegistryResponse notFoundResp = createErrorResponse('404', 'Not Found', 'No record found in registry for ID: ' + registryId);
            notFoundResp.registryCheckId = auditLog.Id;
            return notFoundResp;
        }

        Patient_Ref__c matched = records[0];
        RegistryResponse resp = new RegistryResponse();
        Registry_Check__c audit = new Registry_Check__c();
        audit.Called_At__c = Datetime.now();

        if (matched.Person_Type__c == 'Caregiver') {
            // 1. Verify Caregiver Link to Patient (Rules BR052, BR102)
            if (matched.Linked_Patient__c == null) {
                audit.Caregiver_Ref__c = matched.Id;
                audit.Certification_Status__c = 'Unlinked';
                audit.Response_Code__c = 'ELIG-02: Caregiver card not linked to patient';
                insertSecurityEnforced(audit);

                resp = createErrorResponse('400', 'Unlinked Caregiver', 'Caregiver card ' + registryId + ' is not linked to any certified patient');
                resp.caregiverId = matched.Registry_ID__c;
                resp.caregiverName = matched.Name;
                resp.registryCheckId = audit.Id;
                return resp;
            }

            // 2. Verify Caregiver Card Active Status & Expiration (Rules BR052, BR102)
            Boolean isCaregiverExpired = (matched.Certification_Expiry__c != null && matched.Certification_Expiry__c < Date.today());
            if (matched.Certification_Status__c != 'Active' || isCaregiverExpired) {
                audit.Caregiver_Ref__c = matched.Id;
                audit.Patient_Ref__c = matched.Linked_Patient__c;
                audit.Certification_Status__c = isCaregiverExpired ? 'Expired' : matched.Certification_Status__c;
                audit.Response_Code__c = 'ELIG-03: Caregiver certification is ' + audit.Certification_Status__c;
                insertSecurityEnforced(audit);

                resp = createErrorResponse('400', 'Caregiver Ineligible', 'Caregiver registration is ' + audit.Certification_Status__c);
                resp.caregiverId = matched.Registry_ID__c;
                resp.caregiverName = matched.Name;
                resp.registryCheckId = audit.Id;
                return resp;
            }

            // 3. Resolve Patient & Verify Certification Status (Rules BR053, BR103)
            Patient_Ref__c patient = matched.Linked_Patient__r;
            Boolean isPatientExpired = (patient.Certification_Expiry__c != null && patient.Certification_Expiry__c < Date.today());
            Boolean isPatientActive = (patient.Certification_Status__c == 'Active' && !isPatientExpired);

            resp.statusCode = isPatientActive ? '200' : '400';
            resp.status = isPatientExpired ? 'Expired' : patient.Certification_Status__c;
            resp.message = isPatientActive ? 'Patient and Caregiver Verified' : ('Patient certification is ' + resp.status);
            resp.patientId = patient.Registry_ID__c;
            resp.patientName = patient.Name;
            resp.caregiverId = matched.Registry_ID__c;
            resp.caregiverName = matched.Name;
            resp.certificationExpiry = patient.Certification_Expiry__c;
            resp.practitionerLimits = patient.Practitioner_Limits__c;
            resp.allowanceMMU = (patient.MMU_Allowance__c != null) ? patient.MMU_Allowance__c : 192.00;
            resp.consumedMMU = (patient.MMU_Used_90_Days__c != null) ? patient.MMU_Used_90_Days__c : 0.00;
            resp.remainingMMU = (patient.MMU_Remaining__c != null) ? patient.MMU_Remaining__c : (resp.allowanceMMU - resp.consumedMMU);

            audit.Patient_Ref__c = patient.Id;
            audit.Caregiver_Ref__c = matched.Id;
            audit.Certification_Status__c = resp.status;
            audit.Practitioner_Limits__c = patient.Practitioner_Limits__c;
            audit.MMU_Allowance__c = resp.allowanceMMU;
            audit.MMU_Used_90_Days__c = resp.consumedMMU;
            audit.MMU_Remaining__c = resp.remainingMMU;
            audit.Response_Code__c = isPatientActive ? '200 OK' : ('400 Patient ' + resp.status);

        } else {
            // Direct Patient Query (Scene 9, Rules BR053, BR103)
            Boolean isPatientExpired = (matched.Certification_Expiry__c != null && matched.Certification_Expiry__c < Date.today());
            Boolean isPatientActive = (matched.Certification_Status__c == 'Active' && !isPatientExpired);

            resp.statusCode = isPatientActive ? '200' : '400';
            resp.status = isPatientExpired ? 'Expired' : matched.Certification_Status__c;
            resp.message = isPatientActive ? 'Patient Verified' : ('Patient certification is ' + resp.status);
            resp.patientId = matched.Registry_ID__c;
            resp.patientName = matched.Name;
            resp.caregiverId = null;
            resp.caregiverName = null;
            resp.certificationExpiry = matched.Certification_Expiry__c;
            resp.practitionerLimits = matched.Practitioner_Limits__c;
            resp.allowanceMMU = (matched.MMU_Allowance__c != null) ? matched.MMU_Allowance__c : 192.00;
            resp.consumedMMU = (matched.MMU_Used_90_Days__c != null) ? matched.MMU_Used_90_Days__c : 0.00;
            resp.remainingMMU = (matched.MMU_Remaining__c != null) ? matched.MMU_Remaining__c : (resp.allowanceMMU - resp.consumedMMU);

            audit.Patient_Ref__c = matched.Id;
            audit.Certification_Status__c = resp.status;
            audit.Practitioner_Limits__c = matched.Practitioner_Limits__c;
            audit.MMU_Allowance__c = resp.allowanceMMU;
            audit.MMU_Used_90_Days__c = resp.consumedMMU;
            audit.MMU_Remaining__c = resp.remainingMMU;
            audit.Response_Code__c = isPatientActive ? '200 OK' : ('400 Patient ' + resp.status);
        }

        // Insert audit log to Registry_Check__c (Rule TR009)
        insertSecurityEnforced(audit);
        resp.registryCheckId = audit.Id;

        return resp;
    }

    private static RegistryResponse createErrorResponse(String statusCode, String status, String message) {
        RegistryResponse resp = new RegistryResponse();
        resp.statusCode = statusCode;
        resp.status = status;
        resp.message = message;
        return resp;
    }

    private static void insertSecurityEnforced(SObject record) {
        if (Schema.sObjectType.Registry_Check__c.isCreateable()) {
            try {
                Database.insert(record, AccessLevel.USER_MODE);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to insert Registry_Check audit log: ' + ex.getMessage());
            }
        }
    }
}
