Data360Service.isMockMode = false;
Map<String, Object> updateRes = Data360Service.updateTelemetryEvent('EVT-1793958329041-115766', 'Testing Vault 2 Updated', 105.50);
System.debug('UPDATE_RESULT: ' + JSON.serialize(updateRes));

Map<String, Object> archiveRes = Data360Service.archiveTelemetryEvent('EVT-1793958329041-115766');
System.debug('ARCHIVE_RESULT: ' + JSON.serialize(archiveRes));

