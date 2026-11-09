Id pkgId = 'a03hm000002tz6oAAA';
Map<String, Object> queryRes = Data360Controller.getTelemetryEvents(pkgId, 10, 0);
System.debug('LWC_GET_TELEMETRY: ' + JSON.serialize(queryRes));

Map<String, Object> logRes = Data360Controller.logTelemetryEvent(
    pkgId,
    'Keystone Primary Vault Alpha',
    442.75,
    'RFID_SCAN'
);
System.debug('LWC_LOG_EVENT: ' + JSON.serialize(logRes));

Map<String, Object> recheckRes = Data360Controller.getTelemetryEvents(pkgId, 10, 0);
System.debug('LWC_RECHECK_AFTER_LOG: ' + JSON.serialize(recheckRes));

