/**
 * @description Domain Service for calculating and enforcing rolling 30-day medical
 *              cannabis purchase limits and patient registration status validations.
 */
public with sharing class PurchaseLimitService {

    /**
     * @description Custom exception thrown when purchase quota is exceeded.
     */
    public class LimitExceededException extends Exception {}

    /**
     * @description Validates a batch of dispense transactions against patient 30-day limits
     *              and registration active status. Bulkified and maintains state across
     *              multiple transactions for the same patient in a single execution context.
     * @param newTransactions List of Dispense_Transaction__c records pending insertion.
     */
    public static void validateTransactionLimits(List<Dispense_Transaction__c> newTransactions) {
        if (newTransactions == null || newTransactions.isEmpty()) {
            return;
        }

        // Collect unique patient registration IDs and existing record IDs (if any)
        Set<Id> patientIds = new Set<Id>();
        Set<Id> existingTxIds = new Set<Id>();
        for (Dispense_Transaction__c tx : newTransactions) {
            if (tx.Patient_Registration__c != null) {
                patientIds.add(tx.Patient_Registration__c);
            }
            if (tx.Id != null) {
                existingTxIds.add(tx.Id);
            }
        }

        if (patientIds.isEmpty()) {
            return;
        }

        // Query patient registration records for active status and quota limit
        Map<Id, Patient_Registration__c> patientMap = new Map<Id, Patient_Registration__c>(
            [SELECT Id, Is_Active__c, Thirty_Day_Limit_Grams__c 
             FROM Patient_Registration__c 
             WHERE Id IN :patientIds]
        );

        // Calculate rolling 30-day usage for all target patients
        Datetime thirtyDaysAgo = Datetime.now().addDays(-30);
        Map<Id, Decimal> rollingUsageMap = new Map<Id, Decimal>();
        for (Id patientId : patientIds) {
            rollingUsageMap.put(patientId, 0.00);
        }

        List<AggregateResult> results = [
            SELECT Patient_Registration__c patientId, SUM(Grams_Dispensed__c) totalGrams 
            FROM Dispense_Transaction__c 
            WHERE Patient_Registration__c IN :patientIds 
              AND Transaction_Timestamp__c >= :thirtyDaysAgo 
              AND Id NOT IN :existingTxIds
            GROUP BY Patient_Registration__c
        ];

        for (AggregateResult ar : results) {
            Id pId = (Id) ar.get('patientId');
            Decimal total = (Decimal) ar.get('totalGrams');
            if (total != null) {
                rollingUsageMap.put(pId, total);
            }
        }

        // Evaluate each transaction against limit and active status
        for (Dispense_Transaction__c tx : newTransactions) {
            if (tx.Patient_Registration__c == null) {
                continue;
            }

            Patient_Registration__c patient = patientMap.get(tx.Patient_Registration__c);
            if (patient == null) {
                continue;
            }

            // 1. Inactive / expired patient registration check
            if (patient.Is_Active__c == false) {
                tx.addError('Transaction Rejected: Patient registration is inactive or expired.');
                continue;
            }

            Decimal limitGrams = patient.Thirty_Day_Limit_Grams__c != null ? patient.Thirty_Day_Limit_Grams__c : 90.00;
            Decimal currentUsage = rollingUsageMap.get(patient.Id);
            Decimal txGrams = tx.Grams_Dispensed__c != null ? tx.Grams_Dispensed__c : 0.00;

            Decimal remainingGrams = limitGrams - currentUsage;
            if (remainingGrams < 0) {
                remainingGrams = 0.00;
            }

            // 2. Rolling 30-day purchase limit check
            if (currentUsage + txGrams > limitGrams) {
                tx.addError('Transaction Rejected: Patient has ' + remainingGrams.setScale(2) + ' grams remaining in their rolling 30-day quota.');
            } else {
                // Update in-memory rolling usage for multiple transactions in the same batch
                rollingUsageMap.put(patient.Id, currentUsage + txGrams);
            }
        }
    }

    /**
     * @description Calculates and returns the rolling 30-day grams dispensed for a given patient.
     * @param patientRegistrationId Id of the Patient_Registration__c record.
     * @return Decimal Rolling 30-day total grams dispensed (scaled to 2 decimal places).
     */
    public static Decimal getRolling30DayUsage(Id patientRegistrationId) {
        if (patientRegistrationId == null) {
            return 0.00;
        }

        Datetime thirtyDaysAgo = Datetime.now().addDays(-30);
        List<AggregateResult> results = [
            SELECT SUM(Grams_Dispensed__c) totalGrams 
            FROM Dispense_Transaction__c 
            WHERE Patient_Registration__c = :patientRegistrationId 
              AND Transaction_Timestamp__c >= :thirtyDaysAgo
        ];

        if (!results.isEmpty() && results[0].get('totalGrams') != null) {
            return ((Decimal) results[0].get('totalGrams')).setScale(2);
        }

        return 0.00;
    }
}
