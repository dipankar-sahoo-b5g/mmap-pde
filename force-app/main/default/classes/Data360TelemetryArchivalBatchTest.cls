/**
 * @description Comprehensive unit test suite for Data360TelemetryArchivalBatch.
 *              Validates batch processing, stateful metrics aggregation, schedulable execution,
 *              custom queries, and live Data Cloud Lakehouse callouts for the archival pipeline.
 */
@isTest
private class Data360TelemetryArchivalBatchTest {

    /**
     * @description HTTP Mock implementation simulating native Data Cloud Lakehouse REST endpoints:
     *              - Ingestion API: /api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event (HTTP 202)
     *              - Query API v2: /services/a360/query/v2 (HTTP 200 with ANSI SQL tabular response)
     */
    public class Data360BatchHttpMock implements HttpCalloutMock {
        private Integer statusCode;

        public Data360BatchHttpMock(Integer statusCode) {
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
            if (endpoint != null && endpoint.contains('/services/a360/query/v2')) {
                res.setStatusCode(200);
                res.setStatus('OK');
                String tabularJson = '{"data": [[' +
                    '"EVT-BATCH-001",' +
                    '"PA-PKG-20261106-00000001",' +
                    '"001hm000003JkLM",' +
                    '"Archived Outflow Depository",' +
                    '100.00,' +
                    '"ARCHIVAL_OFFLOAD",' +
                    '"005hm000002oKYf",' +
                    '"2026-11-06T12:00:00Z",' +
                    'true' +
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

    @testSetup
    static void setupTestData() {
        // Create Grower/Processor Account
        Account grower = new Account(
            Name = 'Keystone CannaCultivation GP',
            Facility_Type__c = 'Grower_Processor',
            Premise_Registry_ID__c = 'GP-PA-2026-8801',
            Compliance_Status__c = 'Compliant'
        );
        insert grower;

        // Create Dispensary Account
        Account dispensary = new Account(
            Name = 'Commonwealth Wellness Dispensary',
            Facility_Type__c = 'Dispensary',
            Premise_Registry_ID__c = 'DISP-PA-2026-8802',
            Compliance_Status__c = 'Compliant'
        );
        insert dispensary;

        // Create Cannabis Strain
        Strain__c strain = new Strain__c(
            Name = 'Blueberry Muffin Test',
            Classification__c = 'Hybrid',
            Target_THC_Percentage__c = 19.50,
            Target_CBD_Percentage__c = 0.80,
            Is_Active__c = true
        );
        insert strain;

        // Create Plant Batch
        Plant_Batch__c batch = new Plant_Batch__c(
            Cultivator__c = grower.Id,
            Strain__c = strain.Id,
            Planted_Date__c = Date.today().addDays(-45),
            Growth_Stage__c = 'Vegetative',
            Initial_Plant_Count__c = 100,
            Current_Plant_Count__c = 100,
            Room_Location__c = 'Bay Alpha'
        );
        insert batch;

        // Create Product Packages with compliant 24-character RFID tags
        List<Product_Package__c> packages = new List<Product_Package__c>();

        // 1. Dispensed package
        packages.add(new Product_Package__c(
            Holding_Facility__c = dispensary.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 3.50,
            Unit_Price__c = 45.00,
            Tag_ID__c = 'PA-PKG-20261106-00000001',
            RFID_Tag__c = 'PA-PKG-20261106-00000001',
            Package_Status__c = 'In_Stock',
            Status__c = 'Dispensed',
            Lab_Safety_Status__c = 'Passed'
        ));

        // 2. Quarantined package
        packages.add(new Product_Package__c(
            Holding_Facility__c = dispensary.Id,
            Plant_Batch__c = batch.Id,
            Product_Type__c = 'Usable_Marijuana_Flower',
            Net_Weight_Grams__c = 7.00,
            Unit_Price__c = 85.00,
            Tag_ID__c = 'PA-PKG-20261106-00000002',
            RFID_Tag__c = 'PA-PKG-20261106-00000002',
            Package_Status__c = 'Quarantined',
            Status__c = 'Quarantined',
            Lab_Safety_Status__c = 'Failed'
        ));

        insert packages;
    }

    /**
     * @description Test scenario 1: Batch execution with default query verifying stateful metrics.
     */
    @isTest
    static void testBatchExecutionDefaultQuery() {
        Data360Service.isMockMode = true;
        Data360Service.resetMockStore();

        Test.startTest();
        Id batchId = Database.executeBatch(new Data360TelemetryArchivalBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, batchId, 'Batch Job ID should not be null.');

        Map<String, Object> summary = Data360TelemetryArchivalBatch.getLastExecutionSummary();
        System.assertNotEquals(null, summary, 'Summary metrics map should be populated.');
        Integer recordsProcessed = (Integer) summary.get('recordsProcessed');
        Integer recordsArchived = (Integer) summary.get('recordsArchived');
        Integer batchesProcessed = (Integer) summary.get('batchesProcessed');
        Integer errorCount = (Integer) summary.get('errorCount');

        System.assert(recordsProcessed >= 2, 'Should process at least 2 records. Actual: ' + recordsProcessed);
        System.assertEquals(recordsProcessed, recordsArchived, 'All records processed should be archived.');
        System.assert(batchesProcessed >= 1, 'Should process at least 1 batch.');
        System.assertEquals(0, errorCount, 'Error count should be 0.');
        System.assertEquals('COMPLETED', summary.get('status'), 'Status should be COMPLETED.');
        System.assertNotEquals(null, summary.get('executionStartTime'), 'executionStartTime should be set.');
        System.assertNotEquals(null, summary.get('executionEndTime'), 'executionEndTime should be set.');
    }

    /**
     * @description Test scenario: Batch execution with live Data Cloud Lakehouse callouts.
     */
    @isTest
    static void testBatchExecutionLiveCallouts() {
        Data360Service.isMockMode = false;
        Test.setMock(HttpCalloutMock.class, new Data360BatchHttpMock(200));

        Test.startTest();
        Id batchId = Database.executeBatch(new Data360TelemetryArchivalBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, batchId);
        Map<String, Object> summary = Data360TelemetryArchivalBatch.getLastExecutionSummary();
        System.assertNotEquals(null, summary);
        System.assertEquals('COMPLETED', summary.get('status'));
        System.assertEquals(0, summary.get('errorCount'));
    }

    /**
     * @description Test scenario 2: Schedulable execution via scheduleJob helper and CronTrigger verification.
     */
    @isTest
    static void testSchedulableExecution() {
        Test.startTest();
        String cronExpr = '0 0 2 * * ?';
        String jobId = Data360TelemetryArchivalBatch.scheduleJob('Test Telemetry Archival', cronExpr);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should be returned from scheduleJob.');

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExpr, ct.CronExpression, 'Cron expression should match scheduled value.');
    }

    /**
     * @description Tests direct execution of Schedulable execute method.
     */
    @isTest
    static void testSchedulableExecuteMethod() {
        Data360Service.isMockMode = true;

        Test.startTest();
        Data360TelemetryArchivalBatch schedulable = new Data360TelemetryArchivalBatch();
        schedulable.execute((SchedulableContext) null);
        Test.stopTest();

        System.assert(true, 'Schedulable execute should run without exception.');
    }

    /**
     * @description Test scenario 3a: Custom query constructor matching a specific status subset.
     */
    @isTest
    static void testCustomQueryExecution() {
        Data360Service.isMockMode = true;
        Data360Service.resetMockStore();

        String customQuery = 'SELECT Id, Name, Tag_ID__c, Status__c, Package_Status__c, Lab_Safety_Status__c, Holding_Facility__c, CreatedDate FROM Product_Package__c WHERE Status__c = \'Quarantined\'';
        Data360TelemetryArchivalBatch batchCustom = new Data360TelemetryArchivalBatch(customQuery);

        Test.startTest();
        Database.executeBatch(batchCustom, 200);
        Test.stopTest();

        Map<String, Object> summary = Data360TelemetryArchivalBatch.getLastExecutionSummary();
        System.assertEquals(1, (Integer) summary.get('recordsProcessed'), 'Custom query should match exactly 1 quarantined record.');
        System.assertEquals(1, (Integer) summary.get('recordsArchived'), 'Archived count should match processed count.');
    }

    /**
     * @description Test scenario 3b: Empty dataset handling.
     */
    @isTest
    static void testEmptyDatasetExecution() {
        Data360Service.isMockMode = true;
        Data360Service.resetMockStore();

        String emptyQuery = 'SELECT Id, Name, Tag_ID__c, Status__c, Package_Status__c, Lab_Safety_Status__c, Holding_Facility__c, CreatedDate FROM Product_Package__c WHERE Status__c = \'Draft\'';
        Data360TelemetryArchivalBatch batchEmpty = new Data360TelemetryArchivalBatch(emptyQuery);

        Test.startTest();
        Database.executeBatch(batchEmpty, 200);
        Test.stopTest();

        Map<String, Object> emptySummary = Data360TelemetryArchivalBatch.getLastExecutionSummary();
        System.assertEquals(0, (Integer) emptySummary.get('recordsProcessed'), 'Empty query should process 0 records.');
        System.assertEquals(0, (Integer) emptySummary.get('errorCount'), 'Empty query should have 0 errors.');
    }

    /**
     * @description Test scenario 4: Exception handling branch verifying errorCount tracking.
     */
    @isTest
    static void testExecutionErrorTracking() {
        Data360TelemetryArchivalBatch batch = new Data360TelemetryArchivalBatch();
        Product_Package__c dummyPkg = new Product_Package__c();

        Test.startTest();
        // Disabling mock mode without a mock HTTP response will cause CalloutException inside execute try-catch
        Data360Service.isMockMode = false;
        batch.execute(null, new List<sObject>{ dummyPkg });
        batch.finish(null);
        Test.stopTest();

        System.assert(batch.errorCount > 0, 'Error count should increment on exception.');
        Map<String, Object> summary = Data360TelemetryArchivalBatch.getLastExecutionSummary();
        System.assertEquals('COMPLETED_WITH_ERRORS', summary.get('status'), 'Status should be COMPLETED_WITH_ERRORS.');

        // Test setter helper
        Data360TelemetryArchivalBatch.setLastExecutionSummary(new Map<String, Object>{ 'test' => true });
        System.assertEquals(true, Data360TelemetryArchivalBatch.getLastExecutionSummary().get('test'));
    }
}
