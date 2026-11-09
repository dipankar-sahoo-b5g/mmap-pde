/**
 * @description Trigger on Transfer_Manifest__c delegating custodial state handshakes
 *              and child inventory status updates to TransferManifestTriggerHandler.
 */
trigger TransferManifestTrigger on Transfer_Manifest__c (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        TransferManifestTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        TransferManifestTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
