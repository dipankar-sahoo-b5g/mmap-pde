/**
 * @description Controller for Electronic Chain-of-Custody Shipping Manifests
 *              and Dual-Signature Handshake workflows.
 */
public with sharing class TransferManifestController {

    /**
     * @description Retrieves recent Transfer Manifest records with origin/destination facility
     *              relationships and child line items.
     * @return List of Transfer_Manifest__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Transfer_Manifest__c> getManifests() {
        return [
            SELECT Id, Name, Status__c,
                   Origin_Facility__c, Origin_Facility__r.Name, Origin_Facility__r.Premise_Registry_ID__c,
                   Destination_Facility__c, Destination_Facility__r.Name, Destination_Facility__r.Premise_Registry_ID__c,
                   Transporter_Facility__c, Transporter_Facility__r.Name, Transporter_Facility__r.Premise_Registry_ID__c,
                   Driver_Name__c, Driver_License_No__c, Vehicle_VIN__c, Vehicle_License_Plate__c,
                   Departure_Timestamp__c, Estimated_Arrival__c, Actual_Arrival__c,
                   Dispatcher_Signature__c, Transporter_Signature__c, Receiver_Signature__c,
                   Security_Notes__c, CreatedDate,
                   (SELECT Id, Name, Product_Package__c, Package_RFID__c, Gross_Weight_Grams__c, Item_Count__c 
                    FROM Manifest_Line_Items__r)
            FROM Transfer_Manifest__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    /**
     * @description Helper to construct AuraHandledException with explicit message for tests and client UI.
     * @param message Error message text.
     * @return AuraHandledException instance.
     */
    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * @description Retrieves complete details and line items for a specific manifest.
     * @param manifestId Salesforce ID of the Transfer_Manifest__c.
     * @return Full Transfer_Manifest__c record with line items.
     */
    @AuraEnabled
    public static Transfer_Manifest__c getManifestDetails(Id manifestId) {
        if (manifestId == null) {
            throw createAuraException('Manifest ID cannot be null.');
        }

        List<Transfer_Manifest__c> manifests = [
            SELECT Id, Name, Status__c,
                   Origin_Facility__c, Origin_Facility__r.Name, Origin_Facility__r.Premise_Registry_ID__c,
                   Destination_Facility__c, Destination_Facility__r.Name, Destination_Facility__r.Premise_Registry_ID__c,
                   Transporter_Facility__c, Transporter_Facility__r.Name, Transporter_Facility__r.Premise_Registry_ID__c,
                   Driver_Name__c, Driver_License_No__c, Vehicle_VIN__c, Vehicle_License_Plate__c,
                   Departure_Timestamp__c, Estimated_Arrival__c, Actual_Arrival__c,
                   Dispatcher_Signature__c, Transporter_Signature__c, Receiver_Signature__c,
                   Security_Notes__c, CreatedDate,
                   (SELECT Id, Name, Product_Package__c, Product_Package__r.Name, Product_Package__r.RFID_Tag__c,
                           Product_Package__r.Product_Type__c, Product_Package__r.Net_Weight_Grams__c,
                           Product_Package__r.Lab_Safety_Status__c,
                           Package_RFID__c, Gross_Weight_Grams__c, Item_Count__c
                    FROM Manifest_Line_Items__r
                    ORDER BY CreatedDate ASC)
            FROM Transfer_Manifest__c
            WHERE Id = :manifestId
            WITH USER_MODE
            LIMIT 1
        ];

        if (manifests.isEmpty()) {
            throw createAuraException('Transfer Manifest not found with ID: ' + manifestId);
        }

        return manifests[0];
    }

    /**
     * @description Creates a new Transfer Manifest and associated child Line Items.
     * @param originFacilityId Originating commercial facility Account ID.
     * @param destinationFacilityId Destination commercial facility Account ID.
     * @param transporterFacilityId Transporter facility Account ID.
     * @param driverName Legal name of commercial transport driver.
     * @param driverLicense State driver license number.
     * @param vehicleVIN 17-character vehicle VIN.
     * @param packageIds List of Product_Package__c IDs to attach.
     * @return Newly created Transfer_Manifest__c record.
     */
    @AuraEnabled
    public static Transfer_Manifest__c createManifest(
        Id originFacilityId,
        Id destinationFacilityId,
        Id transporterFacilityId,
        String driverName,
        String driverLicense,
        String vehicleVIN,
        List<Id> packageIds
    ) {
        if (originFacilityId == null || destinationFacilityId == null) {
            throw createAuraException('Origin and Destination facilities are required.');
        }

        if (originFacilityId == destinationFacilityId) {
            throw createAuraException('Origin facility and Destination facility cannot be the same commercial premise.');
        }

        Transfer_Manifest__c newManifest = new Transfer_Manifest__c(
            Origin_Facility__c = originFacilityId,
            Destination_Facility__c = destinationFacilityId,
            Transporter_Facility__c = transporterFacilityId,
            Driver_Name__c = driverName,
            Driver_License_No__c = driverLicense,
            Vehicle_VIN__c = vehicleVIN,
            Departure_Timestamp__c = System.now(),
            Estimated_Arrival__c = System.now().addHours(3),
            Status__c = 'Draft'
        );

        Database.insert(newManifest, AccessLevel.USER_MODE);

        if (packageIds != null && !packageIds.isEmpty()) {
            List<Product_Package__c> packages = [
                SELECT Id, Name, RFID_Tag__c, Net_Weight_Grams__c
                FROM Product_Package__c
                WHERE Id IN :packageIds
                WITH USER_MODE
            ];

            List<Manifest_Line_Item__c> lineItems = new List<Manifest_Line_Item__c>();
            for (Product_Package__c pkg : packages) {
                Decimal netWeight = (pkg.Net_Weight_Grams__c != null) ? pkg.Net_Weight_Grams__c : 10.0;
                Decimal grossWeight = (netWeight * 1.15).setScale(2, RoundingMode.HALF_UP);

                lineItems.add(new Manifest_Line_Item__c(
                    Transfer_Manifest__c = newManifest.Id,
                    Product_Package__c = pkg.Id,
                    Package_RFID__c = pkg.RFID_Tag__c,
                    Gross_Weight_Grams__c = grossWeight,
                    Item_Count__c = 1
                ));
            }

            if (!lineItems.isEmpty()) {
                Database.insert(lineItems, AccessLevel.USER_MODE);
            }
        }

        return getManifestDetails(newManifest.Id);
    }

    /**
     * @description Digitally signs a manifest in a specified custodial role and advances lifecycle status.
     * @param manifestId Salesforce ID of the Transfer_Manifest__c.
     * @param role Signer role ('Dispatcher', 'Transporter', 'Receiver').
     * @param signatureName Signer legal name for attestation.
     * @return Updated Transfer_Manifest__c record.
     */
    @AuraEnabled
    public static Transfer_Manifest__c signManifest(Id manifestId, String role, String signatureName) {
        if (manifestId == null) {
            throw createAuraException('Manifest ID is required.');
        }

        if (String.isBlank(signatureName)) {
            throw createAuraException('Legal signature name is required for digital attestation.');
        }

        if (String.isBlank(role)) {
            throw createAuraException('Signer role is required.');
        }

        Transfer_Manifest__c manifest = [
            SELECT Id, Status__c, Dispatcher_Signature__c, Transporter_Signature__c,
                   Receiver_Signature__c, Departure_Timestamp__c, Actual_Arrival__c,
                   Destination_Facility__c
            FROM Transfer_Manifest__c
            WHERE Id = :manifestId
            WITH USER_MODE
            LIMIT 1
        ];

        String timestampStr = System.now().format('yyyy-MM-dd HH:mm:ss');
        String digitalSignature = signatureName.trim() + ' | ' + timestampStr + ' UTC';

        String normalizedRole = role.trim().toUpperCase();

        if (normalizedRole == 'DISPATCHER') {
            manifest.Dispatcher_Signature__c = digitalSignature;
            manifest.Status__c = 'Dispatched';
            if (manifest.Departure_Timestamp__c == null) {
                manifest.Departure_Timestamp__c = System.now();
            }
        } else if (normalizedRole == 'TRANSPORTER') {
            manifest.Transporter_Signature__c = digitalSignature;
            manifest.Status__c = 'In Transit';
        } else if (normalizedRole == 'RECEIVER') {
            manifest.Receiver_Signature__c = digitalSignature;
            manifest.Status__c = 'Delivered';
            manifest.Actual_Arrival__c = System.now();
        } else {
            throw createAuraException('Invalid signer role: ' + role + '. Allowed roles: Dispatcher, Transporter, Receiver.');
        }

        Database.update(manifest, AccessLevel.USER_MODE);

        return getManifestDetails(manifest.Id);
    }

    /**
     * @description Retrieves active commercial facility Accounts for selector dropdowns.
     * @return List of Account records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getFacilities() {
        return [
            SELECT Id, Name, Facility_Type__c, Premise_Registry_ID__c, Compliance_Status__c
            FROM Account
            WHERE Facility_Type__c != null
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    /**
     * @description Retrieves packaged inventory eligible for manifest inclusion at a facility.
     * @param facilityId Holding facility Account ID.
     * @return List of eligible Product_Package__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Product_Package__c> getAvailablePackages(Id facilityId) {
        if (facilityId == null) {
            return new List<Product_Package__c>();
        }

        return [
            SELECT Id, Name, RFID_Tag__c, Product_Type__c, Net_Weight_Grams__c,
                   Package_Status__c, Status__c, Lab_Safety_Status__c
            FROM Product_Package__c
            WHERE Holding_Facility__c = :facilityId
              AND Package_Status__c IN ('Ready_for_Sale', 'In_Stock')
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }
}
