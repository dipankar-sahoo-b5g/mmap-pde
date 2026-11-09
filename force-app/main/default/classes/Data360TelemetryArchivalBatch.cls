/**
 * @description Enterprise Integration Batch Job for Commonwealth Medical Marijuana Regulatory Platform.
 *              Executes scheduled and on-demand streaming archival of high-volume product package
 *              telemetry to the Data 360 Lakehouse pipeline.
 *              Implements stateful execution metrics tracking and callout handling.
 */
public with sharing class Data360TelemetryArchivalBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable, Database.Stateful {

    // Default SOQL query targeting terminal inventory states
    public static final String DEFAULT_QUERY = 'SELECT Id, Name, Tag_ID__c, Status__c, Package_Status__c, Lab_Safety_Status__c, Holding_Facility__c, CreatedDate FROM Product_Package__c WHERE Status__c IN (\'Dispensed\', \'Quarantined\')';

    // Query executed by this batch instance
    private String query;

    // Stateful metrics tracking
    public Integer recordsProcessed = 0;
    public Integer recordsArchived = 0;
    public Integer batchesProcessed = 0;
    public Integer errorCount = 0;
    public Datetime executionStartTime;
    public Datetime executionEndTime;

    // Static cache of the last execution summary
    private static Map<String, Object> lastExecutionSummary = new Map<String, Object>();

    /**
     * @description Default constructor initializing with DEFAULT_QUERY.
     */
    public Data360TelemetryArchivalBatch() {
        this(DEFAULT_QUERY);
    }

    /**
     * @description Parameterized constructor allowing custom archival SOQL queries.
     * @param customQuery SOQL query retrieving Product_Package__c records.
     */
    public Data360TelemetryArchivalBatch(String customQuery) {
        this.query = String.isNotBlank(customQuery) ? customQuery : DEFAULT_QUERY;
        this.executionStartTime = Datetime.now();
    }

    /**
     * @description Batch start method providing the QueryLocator.
     * @param bc Batchable context.
     * @return Database.QueryLocator for the target query.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (this.executionStartTime == null) {
            this.executionStartTime = Datetime.now();
        }
        return Database.getQueryLocator(this.query);
    }

    /**
     * @description Batch execute method processing each chunk of Product_Package__c records.
     *              Constructs TelemetryRecord and streams/archives to Data 360 Lakehouse.
     * @param bc Batchable context.
     * @param scope List of Product_Package__c records in the current batch.
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        this.batchesProcessed++;
        if (scope == null || scope.isEmpty()) {
            return;
        }

        for (sObject sobj : scope) {
            this.recordsProcessed++;
            Product_Package__c pkg = (Product_Package__c) sobj;

            try {
                // Determine RFID tracking identifier
                String rfid = String.isNotBlank(pkg.Tag_ID__c) ? pkg.Tag_ID__c : pkg.Name;
                String facilityId = pkg.Holding_Facility__c != null ? String.valueOf(pkg.Holding_Facility__c) : '';
                String actionType = 'Quarantined'.equalsIgnoreCase(pkg.Status__c) ? 'STATEWIDE_AUDIT_STREAM' : 'ARCHIVAL_OFFLOAD';
                Decimal metric = 'Quarantined'.equalsIgnoreCase(pkg.Status__c) ? 0.00 : 100.00;
                Datetime eventTime = pkg.CreatedDate != null ? pkg.CreatedDate : Datetime.now();
                String room = 'Quarantined'.equalsIgnoreCase(pkg.Status__c) ? 'Quarantine Holding Zone' : 'Archived Outflow Depository';

                // Construct TelemetryRecord
                Data360Service.TelemetryRecord telemetryRec = new Data360Service.TelemetryRecord();
                telemetryRec.rfidTag = rfid;
                telemetryRec.facilityId = facilityId;
                telemetryRec.roomLocation = room;
                telemetryRec.metricReading = metric;
                telemetryRec.actionType = actionType;
                telemetryRec.eventTimestamp = eventTime;
                telemetryRec.operatorUserId = UserInfo.getUserId();
                telemetryRec.isArchived = true;

                // Stream and archive event in Lakehouse
                Map<String, Object> createResult = Data360Service.createTelemetryEvent(telemetryRec);
                if (createResult != null && createResult.containsKey('eventId')) {
                    String eventId = (String) createResult.get('eventId');
                    Data360Service.archiveTelemetryEvent(eventId);
                }

                this.recordsArchived++;
            } catch (Exception ex) {
                this.errorCount++;
                System.debug(LoggingLevel.ERROR, 'Data360TelemetryArchivalBatch execution error on package ' + pkg.Id + ': ' + ex.getMessage());
            }
        }
    }

    /**
     * @description Batch finish method recording execution end time and compiling summary metrics.
     * @param bc Batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        this.executionEndTime = Datetime.now();

        Map<String, Object> summary = new Map<String, Object>{
            'recordsProcessed' => this.recordsProcessed,
            'recordsArchived' => this.recordsArchived,
            'batchesProcessed' => this.batchesProcessed,
            'errorCount' => this.errorCount,
            'executionStartTime' => this.executionStartTime,
            'executionEndTime' => this.executionEndTime,
            'status' => (this.errorCount == 0 ? 'COMPLETED' : 'COMPLETED_WITH_ERRORS')
        };

        lastExecutionSummary = summary;
        System.debug(LoggingLevel.INFO, 'Data360TelemetryArchivalBatch execution completed: ' + summary);
    }

    /**
     * @description Schedulable execute method invoking batch with safe chunk size 50
     *              (guarantees callout volume <= 100 per transaction for live REST integration).
     * @param sc Schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new Data360TelemetryArchivalBatch(), 50);
    }

    /**
     * @description Schedules recurring archival job via standard Salesforce CronTrigger.
     * @param jobName Optional custom job name.
     * @param cronExpression Valid 5-field/6-field cron expression.
     * @return Id of scheduled CronTrigger job.
     */
    public static String scheduleJob(String jobName, String cronExpression) {
        String effectiveJobName = String.isNotBlank(jobName) ? jobName : 'Data360TelemetryArchivalBatch_Scheduled';
        String effectiveCron = String.isNotBlank(cronExpression) ? cronExpression : '0 0 2 * * ?';
        return System.schedule(effectiveJobName, effectiveCron, new Data360TelemetryArchivalBatch());
    }

    /**
     * @description Returns summary metrics of the last batch execution run.
     * @return Map containing stateful execution metrics.
     */
    public static Map<String, Object> getLastExecutionSummary() {
        return lastExecutionSummary;
    }

    /**
     * @description Test-visible method to set execution summary for isolated testing.
     * @param summary Summary map to set.
     */
    @TestVisible
    private static void setLastExecutionSummary(Map<String, Object> summary) {
        lastExecutionSummary = summary;
    }
}
