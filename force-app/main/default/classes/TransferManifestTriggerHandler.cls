/**
 * @description Trigger Handler for Transfer_Manifest__c that orchestrates
 *              automated inventory state transitions and custodial handshakes.
 */
public with sharing class TransferManifestTriggerHandler {

    /**
     * @description Handles before-update logic, such as setting Actual_Arrival__c when marked Delivered.
     * @param newManifests List of new Transfer_Manifest__c records.
     * @param oldManifestsMap Map of old Transfer_Manifest__c records by Id.
     */
    public static void handleBeforeUpdate(List<Transfer_Manifest__c> newManifests, Map<Id, Transfer_Manifest__c> oldManifestsMap) {
        if (newManifests == null || oldManifestsMap == null) {
            return;
        }

        for (Transfer_Manifest__c mnf : newManifests) {
            Transfer_Manifest__c oldMnf = oldManifestsMap.get(mnf.Id);
            if (oldMnf != null && mnf.Status__c == 'Delivered' && oldMnf.Status__c != 'Delivered') {
                if (mnf.Actual_Arrival__c == null) {
                    mnf.Actual_Arrival__c = System.now();
                }
            }
        }
    }

    /**
     * @description Handles after-update logic for Transfer_Manifest__c.
     *              - When Status__c changes to 'In Transit', queries child line items and updates Product_Package__c.Status__c = 'In_Transit'.
     *              - When Status__c changes to 'Delivered', updates Product_Package__c.Holding_Facility__c = Destination_Facility__c and Status__c = 'In_Stock'.
     * @param newManifests List of new Transfer_Manifest__c records.
     * @param oldManifestsMap Map of old Transfer_Manifest__c records by Id.
     */
    public static void handleAfterUpdate(List<Transfer_Manifest__c> newManifests, Map<Id, Transfer_Manifest__c> oldManifestsMap) {
        if (newManifests == null || oldManifestsMap == null) {
            return;
        }

        Set<Id> manifestIdsInTransit = new Set<Id>();
        Map<Id, Id> deliveredManifestToDestinationMap = new Map<Id, Id>();

        for (Transfer_Manifest__c mnf : newManifests) {
            Transfer_Manifest__c oldMnf = oldManifestsMap.get(mnf.Id);
            if (oldMnf == null) {
                continue;
            }

            if (mnf.Status__c == 'In Transit' && oldMnf.Status__c != 'In Transit') {
                manifestIdsInTransit.add(mnf.Id);
            } else if (mnf.Status__c == 'Delivered' && oldMnf.Status__c != 'Delivered') {
                deliveredManifestToDestinationMap.put(mnf.Id, mnf.Destination_Facility__c);
            }
        }

        Set<Id> allRelevantManifestIds = new Set<Id>();
        allRelevantManifestIds.addAll(manifestIdsInTransit);
        allRelevantManifestIds.addAll(deliveredManifestToDestinationMap.keySet());

        if (allRelevantManifestIds.isEmpty()) {
            return;
        }

        // Query related line items in bulk
        List<Manifest_Line_Item__c> lineItems = [
            SELECT Id, Transfer_Manifest__c, Product_Package__c
            FROM Manifest_Line_Item__c
            WHERE Transfer_Manifest__c IN :allRelevantManifestIds
              AND Product_Package__c != null
        ];

        if (lineItems.isEmpty()) {
            return;
        }

        Map<Id, Product_Package__c> packagesToUpdate = new Map<Id, Product_Package__c>();

        for (Manifest_Line_Item__c item : lineItems) {
            Id manifestId = item.Transfer_Manifest__c;
            Id packageId = item.Product_Package__c;

            if (manifestIdsInTransit.contains(manifestId)) {
                Product_Package__c pkg = packagesToUpdate.containsKey(packageId)
                    ? packagesToUpdate.get(packageId)
                    : new Product_Package__c(Id = packageId);
                pkg.Status__c = 'In_Transit';
                pkg.Package_Status__c = 'In_Transit';
                packagesToUpdate.put(packageId, pkg);
            } else if (deliveredManifestToDestinationMap.containsKey(manifestId)) {
                Id destinationFacility = deliveredManifestToDestinationMap.get(manifestId);
                Product_Package__c pkg = packagesToUpdate.containsKey(packageId)
                    ? packagesToUpdate.get(packageId)
                    : new Product_Package__c(Id = packageId);
                pkg.Holding_Facility__c = destinationFacility;
                pkg.Status__c = 'In_Stock';
                pkg.Package_Status__c = 'Ready_for_Sale';
                packagesToUpdate.put(packageId, pkg);
            }
        }

        if (!packagesToUpdate.isEmpty()) {
            update packagesToUpdate.values();
        }
    }
}
