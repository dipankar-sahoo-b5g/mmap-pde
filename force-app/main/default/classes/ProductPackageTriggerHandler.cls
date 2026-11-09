/**
 * @description Trigger Handler for Product_Package__c that orchestrates
 *              pre-commit validations and field assignments.
 */
public with sharing class ProductPackageTriggerHandler {

    /**
     * @description Handles before-insert processing for Product Package records:
     *              1. Auto-assigns compliant 24-character RFID tags if blank.
     *              2. Defaults Package_Status__c to 'In_Testing' if blank.
     *              3. Defaults Lab_Safety_Status__c to 'Untested' if blank.
     * @param newPackages List of Product_Package__c records pending insertion.
     */
    public static void handleBeforeInsert(List<Product_Package__c> newPackages) {
        if (newPackages == null || newPackages.isEmpty()) {
            return;
        }

        List<Product_Package__c> packagesNeedingRFID = new List<Product_Package__c>();

        for (Product_Package__c pkg : newPackages) {
            // Check if RFID tag is blank and needs auto-generation or sync from Tag_ID__c
            if (String.isBlank(pkg.RFID_Tag__c)) {
                if (String.isNotBlank(pkg.Tag_ID__c) && pkg.Tag_ID__c.length() == 24) {
                    pkg.RFID_Tag__c = pkg.Tag_ID__c;
                } else {
                    packagesNeedingRFID.add(pkg);
                }
            } else if (String.isBlank(pkg.Tag_ID__c)) {
                pkg.Tag_ID__c = pkg.RFID_Tag__c;
            }

            // Default Package Status to 'In_Testing' if blank
            if (String.isBlank(pkg.Package_Status__c)) {
                pkg.Package_Status__c = 'In_Testing';
            }

            // Default Lab Safety Status to 'Untested' if blank
            if (String.isBlank(pkg.Lab_Safety_Status__c)) {
                pkg.Lab_Safety_Status__c = 'Untested';
            }
        }

        // Bulk generate and assign RFID tags for packages requiring them
        if (!packagesNeedingRFID.isEmpty()) {
            List<String> generatedTags = RFIDGeneratorService.generateTags(packagesNeedingRFID.size());
            for (Integer i = 0; i < packagesNeedingRFID.size(); i++) {
                packagesNeedingRFID[i].RFID_Tag__c = generatedTags[i];
                if (String.isBlank(packagesNeedingRFID[i].Tag_ID__c)) {
                    packagesNeedingRFID[i].Tag_ID__c = generatedTags[i];
                }
            }
        }
    }
}
