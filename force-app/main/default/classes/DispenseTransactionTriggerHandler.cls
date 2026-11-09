/**
 * @description Trigger Handler for Dispense_Transaction__c that coordinates pre-commit
 *              validations, quota checks, and default timestamp assignment.
 */
public with sharing class DispenseTransactionTriggerHandler {

    /**
     * @description Handles before-insert processing for Dispense Transaction records:
     *              1. Defaults Transaction_Timestamp__c to Datetime.now() if null.
     *              2. Validates rolling 30-day purchase limits and active patient registration status.
     * @param newTransactions List of Dispense_Transaction__c records pending insertion.
     */
    public static void handleBeforeInsert(List<Dispense_Transaction__c> newTransactions) {
        if (newTransactions == null || newTransactions.isEmpty()) {
            return;
        }

        // Default transaction timestamp to current datetime if blank
        for (Dispense_Transaction__c tx : newTransactions) {
            if (tx.Transaction_Timestamp__c == null) {
                tx.Transaction_Timestamp__c = Datetime.now();
            }
        }

        // Delegate quota calculation and active status validation to PurchaseLimitService
        PurchaseLimitService.validateTransactionLimits(newTransactions);
    }
}
