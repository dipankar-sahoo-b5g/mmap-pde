/**
 * @description Trigger on Product_Package__c delegating lifecycle events to ProductPackageTriggerHandler.
 */
trigger ProductPackageTrigger on Product_Package__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ProductPackageTriggerHandler.handleBeforeInsert(Trigger.new);
    }
}
