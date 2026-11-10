/**
 * @description Flow Invocable Action enabling declarative Screen Flows (e.g. Dispensary Counter Flow T21)
 *              to verify patient and caregiver registry eligibility, practitioner limits, and 90-day MMU balances.
 *              Source Baseline: PA Seed-to-Sale Demo Plan_7.xlsx (Dev Tasks T26, Scene 9, Rules BR052, BR053, BR102, BR103, TR009).
 * @author Dipankar Sahoo
 */
public with sharing class RegistryServiceCallout {

    /**
     * @description Invocable Request wrapper holding input parameters from Flow.
     */
    public class RegistryRequest {
        @InvocableVariable(label='Registry ID' description='Patient or Caregiver Registry ID (e.g., PA-PAT-77201 or PA-CG-99104)' required=true)
        public String registryId;
    }

    /**
     * @description Invocable Result wrapper returning verification outputs to Flow.
     */
    public class RegistryResult {
        @InvocableVariable(label='Is Eligible' description='True if both patient and caregiver (if applicable) are active, unexpired, and properly linked.')
        public Boolean isEligible;

        @InvocableVariable(label='Status Code' description='HTTP-style response code (e.g. 200, 400, 404).')
        public String statusCode;

        @InvocableVariable(label='Certification Status' description='Active, Expired, Revoked, Unlinked, etc.')
        public String status;

        @InvocableVariable(label='Status Message' description='Descriptive verification or refusal message.')
        public String message;

        @InvocableVariable(label='Patient ID' description='System-generated Patient Registry ID.')
        public String patientId;

        @InvocableVariable(label='Patient Name' description='Full legal name of the certified patient.')
        public String patientName;

        @InvocableVariable(label='Caregiver ID' description='Caregiver Registry ID if presented.')
        public String caregiverId;

        @InvocableVariable(label='Caregiver Name' description='Full legal name of the caregiver if presented.')
        public String caregiverName;

        @InvocableVariable(label='Certification Expiration Date' description='Date when patient certification expires.')
        public Date certificationExpiry;

        @InvocableVariable(label='Practitioner Limits' description='Physician instructions and product form restrictions.')
        public String practitionerLimits;

        @InvocableVariable(label='90-Day MMU Allowance' description='Statutory 90-day medical marijuana unit allowance (typically 192.00).')
        public Decimal allowanceMMU;

        @InvocableVariable(label='90-Day MMU Consumed' description='Total MMUs purchased across all dispensaries within the last 90 rolling days.')
        public Decimal consumedMMU;

        @InvocableVariable(label='90-Day MMU Remaining' description='Remaining allowable MMU units.')
        public Decimal remainingMMU;

        @InvocableVariable(label='Registry Check Log ID' description='Salesforce ID of the audit record created in Registry_Check__c per Rule TR009.')
        public Id registryCheckId;
    }

    /**
     * @description Invocable method called by Salesforce Flow.
     * @param requests List of RegistryRequest input records from Flow
     * @return List of RegistryResult output records corresponding to each request
     */
    @InvocableMethod(
        label='Verify Registry Eligibility'
        description='Queries PA Medical Marijuana Registry for certification status, caregiver linkage, practitioner limits, and 90-day MMU quota.'
        category='Dispensary'
    )
    public static List<RegistryResult> verifyEligibility(List<RegistryRequest> requests) {
        List<RegistryResult> results = new List<RegistryResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (RegistryRequest req : requests) {
            RegistryResult res = new RegistryResult();

            if (req == null || String.isBlank(req.registryId)) {
                res.isEligible = false;
                res.statusCode = '400';
                res.status = 'Bad Request';
                res.message = 'Registry ID is required';
                results.add(res);
                continue;
            }

            // Invoke underlying Registry service
            RegistryMockRestService.RegistryResponse serviceResp = RegistryMockRestService.verifyRegistryId(req.registryId.trim());

            res.statusCode = serviceResp.statusCode;
            res.status = serviceResp.status;
            res.message = serviceResp.message;
            res.patientId = serviceResp.patientId;
            res.patientName = serviceResp.patientName;
            res.caregiverId = serviceResp.caregiverId;
            res.caregiverName = serviceResp.caregiverName;
            res.certificationExpiry = serviceResp.certificationExpiry;
            res.practitionerLimits = serviceResp.practitionerLimits;
            res.allowanceMMU = serviceResp.allowanceMMU;
            res.consumedMMU = serviceResp.consumedMMU;
            res.remainingMMU = serviceResp.remainingMMU;
            res.registryCheckId = serviceResp.registryCheckId;

            // Determine overall eligibility for Flow decision nodes
            res.isEligible = (serviceResp.statusCode == '200' && serviceResp.status == 'Active');

            results.add(res);
        }

        return results;
    }
}

