Data360Service.TelemetryRecord rec = new Data360Service.TelemetryRecord();
rec.eventId = 'EVT-LIVE-TEST-001';
rec.rfidTag = '1A4000312678D88325136FEF';
rec.facilityId = '001hm00000AOebMAAT';
rec.roomLocation = 'Vault Alpha - Secured Shelf 4';
rec.metricReading = 530.00;
rec.actionType = 'RFID_SCAN';
rec.operatorUserId = UserInfo.getUserId();
rec.eventTimestamp = Datetime.now();
rec.isArchived = false;

try {
    Map<String, Object> res = Data360Service.createTelemetryEvent(rec);
    System.debug('LIVE_INGEST_SUCCESS: ' + JSON.serialize(res));
} catch (Exception ex) {
    System.debug('LIVE_INGEST_ERROR: ' + ex.getMessage());
}