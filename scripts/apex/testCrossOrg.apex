HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Data360_API/api/v1/telemetry');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
Map<String, Object> payload = new Map<String, Object>{
    'rfidTag' => 'LIVE-CROSS-ORG-001',
    'facilityId' => 'FAC-999',
    'roomLocation' => 'Testing Vault 1',
    'metricReading' => 99.99,
    'actionType' => 'RFID_SCAN',
    'operatorUserId' => UserInfo.getUserId()
};
req.setBody(JSON.serialize(payload));
Http http = new Http();
HttpResponse res = http.send(req);
System.debug('POST_STATUS: ' + res.getStatusCode() + ' BODY: ' + res.getBody());

