# 📋 Field-Level Data Dictionary & Object Schema Specification
## Commonwealth Medical Marijuana Regulatory Platform (MVP)
**Document Type:** Technical Field Specification & Data Contract  
**Target Environment:** Salesforce Platform & Data 360  
**Version:** 1.0 • **Status:** Implementation Blueprint  

---

> [!IMPORTANT]
> **Implementation Mandate:** This document provides the field-level specification for all custom objects, relationships, validation rules, and the Data 360 API contract. All Salesforce developers and administrators must adhere strictly to these API names, data types, and picklist definitions during schema deployment.

---

## 1. Object Inventory & Schema Summary

| Object Label | Object API Name | Standard / Custom | Relationship Model | Primary Function |
| :--- | :--- | :--- | :--- | :--- |
| **Facility / Entity** | `Account` | Standard | Master entity | Represents commercial facilities (Grower, Lab, Dispensary). |
| **Person Profile** | `Contact` | Standard | Lookup to `Account` | Represents individuals (Physicians, Patients, Facility Staff). |
| **Business License** | `Business_License__c` | Custom | Master-Detail to `Account` | State operational license records and compliance statuses. |
| **Patient Registration** | `Patient_Registration__c` | Custom | Master-Detail to `Contact` | Medical marijuana card registry, physician linkage, and limits. |
| **Cannabis Strain** | `Strain__c` | Custom | Independent Catalog | Genetic cultivar library, cannabinoid ratios, and classifications. |
| **Plant Batch** | `Plant_Batch__c` | Custom | Lookup to `Account` & `Strain__c` | Cultivation lifecycle tracking from seedling to harvest. |
| **Product Package** | `Product_Package__c` | Custom | Lookup to `Plant_Batch__c` | Inventory units serialized with 24-character state RFID tags. |
| **Lab Test Result** | `Lab_Test_Result__c` | Custom | Lookup to `Product_Package__c` | Official Certificate of Analysis (COA) chemical screen results. |
| **Dispense Transaction**| `Dispense_Transaction__c` | Custom | Lookup to `Patient_Registration__c` | Dispensary point-of-sale checkout records. |

---

## 2. Field-Level Data Dictionary

### 2.1 Standard Object Extensions: `Account` & `Contact`

#### Account (Facility Profile Extensions)
| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Facility Type** | `Facility_Type__c` | Picklist | Yes | `Grower_Processor`, `Testing_Laboratory`, `Dispensary`, `Research_Center` | Regulatory categorization of the commercial premises. |
| **Premise Registry ID** | `Premise_Registry_ID__c` | Text(30) | Yes (Unique) | Formatted string (e.g., `FAC-PA-2026-091`) | State-assigned physical location registry code. |
| **Vault Storage Capacity**| `Vault_Capacity_Grams__c`| Number(12, 2)| No | Decimal $> 0$ | Maximum approved secure storage capacity in grams. |
| **Compliance Status** | `Compliance_Status__c` | Picklist | Yes | `Compliant`, `Under_Investigation`, `Suspended`, `Revoked` | Real-time regulatory standing determined by state audits. |

#### Contact (Person Profile Extensions)
| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Stakeholder Role** | `Stakeholder_Role__c` | Picklist | Yes | `Patient`, `Caregiver`, `Physician`, `Facility_Agent` | Identifies individual standing within the state program. |
| **State ID Number** | `State_ID_Number__c` | Text(20) | No (Encrypted) | Formatted string | PennDOT driver's license or state identification number. |
| **Medical License Number**| `Medical_License_No__c` | Text(30) | No | Formatted string | State medical board license number (for certifying doctors). |

---

### 2.2 Custom Object: `Business_License__c`
* **Parent Object:** `Account` (Master-Detail)
* **Plural Label:** Business Licenses
* **Sharing Model:** Controlled by Parent

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **License Name** | `Name` | Auto-Number | Auto | `LIC-{YYYY}-{00000}` | Standard system identifier for the license record. |
| **Facility** | `Facility__c` | Master-Detail(`Account`) | Yes | References `Account` | The licensed commercial operating entity. |
| **License Number** | `License_Number__c` | Text(30) | Yes (Unique) | Formatted string (e.g., `GP-2026-00412`) | Official state-issued license credential string. |
| **License Tier** | `License_Tier__c` | Picklist | Yes | `Standard_Commercial`, `Microbusiness`, `Research_Academic` | Operating scale and fee authorization tier. |
| **Issue Date** | `Issue_Date__c` | Date | Yes | Valid date | Date license was formally granted by the DOH. |
| **Expiration Date** | `Expiration_Date__c` | Date | Yes | Date $> \text{Issue\_Date\_\_c}$ | Annual renewal deadline. |
| **Status** | `Status__c` | Picklist | Yes | `Active`, `Pending_Renewal`, `Suspended`, `Expired`, `Revoked` | Current legal authorization status. |

---

### 2.3 Custom Object: `Patient_Registration__c`
* **Parent Object:** `Contact` (Master-Detail)
* **Plural Label:** Patient Registrations
* **Sharing Model:** Controlled by Parent

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Registration Number** | `Name` | Auto-Number | Auto | `MMAP-{YYYY}-{000000}` | Public registration ID printed on medical cannabis cards. |
| **Patient Contact** | `Patient__c` | Master-Detail(`Contact`) | Yes | References `Contact` | The individual registered patient record. |
| **Certifying Physician** | `Certifying_Physician__c` | Lookup(`Contact`) | Yes | References `Contact` | The doctor who issued the medical certification. |
| **Barcode String** | `Barcode_String__c` | Text(50) | Yes (Unique) | Formatted string (e.g., `PA-MED-84920194`) | Scannable barcode identifier read by dispensary registers. |
| **30-Day Quota (Grams)** | `Thirty_Day_Limit_Grams__c`| Number(6, 2) | Yes | Default: `90.00` | Maximum grams of cannabis permitted in a rolling 30-day period. |
| **Certification Date** | `Certification_Date__c` | Date | Yes | Valid date | Date the physician approved the recommendation. |
| **Expiration Date** | `Expiration_Date__c` | Date | Yes | Date $> \text{Certification\_Date\_\_c}$ | End date of valid patient registration (maximum 12 months). |
| **Active Status** | `Is_Active__c` | Checkbox | No | Formula: `Expiration_Date__c >= TODAY()` | Automated flag indicating if the card is currently valid. |

---

### 2.4 Custom Object: `Strain__c`
* **Parent Object:** None (Independent Catalog)
* **Plural Label:** Cannabis Strains
* **Sharing Model:** Read / Write for internal, Read-Only for external

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Strain Name** | `Name` | Text(80) | Yes | e.g., `Blue Dream`, `ACDC` | Registered cultivar commercial and genetic name. |
| **Classification** | `Classification__c` | Picklist | Yes | `Indica`, `Sativa`, `Hybrid`, `High_CBD` | Botanical classification and effect profile. |
| **Target THC Percentage**| `Target_THC_Percentage__c`| Percent(5, 2) | No | `0.00%` to `100.00%` | Expected typical THC concentration. |
| **Target CBD Percentage**| `Target_CBD_Percentage__c`| Percent(5, 2) | No | `0.00%` to `100.00%` | Expected typical CBD concentration. |
| **Active In Catalog** | `Is_Active__c` | Checkbox | No | Default: `true` | Allows discontinuing outdated genetics. |

---

### 2.5 Custom Object: `Plant_Batch__c`
* **Parent Object:** `Account` (Lookup), `Strain__c` (Lookup)
* **Plural Label:** Plant Batches
* **Sharing Model:** Private (Restricted to Cultivator Facility)

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Batch Identifier** | `Name` | Auto-Number | Auto | `PB-{YYYYMM}-{0000}` | System-generated tracking batch reference. |
| **Cultivator Facility** | `Cultivator__c` | Lookup(`Account`) | Yes | References `Account` | Licensed grower organization managing the batch. |
| **Strain** | `Strain__c` | Lookup(`Strain__c`) | Yes | References `Strain__c` | Genetics cultivar associated with this batch. |
| **Growth Stage** | `Growth_Stage__c` | Picklist | Yes | `Seedling`, `Vegetative`, `Flowering`, `Harvested`, `Destroyed` | Current biological phase in the cultivation facility. |
| **Initial Plant Count** | `Initial_Plant_Count__c` | Number(6, 0) | Yes | Integer $> 0$ | Total number of plants tracked together in this batch. |
| **Surviving Plant Count**| `Current_Plant_Count__c` | Number(6, 0) | Yes | Integer $\le \text{Initial}$ | Remaining live plants after mortality or culling. |
| **Room Location** | `Room_Location__c` | Text(50) | Yes | e.g., `Grow Room B-2`, `Vault 1` | Physical room or zone within the licensed facility. |
| **Planted Date** | `Planted_Date__c` | Date | Yes | Valid date | Date cultivation commenced. |
| **Harvest Date** | `Harvest_Date__c` | Date | No | Valid date | Date plants were cut down for drying and processing. |
| **Wet Weight (Grams)** | `Wet_Weight_Grams__c` | Number(10, 2)| No | Decimal $> 0$ | Gross weight measured immediately post-harvest. |
| **Dry Weight (Grams)** | `Dry_Weight_Grams__c` | Number(10, 2)| No | Decimal $\le \text{Wet\_Weight}$ | Usable weight recorded after the drying and curing process. |

---

### 2.6 Custom Object: `Product_Package__c`
* **Parent Object:** `Plant_Batch__c` (Lookup)
* **Label / Plural Label:** Packaged Inventory
* **Sharing Model:** Private (Restricted to Holding Facility)

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Package Number** | `Name` | Auto-Number | Auto | `PKG-{YYYYMM}-{00000}` | Administrative package record reference. |
| **State RFID Tag** | `RFID_Tag__c` | Text(24) | Yes (Unique) | 24-character string | Serialized physical barcode / RFID tag affixed to unit. |
| **Plant Batch** | `Plant_Batch__c` | Lookup(`Plant_Batch__c`)| Yes | References `Plant_Batch__c` | Source harvest batch genealogy. |
| **Holding Facility** | `Holding_Facility__c` | Lookup(`Account`) | Yes | References `Account` | Current physical location holding custody of package. |
| **Product Type** | `Product_Type__c` | Picklist | Yes | `Usable_Marijuana_Flower`, `Cannabis_Oil`, `Concentrate`, `Topical`, `Edible` | Market product category. |
| **Net Weight (Grams)** | `Net_Weight_Grams__c` | Number(8, 2) | Yes | Decimal $> 0$ | Sellable net weight contained within the package. |
| **Unit Price** | `Unit_Price__c` | Currency(8, 2)| No | Decimal $\ge 0$ | Wholesale or retail listed price. |
| **Package Status** | `Package_Status__c` | Picklist | Yes | `In_Testing`, `Ready_for_Sale`, `Transferred`, `Sold`, `Quarantined`, `Destroyed` | Operational inventory state. |
| **Lab Safety Status** | `Lab_Safety_Status__c` | Picklist | Yes | `Untested`, `Passed`, `Failed` | Rollup indicator of laboratory safety clearance. |

---

### 2.7 Custom Object: `Lab_Test_Result__c`
* **Parent Object:** `Product_Package__c` (Lookup)
* **Plural Label:** Lab Test Results
* **Sharing Model:** Controlled by Facility Access

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **COA Number** | `Name` | Auto-Number | Auto | `COA-{YYYYMM}-{0000}` | Official Certificate of Analysis reference identifier. |
| **Tested Package** | `Product_Package__c` | Lookup(`Product_Package__c`)| Yes | References `Product_Package__c` | Inventory package from which the sample was drawn. |
| **Testing Laboratory** | `Testing_Laboratory__c`| Lookup(`Account`) | Yes | References `Account` | Certified laboratory organization performing test. |
| **Test Date** | `Test_Date__c` | Date | Yes | Valid date | Date laboratory completed testing panel. |
| **THC Potency (%)** | `THC_Potency_Pct__c` | Percent(5, 2) | Yes | `0.00%` to `100.00%` | Verified tetrahydrocannabinol concentration. |
| **CBD Potency (%)** | `CBD_Potency_Pct__c` | Percent(5, 2) | Yes | `0.00%` to `100.00%` | Verified cannabidiol concentration. |
| **Pesticides Screen** | `Pesticides_Pass__c` | Checkbox | No | Default: `false` | `true` indicates sample passed chemical pesticide limits. |
| **Heavy Metals Screen**| `Heavy_Metals_Pass__c` | Checkbox | No | Default: `false` | `true` indicates sample passed lead/arsenic/cadmium limits. |
| **Mycotoxins Screen** | `Mycotoxins_Pass__c` | Checkbox | No | Default: `false` | `true` indicates sample passed mold/yeast limits. |
| **Residual Solvents** | `Residual_Solvents_Pass__c`| Checkbox | No | Default: `false` | `true` indicates extraction solvents are below threshold. |
| **Overall Status** | `Overall_Status__c` | Picklist | Yes | `Pending`, `Passed`, `Failed` | Comprehensive determination of product safety. |

---

### 2.8 Custom Object: `Dispense_Transaction__c`
* **Parent Object:** `Patient_Registration__c` (Lookup), `Product_Package__c` (Lookup)
* **Plural Label:** Dispense Transactions
* **Sharing Model:** Private (Restricted to Dispensing Facility & Regulators)

| Field Label | Field API Name | Data Type | Required | Values / Options | Business Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Transaction Number**| `Name` | Auto-Number | Auto | `TXN-{YYYYMM}-{000000}` | Unique retail sale receipt identifier. |
| **Patient Registration**| `Patient_Registration__c`| Lookup(`Patient_Registration__c`)| Yes | References `Patient_Registration__c` | Certified patient purchasing the medicine. |
| **Dispensary Facility**| `Dispensary__c` | Lookup(`Account`) | Yes | References `Account` | Retail location completing the transaction. |
| **Sold Package** | `Product_Package__c` | Lookup(`Product_Package__c`)| Yes | References `Product_Package__c` | Serialized inventory unit dispensed. |
| **Grams Dispensed** | `Grams_Dispensed__c` | Number(6, 2) | Yes | Decimal $> 0$ | Total weight deducted from patient 30-day allowance. |
| **Transaction Date** | `Transaction_Timestamp__c`| DateTime | Yes | Current DateTime | Exact timestamp of sale. |
| **Total Amount Paid** | `Total_Amount__c` | Currency(8, 2)| Yes | Decimal $\ge 0$ | Total price charged at checkout. |

---

### 2.9 Custom Object: `Inspection_Audit__c`
* **Label:** `Inspection Audit`
* **Plural Label:** `Inspection Audits`
* **API Name:** `Inspection_Audit__c`
* **Standard Name Field:** `Name` (Auto-Number: `AUD-{YYYYMM}-{0000}`)
* **Sharing Model:** `ReadWrite`
* **Description:** On-site regulatory audits and field compliance scorecards for licensed facilities.

| Business Field Name | Field API Name | Field Data Type | Required | Values / Constraints | Business Description |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Regulated Facility** | `Facility__c` | Lookup(`Account`) | Yes | References `Account` | Regulated commercial facility undergoing inspection audit. |
| **Regulatory Inspector**| `Inspector__c` | Lookup(`Contact`) | No | References `Contact` | Authorized regulatory inspector who conducted the audit. |
| **Inspection Date** | `Inspection_Date__c` | Date | Yes | Valid Calendar Date | Date on which on-site field inspection took place. |
| **Inspection Type** | `Inspection_Type__c` | Picklist | Yes | `Annual Routine`, `Unannounced Compliance`, `Follow-Up Re-Inspection`, `Adverse Event Investigation` | Categorical classification and triggering context for the audit. |
| **Overall Inspection Score**| `Audit_Score__c` | Number(3, 0) | No | $0 \le \text{Score} \le 100$ | Overall numerical compliance score evaluated against statutory criteria. |
| **Compliance Grade** | `Compliance_Grade__c` | Picklist | No | `Pass`, `Conditional Pass`, `Failed - Immediate Revocation` | Regulatory grade auto-assigned based on numerical score thresholds. |
| **Status** | `Status__c` | Picklist | No | `Scheduled`, `In Progress`, `Completed`, `Quarantine Enacted` | Operational lifecycle status of the inspection audit. |
| **Stop-Sale Order Enacted**| `Stop_Sale_Enacted__c`| Checkbox | No | Default: `false` | Indicates whether an emergency statewide stop-sale order has been enacted. |
| **Stop-Sale Timestamp**| `Stop_Sale_Timestamp__c`| DateTime | No | System-stamped DateTime | Date and time at which emergency stop-sale quarantine order was enacted. |
| **Executive Audit Findings**| `Summary_Findings__c` | LongTextArea(32768)| No | Rich Text Narrative | Executive narrative summarizing on-site findings and inspector conclusions. |

---

### 2.10 Custom Object: `Audit_Finding__c`
* **Label:** `Audit Finding`
* **Plural Label:** `Audit Findings`
* **API Name:** `Audit_Finding__c`
* **Standard Name Field:** `Name` (Auto-Number: `FND-{YYYYMM}-{0000}`)
* **Sharing Model:** `ControlledByParent`
* **Description:** Discrete violations or deficiency citations cited during an on-site inspection audit.

| Business Field Name | Field API Name | Field Data Type | Required | Values / Constraints | Business Description |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Inspection Audit** | `Inspection_Audit__c` | MasterDetail(`Inspection_Audit__c`)| Yes | Parent Master Record | Parent inspection audit during which this finding was cited. |
| **Finding Category** | `Finding_Category__c` | Picklist | No | `Security & Surveillance`, `Vault Scale Calibration`, `Pesticide / Chemical Storage`, `Sanitation & Hygiene`, `Diversion Discrepancy` | Compliance domain cited for this infraction. |
| **Severity** | `Severity__c` | Picklist | No | `Minor`, `Major`, `Critical Violation` | Risk and statutory violation severity level. |
| **Statutory Fine Amount**| `Statutory_Fine_Amount__c`| Currency(18, 2)| No | Decimal $\ge 0$ | Civil monetary penalty assessed for this citation. |
| **Mandated Corrective Action**| `Corrective_Action_Plan__c`| LongTextArea(32768)| No | Text Narrative | Mandated remediation steps required by Commonwealth regulators. |
| **Finding Resolved** | `Resolved__c` | Checkbox | No | Default: `false` | Indicates whether the corrective action was verified and resolved. |

---

## 3. Validation Rules Specification

| Rule Name | Target Object | Error Condition Formula | Error Message |
| :--- | :--- | :--- | :--- |
| **VR_AUDIT_Valid_Score** | `Inspection_Audit__c` | `Audit_Score__c < 0 || Audit_Score__c > 100` | "Inspection Audit Score must be between 0 and 100." |
| **VR_PKG_COA_Must_Pass** | `Product_Package__c` | `AND(ISPICKVAL(Package_Status__c, 'Ready_for_Sale'), NOT(ISPICKVAL(Lab_Safety_Status__c, 'Passed')))` | "Packages cannot be marked Ready for Sale until the laboratory safety status is Passed." |
| **VR_PKG_RFID_Length** | `Product_Package__c` | `LEN(RFID_Tag__c) != 24` | "State RFID tracking tags must be exactly 24 characters in length." |
| **VR_BATCH_Harvest_Weight** | `Plant_Batch__c` | `AND(ISPICKVAL(Growth_Stage__c, 'Harvested'), ISBLANK(Dry_Weight_Grams__c))` | "You must enter dry harvest weight before setting batch stage to Harvested." |
| **VR_PAT_Active_Date** | `Patient_Registration__c`| `Expiration_Date__c <= Certification_Date__c` | "Card expiration date must be later than the doctor certification date." |
| **VR_LIC_Valid_Dates** | `Business_License__c` | `Expiration_Date__c <= Issue_Date__c` | "License expiration date must be after the issue date." |

---

## 4. Data 360 REST API Contract (Big Data Lakehouse)

The Data 360 platform provides REST endpoints for high-frequency telemetry, RFID movements, and multi-year transaction line items. The Salesforce `data360Manager` LWC and `Data360Controller.cls` interact using the schemas defined below:

### 4.1 Native Lakehouse Data Model Object Schema (`MMAP_Telemetry__dlm`)

The Data 360 Lakehouse persists high-frequency sensor readings, RFID tracking movements, and multi-year transaction line items directly in Data Cloud's big-data storage engine (`MMAP_Telemetry__dlm`), supporting 1 TB+ of multi-year history with zero consumption of transactional Salesforce CRM database limits:

| Field Name | Data Cloud Type | Key / Attribute Type | Description |
| :--- | :--- | :--- | :--- |
| `Event_ID__c` | Text (255) | Primary Key | Unique high-entropy event transaction identifier across org boundaries. |
| `RFID_Tag__c` | Text (24) | Indexed Dimension | 24-character Commonwealth RFID tag linked to parent package. |
| `Facility_ID__c` | Text (18) | Dimension | Originating Salesforce Account/Facility ID. |
| `Event_Timestamp__c` | DateTime | Timestamp | Date and time physical event occurred in UTC. |
| `Room_Location__c` | Text (100) | Dimension | Room or facility zone where scan occurred. |
| `Metric_Reading__c` | Number (10, 2) | Measure | Scale weight in grams or sensor telemetry reading. |
| `Action_Type__c` | Text (50) | Categorical Dimension | `STAGE_MOVE`, `RFID_SCAN`, `SAMPLE_TEST`, `ARCHIVAL_OFFLOAD`, `STATEWIDE_AUDIT_STREAM`. |
| `Operator_User_ID__c` | Text (18) | Dimension | Salesforce User ID who initiated action. |
| `Is_Archived__c` | Boolean | Status Dimension | Regulatory soft-delete flag (`true` indicates archived). |

---

### 4.2 Endpoint Specifications

#### 1. Ingest Event (Create)
* **Endpoint:** `POST /api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event`
* **Purpose:** Stream a new sensor log or RFID movement directly into Data Cloud Lakehouse (`MMAP_Telemetry_Event` DLO / `MMAP_Telemetry__dlm` DMO).
* **Request Payload:**
```json
{
  "data": [
    {
      "eventId": "e9b2c34a-9e12-4f62-8172-10f84a329c11",
      "rfidTag": "1A4000312678900000049210",
      "facilityId": "001hm000003JkLM",
      "roomLocation": "Curing Room 3",
      "metricReading": 450.25,
      "actionType": "STAGE_MOVE",
      "operatorUserId": "005hm000002oKYf",
      "eventTimestamp": "2026-11-05T18:45:00Z",
      "isArchived": false
    }
  ]
}
```
* **Success Response (`202 Accepted` / `201 Created`):**
```json
{
  "status": "SUCCESS",
  "eventId": "e9b2c34a-9e12-4f62-8172-10f84a329c11",
  "timestamp": "2026-11-05T18:45:00Z"
}
```

#### 2. Query Events (Read)
* **Endpoint:** `POST /services/a360/query/v2`
* **Purpose:** Execute high-performance ANSI SQL Query v2 against `MMAP_Telemetry__dlm` for display in the `data360Manager` LWC.
* **Request Payload:**
```json
{
  "sql": "SELECT Event_ID__c, RFID_Tag__c, Facility_ID__c, Room_Location__c, Metric_Reading__c, Action_Type__c, Operator_User_ID__c, Event_Timestamp__c, Is_Archived__c FROM MMAP_Telemetry__dlm WHERE RFID_Tag__c = '1A4000312678900000049210' ORDER BY Event_Timestamp__c DESC LIMIT 10 OFFSET 0"
}
```
* **Success Response (`200 OK`):**
```json
{
  "data": [
    [
      "e9b2c34a-9e12-4f62-8172-10f84a329c11",
      "1A4000312678900000049210",
      "001hm000003JkLM",
      "Curing Room 3",
      450.25,
      "STAGE_MOVE",
      "005hm000002oKYf",
      "2026-11-05T18:45:00Z",
      false
    ]
  ],
  "rowCount": 1,
  "done": true
}
```

#### 3. Update Event (Update)
* **Endpoint:** `POST /api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event`
* **Purpose:** Modify an existing record in Data Cloud Lakehouse via streaming mutation/upsert.
* **Request Payload:**
```json
{
  "data": [
    {
      "eventId": "e9b2c34a-9e12-4f62-8172-10f84a329c11",
      "rfidTag": "1A4000312678900000049210",
      "roomLocation": "Vault 1",
      "metricReading": 448.00,
      "eventTimestamp": "2026-11-05T18:48:10Z"
    }
  ]
}
```
* **Success Response (`202 Accepted` / `200 OK`):**
```json
{
  "status": "UPDATED",
  "eventId": "e9b2c34a-9e12-4f62-8172-10f84a329c11",
  "modifiedAt": "2026-11-05T18:48:10Z"
}
```

#### 4. Soft-Delete Event (Delete / Archive)
* **Endpoint:** `POST /api/v1/ingest/sources/MMAP_Telemetry/MMAP_Telemetry_Event`
* **Purpose:** Enforce compliance by streaming tombstone event with `isArchived: true` and `actionType: "ARCHIVAL_OFFLOAD"` into Data Cloud Lakehouse.
* **Success Response (`202 Accepted` / `200 OK`):**
```json
{
  "status": "ARCHIVED",
  "eventId": "e9b2c34a-9e12-4f62-8172-10f84a329c11",
  "isArchived": true
}
```

---

## 5. Next Steps: Development Sequence

With the Field-Level Data Dictionary finalized:
1. **Scaffold Metadata Files:** Create Custom Object definition XMLs in `force-app/main/default/objects/`.
2. **Deploy Schema to Org:** Run `sf project deploy start` to create the objects in `pmarijuna-partner-dev-org`.
3. **Build Apex Automation:** Implement RFID generation and the Lab COA gatekeeper.
4. **Develop Data 360 LWC:** Construct the `data360Manager` component with mock/live service integration.

