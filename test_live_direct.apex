HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Data360_API/api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Accept', 'application/json');
req.setBody('{"data":[{"eventId":"EVT-1793968853465-147384","rfidTag":"1A4000312678D88325136FEF","facilityId":"001hm00000AOebMAAT","roomLocation":"Vault Alpha","metricReading":530.0,"actionType":"RFID_SCAN","operatorUserId":"005hm000002oKYfAAM","eventTimestamp":"2026-11-08T12:40:53Z","isArchived":false}]}');

Http h = new Http();
HttpResponse res = h.send(req);
System.debug('HTTP_STATUS: ' + res.getStatusCode());
System.debug('HTTP_BODY: ' + res.getBody());
