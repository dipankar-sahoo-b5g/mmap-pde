String eventId = 'EVT-1793959142618-708666';
Map<String, Object> updateRes = Data360Controller.updateEvent(eventId, 'Keystone Curing Zone 4', 450.00);
System.debug('LWC_UPDATE_EVENT: ' + JSON.serialize(updateRes));

Map<String, Object> archiveRes = Data360Controller.archiveEvent(eventId);
System.debug('LWC_ARCHIVE_EVENT: ' + JSON.serialize(archiveRes));

