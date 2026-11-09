/**
 * @description Lightning Web Component Controller for Data 360 Lakehouse Telemetry.
 *              Exposes methods for retrieving, streaming, updating, and archiving
 *              RFID and sensor telemetry logs associated with Product Packages and Plant Batches.
 */
public with sharing class Data360Controller {

    /**
     * @description Helper structure to encapsulate resolved context from SObject.
     */
    private class RecordContext {
        public String rfidTag;
        public String facilityId;
        public String recordName;
        public String defaultRoom;
        public String sObjectType;
    }

    /**
     * @description Retrieves historical telemetry logs from Data 360 for the given record.
     * @param recordId Salesforce ID of Product_Package__c or Plant_Batch__c.
     * @param pageSize Number of rows per page.
     * @param offset Starting row index.
     * @return Map containing records, pagination metadata, and record context.
     */
    @AuraEnabled
    public static Map<String, Object> getTelemetryEvents(Id recordId, Integer pageSize, Integer offset) {
        try {
            RecordContext ctx = resolveRecordContext(recordId);
            Map<String, Object> result = Data360Service.queryTelemetryEvents(ctx.rfidTag, pageSize, offset);
            result.put('rfidTag', ctx.rfidTag);
            result.put('facilityId', ctx.facilityId);
            result.put('recordName', ctx.recordName);
            result.put('defaultRoom', ctx.defaultRoom);
            result.put('sObjectType', ctx.sObjectType);
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    /**
     * @description Ingests a new telemetry or RFID movement event into Data 360.
     * @param recordId Salesforce ID of the parent package or batch.
     * @param roomLocation Room or physical zone identifier.
     * @param metricReading Scale weight in grams or sensor metric value.
     * @param actionType Regulatory action category (STAGE_MOVE, RFID_SCAN, SAMPLE_TEST, DISPENSED).
     * @return Map containing status, eventId, and timestamp.
     */
    @AuraEnabled
    public static Map<String, Object> logTelemetryEvent(
        Id recordId,
        String roomLocation,
        Decimal metricReading,
        String actionType
    ) {
        try {
            if (String.isBlank(actionType)) {
                throw new AuraHandledException('Action Type is required to log a telemetry event.');
            }

            RecordContext ctx = resolveRecordContext(recordId);
            String finalRoom = String.isNotBlank(roomLocation) ? roomLocation : ctx.defaultRoom;
            String operatorUserId = UserInfo.getUserId();

            return Data360Service.createTelemetryEvent(
                ctx.rfidTag,
                ctx.facilityId,
                finalRoom,
                metricReading,
                actionType,
                operatorUserId
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    /**
     * @description Updates an existing telemetry event in Data 360.
     * @param eventId UUID of the telemetry record.
     * @param roomLocation Updated room / zone.
     * @param metricReading Updated metric reading.
     * @return Map containing status, eventId, and modifiedAt.
     */
    @AuraEnabled
    public static Map<String, Object> updateEvent(String eventId, String roomLocation, Decimal metricReading) {
        try {
            if (String.isBlank(eventId)) {
                throw new AuraHandledException('Event ID is required to update a telemetry log.');
            }
            return Data360Service.updateTelemetryEvent(eventId, roomLocation, metricReading);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    /**
     * @description Archives (soft-deletes) an existing telemetry event in Data 360 for audit compliance.
     * @param eventId UUID of the telemetry record.
     * @return Map containing status, eventId, and isArchived boolean.
     */
    @AuraEnabled
    public static Map<String, Object> archiveEvent(String eventId) {
        try {
            if (String.isBlank(eventId)) {
                throw new AuraHandledException('Event ID is required to archive a telemetry log.');
            }
            return Data360Service.archiveTelemetryEvent(eventId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            e.setMessage(ex.getMessage());
            throw e;
        }
    }

    /**
     * @description Resolves RFID tracking tag and facility information from parent record ID.
     */
    private static RecordContext resolveRecordContext(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record ID cannot be null.');
        }

        RecordContext ctx = new RecordContext();
        String sObjName = recordId.getSobjectType().getDescribe().getName();
        ctx.sObjectType = sObjName;

        if (sObjName == 'Product_Package__c') {
            List<Product_Package__c> pkgs = [
                SELECT Id, Name, RFID_Tag__c, Holding_Facility__c, Plant_Batch__r.Room_Location__c
                FROM Product_Package__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (pkgs.isEmpty()) {
                throw new AuraHandledException('Product Package not found: ' + recordId);
            }
            Product_Package__c pkg = pkgs[0];
            ctx.rfidTag = String.isNotBlank(pkg.RFID_Tag__c) ? pkg.RFID_Tag__c : pkg.Name;
            ctx.facilityId = String.valueOf(pkg.Holding_Facility__c);
            ctx.recordName = pkg.Name;
            ctx.defaultRoom = (pkg.Plant_Batch__r != null && String.isNotBlank(pkg.Plant_Batch__r.Room_Location__c))
                ? pkg.Plant_Batch__r.Room_Location__c
                : 'Vault Storage';

        } else if (sObjName == 'Plant_Batch__c') {
            List<Plant_Batch__c> batches = [
                SELECT Id, Name, Cultivator__c, Room_Location__c
                FROM Plant_Batch__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (batches.isEmpty()) {
                throw new AuraHandledException('Plant Batch not found: ' + recordId);
            }
            Plant_Batch__c batch = batches[0];
            ctx.rfidTag = batch.Name;
            ctx.facilityId = String.valueOf(batch.Cultivator__c);
            ctx.recordName = batch.Name;
            ctx.defaultRoom = String.isNotBlank(batch.Room_Location__c)
                ? batch.Room_Location__c
                : 'Cultivation Bay';

        } else {
            throw new AuraHandledException(
                'Unsupported SObject type: ' + sObjName +
                '. Telemetry integration is only supported for Product_Package__c and Plant_Batch__c.'
            );
        }

        return ctx;
    }
}
