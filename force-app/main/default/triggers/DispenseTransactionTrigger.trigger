/**
 * @description Trigger on Dispense_Transaction__c delegating lifecycle events to DispenseTransactionTriggerHandler.
 */
trigger DispenseTransactionTrigger on Dispense_Transaction__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        DispenseTransactionTriggerHandler.handleBeforeInsert(Trigger.new);
    }
}
