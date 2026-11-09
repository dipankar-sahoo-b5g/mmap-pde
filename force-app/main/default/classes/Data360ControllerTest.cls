/**
 * @description Comprehensive unit test suite for Data360Service and Data360Controller.
 *              Validates both in-memory Mock Engine and native Data Cloud Lakehouse HTTP REST callouts
 *              (Ingestion API and Query API v2 ANSI SQL), covering CRUD lifecycles for
 *              Product_Package__c and Plant_Batch__c, pagination, error handling, and edge cases.
 */
@isTest
private class Data360ControllerTest {

    /**
     * @description HTTP Mock implementation simulating native Data Cloud Lakehouse REST endpoints:
     *              - Ingestion API: /api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event (HTTP 202)
     *              - Query API v2: /services/a360/query/v2 (HTTP 200 with ANSI SQL tabular response)
     */
    public class Data360HttpMock implements HttpCalloutMock {
        private Integer statusCode;

        public Data360HttpMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (this.statusCode >= 400) {
                res.setStatusCode(this.statusCode);
                res.setStatus('Error');
                res.setBody('{"error": "Simulated Data Cloud error", "code": ' + this.statusCode + '}');
                return res;
            }

            String endpoint = req.getEndpoint();
            if (endpoint != null && (endpoint.contains('/services/a360/query/v2') || endpoint.contains('/api/v2/query'))) {
                res.setStatusCode(200);
                res.setStatus('OK');
                // Native Data Cloud Query v2 ANSI SQL tabular response format
                String tabularJson = '{"data": [[' +
                    '"e9b2c34a-9e12-4f62-8172-10f84a329c11",' +
                    '"1A4000312678000000001234",' +
                    '"001hm000003JkLM",' +
                    '"Curing Room 3",' +
                    '450.25,' +
                    '"STAGE_MOVE",' +
                    '"005hm000002oKYf",' +
                    '"2026-11-05T18:45:00Z",' +
                    'false' +
                ']],' +
                '"metadata": [' +
                    '{"name": "Event_ID__c", "type": "VARCHAR"},' +
                    '{"name": "RFID_Tag__c", "type": "VARCHAR"},' +
                    '{"name": "Facility_ID__c", "type": "VARCHAR"},' +
                    '{"name": "Room_Location__c", "type": "VARCHAR"},' +
                    '{"name": "Metric_Reading__c", "type": "NUMBER"},' +
                    '{"name": "Action_Type__c", "type": "VARCHAR"},' +
                    '{"name": "Operator_User_ID__c", "type": "VARCHAR"},' +
                    '{"name": "Event_Timestamp__c", "type": "TIMESTAMP"},' +
                    '{"name": "Is_Archived__c", "type": "BOOLEAN"}' +
                '],' +
                '"rowCount": 1,' +
                '"done": true}';
                res.setBody(tabularJson);
            } else if (endpoint != null && endpoint.contains('/api/v1/ingest/sources/')) {
                // Native Data Cloud Ingest API response format (HTTP 202 Accepted)
                res.setStatusCode(202);
                res.setStatus('Accepted');
                res.setBody('{"status": "ACCEPTED", "acceptedCount": 1}');
            } else {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"status": "OK"}');
            }
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Facility Account
        Account facility = new Account(
            Name = 'Keystone Testing Facility',
            Premise_Registry_ID__c = 'FAC-TEST-0077',
            Facility_Type__c = 'Grower_Processor',
            Compliance_Status__c = 'Compliant',
            Vault_Capacity_Grams__c = 100000.00
        );
        insert facility;

        // Cannabis Strain
        Strain__c strain = new Strain__c(
            Name = 'Granddaddy Purple Test',
            Classification__c = 'Indica',
            Target_THC_Percentage__c = 22.00,
            Target_CBD_Percentage__c = 0.50,
            Is_Active__c = true
        );
        insert strain;

        // Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = facility.Id,
            Strain__c = strain.Id,
            Planted_Date__c = Date.today().addDays(-30),
            Growth_Stage__c = 'Vegetative',
            Initial_Plant_Count__c = 50,
            Current_Plant_Count__c = 50,
            Room_Location__c = 'Grow Bay Beta'
        );
        insert batch;

        // Product Package
        Product_Package__c pkg = new Product_Package__c(
            Holding_Facility__c = facility.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 40.00,
            RFID_Tag__c = '1A4000312678000000001234',
            Package_Status__c = 'In_Testing',
            Lab_Safety_Status__c = 'Untested'
        );
        insert pkg;
    }

    /**
     * @description Tests mock mode lifecycle using a Product_Package__c record:
     *              1. Query telemetry (auto-seeds baseline logs).
     *              2. Ingest new event (STAGE_MOVE).
     *              3. In-place update of metric and room location.
     *              4. Archival (soft-delete).
     */
    @isTest
    static void testMockModeProductPackageLifecycle() {
        Product_Package__c pkg = [SELECT Id, RFID_Tag__c FROM Product_Package__c LIMIT 1];
        Data360Service.isMockMode = true;
        Data360Service.resetMockStore();

        Test.startTest();

        // 1. Initial query - seeds mock data
        Map<String, Object> queryResult = Data360Controller.getTelemetryEvents(pkg.Id, 10, 0);
        System.assertNotEquals(null, queryResult);
        System.assertEquals(pkg.RFID_Tag__c, (String) queryResult.get('rfidTag'));
        Integer initialCount = (Integer) queryResult.get('totalRecords');
        System.assert(initialCount > 0, 'Seeded records should be present');

        // 2. Ingest new telemetry event
        Map<String, Object> createResult = Data360Controller.logTelemetryEvent(
            pkg.Id,
            'Secure Vault A',
            455.50,
            'STAGE_MOVE'
        );
        System.assertEquals('SUCCESS', (String) createResult.get('status'));
        String newEventId = (String) createResult.get('eventId');
        System.assertNotEquals(null, newEventId, 'Generated Event ID should not be null');

        // 3. Update the event
        Map<String, Object> updateResult = Data360Controller.updateEvent(
            newEventId,
            'Packaging Room 2',
            454.00
        );
        System.assertEquals('UPDATED', (String) updateResult.get('status'));
        System.assertEquals(newEventId, (String) updateResult.get('eventId'));

        // 4. Archive the event
        Map<String, Object> archiveResult = Data360Controller.archiveEvent(newEventId);
        System.assertEquals('ARCHIVED', (String) archiveResult.get('status'));
        System.assertEquals(true, (Boolean) archiveResult.get('isArchived'));

        // Re-query to verify new record state
        Map<String, Object> recheckResult = Data360Controller.getTelemetryEvents(pkg.Id, 10, 0);
        System.assertEquals(initialCount + 1, (Integer) recheckResult.get('totalRecords'));

        Test.stopTest();
    }

    /**
     * @description Tests mock mode lifecycle using a Plant_Batch__c record.
     */
    @isTest
    static void testMockModePlantBatchLifecycle() {
        Plant_Batch__c batch = [SELECT Id, Name, Room_Location__c FROM Plant_Batch__c LIMIT 1];
        Data360Service.isMockMode = true;
        Data360Service.resetMockStore();

        Test.startTest();

        // Query telemetry for plant batch
        Map<String, Object> queryResult = Data360Controller.getTelemetryEvents(batch.Id, 5, 0);
        System.assertNotEquals(null, queryResult);
        System.assertEquals(batch.Name, (String) queryResult.get('rfidTag'));
        System.assertEquals('Plant_Batch__c', (String) queryResult.get('sObjectType'));

        // Log an RFID scan telemetry event with blank room (should fallback to batch's room)
        Map<String, Object> createResult = Data360Controller.logTelemetryEvent(
            batch.Id,
            null, // should default to batch.Room_Location__c
            120.00,
            'RFID_SCAN'
        );
        System.assertEquals('SUCCESS', (String) createResult.get('status'));
        String eventId = (String) createResult.get('eventId');
        System.assertNotEquals(null, eventId);

        // Query again
        Map<String, Object> recheck = Data360Controller.getTelemetryEvents(batch.Id, 10, 0);
        System.assert((Integer) recheck.get('totalRecords') > 0);

        Test.stopTest();
    }

    /**
     * @description Validates native Data Cloud Lakehouse REST callouts against callout:Data360_API
     *              using HttpCalloutMock when isMockMode is false.
     */
    @isTest
    static void testLiveCalloutSuccess() {
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];
        Data360Service.isMockMode = false;
        Test.setMock(HttpCalloutMock.class, new Data360HttpMock(200));

        Test.startTest();

        // Live Query
        Map<String, Object> queryResult = Data360Controller.getTelemetryEvents(pkg.Id, 10, 0);
        System.assertNotEquals(null, queryResult);
        System.assertEquals(1, (Integer) queryResult.get('totalRecords'));

        // Live Create
        Map<String, Object> createResult = Data360Controller.logTelemetryEvent(
            pkg.Id,
            'Curing Room 3',
            450.25,
            'STAGE_MOVE'
        );
        System.assertEquals('SUCCESS', (String) createResult.get('status'));

        // Live Update
        Map<String, Object> updateResult = Data360Controller.updateEvent(
            'e9b2c34a-9e12-4f62-8172-10f84a329c11',
            'Vault 1',
            448.00
        );
        System.assertEquals('UPDATED', (String) updateResult.get('status'));

        // Live Archive
        Map<String, Object> archiveResult = Data360Controller.archiveEvent(
            'e9b2c34a-9e12-4f62-8172-10f84a329c11'
        );
        System.assertEquals('ARCHIVED', (String) archiveResult.get('status'));

        Test.stopTest();
    }

    /**
     * @description Validates error handling when live HTTP callouts return non-200 responses.
     */
    @isTest
    static void testLiveCalloutFailures() {
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];
        Data360Service.isMockMode = false;
        Test.setMock(HttpCalloutMock.class, new Data360HttpMock(500));

        Test.startTest();

        // Test Live Query Failure
        Boolean queryFailed = false;
        try {
            Data360Controller.getTelemetryEvents(pkg.Id, 10, 0);
        } catch (AuraHandledException e) {
            queryFailed = true;
        }
        System.assertEquals(true, queryFailed, 'Live query should throw AuraHandledException on HTTP 500');

        // Test Live Ingest Failure
        Boolean ingestFailed = false;
        try {
            Data360Controller.logTelemetryEvent(pkg.Id, 'Vault', 10.0, 'RFID_SCAN');
        } catch (AuraHandledException e) {
            ingestFailed = true;
        }
        System.assertEquals(true, ingestFailed, 'Live ingest should throw AuraHandledException on HTTP 500');

        // Test Live Update Failure
        Boolean updateFailed = false;
        try {
            Data360Controller.updateEvent('some-id', 'Room', 1.0);
        } catch (AuraHandledException e) {
            updateFailed = true;
        }
        System.assertEquals(true, updateFailed, 'Live update should throw AuraHandledException on HTTP 500');

        // Test Live Archive Failure
        Boolean archiveFailed = false;
        try {
            Data360Controller.archiveEvent('some-id');
        } catch (AuraHandledException e) {
            archiveFailed = true;
        }
        System.assertEquals(true, archiveFailed, 'Live archive should throw AuraHandledException on HTTP 500');

        Test.stopTest();
    }

    /**
     * @description Validates parameter validation, unsupported objects, and edge cases.
     */
    @isTest
    static void testValidationAndDefensiveChecks() {
        Account facility = [SELECT Id FROM Account LIMIT 1];
        Product_Package__c pkg = [SELECT Id FROM Product_Package__c LIMIT 1];
        Data360Service.isMockMode = true;

        Test.startTest();

        // 1. Null Record ID in getTelemetryEvents
        Boolean nullIdCaught = false;
        try {
            Data360Controller.getTelemetryEvents(null, 10, 0);
        } catch (AuraHandledException e) {
            nullIdCaught = true;
        }
        System.assertEquals(true, nullIdCaught);

        // 2. Unsupported SObject type (Account)
        Boolean unsupportedCaught = false;
        try {
            Data360Controller.getTelemetryEvents(facility.Id, 10, 0);
        } catch (AuraHandledException e) {
            unsupportedCaught = true;
        }
        System.assertEquals(true, unsupportedCaught);

        // 3. Blank Action Type in logTelemetryEvent
        Boolean blankActionCaught = false;
        try {
            Data360Controller.logTelemetryEvent(pkg.Id, 'Vault', 10.0, '');
        } catch (AuraHandledException e) {
            blankActionCaught = true;
        }
        System.assertEquals(true, blankActionCaught);

        // 4. Blank Event ID in updateEvent
        Boolean blankUpdateCaught = false;
        try {
            Data360Controller.updateEvent('', 'Room', 10.0);
        } catch (AuraHandledException e) {
            blankUpdateCaught = true;
        }
        System.assertEquals(true, blankUpdateCaught);

        // 5. Blank Event ID in archiveEvent
        Boolean blankArchiveCaught = false;
        try {
            Data360Controller.archiveEvent('');
        } catch (AuraHandledException e) {
            blankArchiveCaught = true;
        }
        System.assertEquals(true, blankArchiveCaught);

        // 6. Direct Data360Service validation
        Boolean serviceNullRecCaught = false;
        try {
            Data360Service.createTelemetryEvent(null);
        } catch (IllegalArgumentException e) {
            serviceNullRecCaught = true;
        }
        System.assertEquals(true, serviceNullRecCaught);

        Boolean serviceBlankRfidCaught = false;
        try {
            Data360Service.queryTelemetryEvents('', 10, 0);
        } catch (IllegalArgumentException e) {
            serviceBlankRfidCaught = true;
        }
        System.assertEquals(true, serviceBlankRfidCaught);

        Boolean serviceBlankUpdateCaught = false;
        try {
            Data360Service.updateTelemetryEvent('', 'Room', 1.0);
        } catch (IllegalArgumentException e) {
            serviceBlankUpdateCaught = true;
        }
        System.assertEquals(true, serviceBlankUpdateCaught);

        Boolean serviceBlankArchiveCaught = false;
        try {
            Data360Service.archiveTelemetryEvent('');
        } catch (IllegalArgumentException e) {
            serviceBlankArchiveCaught = true;
        }
        System.assertEquals(true, serviceBlankArchiveCaught);

        Test.stopTest();
    }

    /**
     * @description Direct unit test for the TelemetryRecord data structure class.
     */
    @isTest
    static void testTelemetryRecordDataStructure() {
        Test.startTest();

        Data360Service.TelemetryRecord rec1 = new Data360Service.TelemetryRecord();
        rec1.eventId = 'test-id';
        rec1.rfidTag = '1A4000312678000000001234';
        rec1.facilityId = '001hm000003JkLM';
        rec1.eventTimestamp = Datetime.now();
        rec1.roomLocation = 'Vault Alpha';
        rec1.metricReading = 100.50;
        rec1.actionType = 'RFID_SCAN';
        rec1.operatorUserId = UserInfo.getUserId();
        rec1.isArchived = false;

        System.assertEquals('test-id', rec1.eventId);
        System.assertEquals(100.50, rec1.metricReading);
        System.assertEquals(false, rec1.isArchived);

        Data360Service.TelemetryRecord rec2 = new Data360Service.TelemetryRecord(
            'uuid-2',
            '1A4000312678000000001234',
            '001hm000003JkLM',
            Datetime.now(),
            'Room Beta',
            200.00,
            'STAGE_MOVE',
            UserInfo.getUserId(),
            true
        );
        System.assertEquals('uuid-2', rec2.eventId);
        System.assertEquals(true, rec2.isArchived);

        Test.stopTest();
    }

    /**
     * @description Validates Data Cloud Query response parser across tabular and record formats.
     */
    @isTest
    static void testDataCloudFallbackQueryParsing() {
        Test.startTest();

        // 1. Tabular parsing without metadata
        Map<String, Object> tabularNoMeta = new Map<String, Object>{
            'data' => new List<Object>{
                new List<Object>{
                    'EVT-TAB-01',
                    '1A4000312678000000009999',
                    '001hm000003JkLM',
                    'Drying Room 1',
                    120.50,
                    'STAGE_MOVE',
                    UserInfo.getUserId(),
                    '2026-11-06T12:00:00Z',
                    false
                }
            },
            'rowCount' => 1
        };
        List<Data360Service.TelemetryRecord> parsedTab = Data360Service.parseRecordsFromRaw(tabularNoMeta);
        System.assertEquals(1, parsedTab.size());
        System.assertEquals('EVT-TAB-01', parsedTab[0].eventId);
        System.assertEquals(120.50, parsedTab[0].metricReading);

        // 2. DLM REST / Record map parsing with __c fields
        Map<String, Object> mapResCustom = new Map<String, Object>{
            'data' => new List<Object>{
                new Map<String, Object>{
                    'Event_ID__c' => 'EVT-MAP-01',
                    'RFID_Tag__c' => '1A4000312678000000008888',
                    'Facility_ID__c' => '001hm000003JkLM',
                    'Room_Location__c' => 'Extraction Lab',
                    'Metric_Reading__c' => 500.00,
                    'Action_Type__c' => 'SAMPLE_TEST',
                    'Operator_User_ID__c' => UserInfo.getUserId(),
                    'Event_Timestamp__c' => '2026-11-06T12:00:00Z',
                    'Is_Archived__c' => false
                }
            },
            'totalRecords' => 1
        };
        List<Data360Service.TelemetryRecord> parsedMap = Data360Service.parseRecordsFromRaw(mapResCustom);
        System.assertEquals(1, parsedMap.size());
        System.assertEquals('EVT-MAP-01', parsedMap[0].eventId);

        // 3. Fallback camelCase records parsing
        Map<String, Object> mapResCamel = new Map<String, Object>{
            'records' => new List<Object>{
                new Map<String, Object>{
                    'eventId' => 'EVT-CAMEL-01',
                    'rfidTag' => '1A4000312678000000007777',
                    'facilityId' => '001hm000003JkLM',
                    'roomLocation' => 'Vault Alpha',
                    'metricReading' => 300.00,
                    'actionType' => 'RFID_SCAN',
                    'operatorUserId' => UserInfo.getUserId(),
                    'eventTimestamp' => '2026-11-06T12:00:00Z',
                    'isArchived' => true
                }
            }
        };
        List<Data360Service.TelemetryRecord> parsedCamel = Data360Service.parseRecordsFromRaw(mapResCamel);
        System.assertEquals(1, parsedCamel.size());
        System.assertEquals('EVT-CAMEL-01', parsedCamel[0].eventId);
        System.assertEquals(true, parsedCamel[0].isArchived);

        Test.stopTest();
    }

    /**
     * @description Validates advanced parser data type conversions (Double, Integer, Long, Datetime formats).
     */
    @isTest
    static void testData360ServiceParserAdvancedTypes() {
        Test.startTest();

        // Null and empty structures
        System.assertEquals(0, Data360Service.parseRecordsFromRaw(null).size());
        System.assertEquals(0, Data360Service.parseRecordsFromRaw(new Map<String, Object>()).size());
        System.assertEquals(0, Data360Service.parseRecordsFromRaw(new Map<String, Object>{ 'data' => new List<Object>() }).size());

        // Tabular parsing with column metadata and mixed numeric / boolean / date types
        Map<String, Object> tabMixed = new Map<String, Object>{
            'metadata' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Event_ID__c' },
                new Map<String, Object>{ 'name' => 'RFID_Tag__c' },
                new Map<String, Object>{ 'name' => 'Facility_ID__c' },
                new Map<String, Object>{ 'name' => 'Room_Location__c' },
                new Map<String, Object>{ 'name' => 'Metric_Reading__c' },
                new Map<String, Object>{ 'name' => 'Action_Type__c' },
                new Map<String, Object>{ 'name' => 'Operator_User_ID__c' },
                new Map<String, Object>{ 'name' => 'Event_Timestamp__c' },
                new Map<String, Object>{ 'name' => 'Is_Archived__c' }
            },
            'data' => new List<Object>{
                // Row with Double metric, Integer 1 boolean, Datetime object
                new List<Object>{
                    'EVT-MIX-01', 'TAG-01', 'FAC-01', 'Room 1', (Double) 123.45, 'RFID_SCAN', '005000000000001', Datetime.now(), (Integer) 1
                },
                // Row with Integer metric, Boolean true, Long timestamp millis
                new List<Object>{
                    'EVT-MIX-02', 'TAG-02', 'FAC-02', 'Room 2', (Integer) 150, 'STAGE_MOVE', '005000000000002', System.currentTimeMillis(), true
                },
                // Row with Long metric, String boolean 'true', ISO string without milliseconds
                new List<Object>{
                    'EVT-MIX-03', 'TAG-03', 'FAC-03', 'Room 3', (Long) 250000L, 'DISPENSED', '005000000000003', '2026-11-06T15:30:00Z', 'true'
                },
                // Row with String metric, String boolean 'false', standard datetime string
                new List<Object>{
                    'EVT-MIX-04', 'TAG-04', 'FAC-04', 'Room 4', '375.80', 'SAMPLE_TEST', '005000000000004', '2026-11-06 15:30:00', 'false'
                }
            }
        };

        List<Data360Service.TelemetryRecord> parsed = Data360Service.parseRecordsFromRaw(tabMixed);
        System.assertEquals(4, parsed.size());
        System.assertEquals(123.45, parsed[0].metricReading);
        System.assertEquals(true, parsed[0].isArchived);
        System.assertEquals(150.00, parsed[1].metricReading);
        System.assertEquals(true, parsed[1].isArchived);
        System.assertEquals(250000.00, parsed[2].metricReading);
        System.assertEquals(true, parsed[2].isArchived);
        System.assertEquals(375.80, parsed[3].metricReading);
        System.assertEquals(false, parsed[3].isArchived);

        // Map format with Double, Integer, Long, String metrics and Integer booleans
        Map<String, Object> mapMixed = new Map<String, Object>{
            'data' => new List<Object>{
                new Map<String, Object>{
                    'eventId' => 'EVT-MAP-01',
                    'rfidTag' => 'TAG-M1',
                    'metricReading' => (Double) 99.99,
                    'isArchived' => (Integer) 1
                },
                new Map<String, Object>{
                    'eventId' => 'EVT-MAP-02',
                    'rfidTag' => 'TAG-M2',
                    'metricReading' => (Integer) 88,
                    'isArchived' => (Integer) 0
                },
                new Map<String, Object>{
                    'eventId' => 'EVT-MAP-03',
                    'rfidTag' => 'TAG-M3',
                    'metricReading' => (Long) 77777L,
                    'isArchived' => 'true'
                },
                new Map<String, Object>{
                    'eventId' => 'EVT-MAP-04',
                    'rfidTag' => 'TAG-M4',
                    'metricReading' => '66.50',
                    'isArchived' => 'false'
                }
            }
        };
        List<Data360Service.TelemetryRecord> parsedMaps = Data360Service.parseRecordsFromRaw(mapMixed);
        System.assertEquals(4, parsedMaps.size());
        System.assertEquals(99.99, parsedMaps[0].metricReading);
        System.assertEquals(true, parsedMaps[0].isArchived);
        System.assertEquals(88.00, parsedMaps[1].metricReading);
        System.assertEquals(false, parsedMaps[1].isArchived);
        System.assertEquals(77777.00, parsedMaps[2].metricReading);
        System.assertEquals(true, parsedMaps[2].isArchived);
        System.assertEquals(66.50, parsedMaps[3].metricReading);
        System.assertEquals(false, parsedMaps[3].isArchived);

        Test.stopTest();
    }

    /**
     * @description Validates live callout error handling and fetchEventById live resolution.
     */
    @isTest
    static void testData360ServiceLiveEdgeCases() {
        Test.startTest();

        // 1. Live Callout 500 error on query
        Data360Service.isMockMode = false;
        Test.setMock(HttpCalloutMock.class, new Data360HttpMock(500));
        try {
            Data360Service.queryTelemetryEvents('TAG-ERR-001', 5, 0);
            System.assert(false, 'Should throw CalloutException on HTTP 500.');
        } catch (CalloutException ce) {
            System.assert(ce.getMessage().contains('Data Cloud Query Failed'));
        }

        // 2. Live Callout 500 error on create
        try {
            Data360Service.TelemetryRecord rec = new Data360Service.TelemetryRecord();
            rec.rfidTag = 'TAG-ERR-002';
            Data360Service.createTelemetryEvent(rec);
            System.assert(false, 'Should throw CalloutException on create HTTP 500.');
        } catch (CalloutException ce) {
            System.assert(ce.getMessage().contains('Data Cloud Ingest Failed'));
        }

        // 3. Live Callout successful fetchEventById for update and archive
        Test.setMock(HttpCalloutMock.class, new Data360HttpMock(200));
        Map<String, Object> updateRes = Data360Service.updateTelemetryEvent('EVT-REMOTE-99', 'Vault Live', 777.00);
        System.assertEquals('UPDATED', updateRes.get('status'));

        Map<String, Object> archiveRes = Data360Service.archiveTelemetryEvent('EVT-REMOTE-99');
        System.assertEquals('ARCHIVED', archiveRes.get('status'));

        // 4. Create event with null optional fields in both mock and live mode
        Data360Service.isMockMode = true;
        Data360Service.TelemetryRecord mockRec = new Data360Service.TelemetryRecord();
        mockRec.rfidTag = 'TAG-NULL-001';
        Map<String, Object> mockCreate = Data360Service.createTelemetryEvent(mockRec);
        System.assertEquals('SUCCESS', mockCreate.get('status'));

        Data360Service.isMockMode = false;
        Data360Service.TelemetryRecord liveRec = new Data360Service.TelemetryRecord();
        liveRec.rfidTag = 'TAG-NULL-002';
        Map<String, Object> liveCreate = Data360Service.createTelemetryEvent(liveRec);
        System.assertEquals('SUCCESS', liveCreate.get('status'));

        Test.stopTest();
    }
}
