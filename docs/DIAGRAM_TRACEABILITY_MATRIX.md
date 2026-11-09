# 📊 Diagram Traceability & Component Status Matrix
## Commonwealth Medical Marijuana Regulatory Platform
**Document Type:** Architecture Diagram Coverage & Implementation Tracking Matrix  
**Source Reference:** RFP Proposed Logical Architecture (Pages 10 & 11 of RFP PDF)  
**Version:** 1.0 • **Status:** Final MVP Verified Tracking Document  

---

## 1. Purpose of this Document

This document captures **every single visual component, box, module, and integration** shown in the two architecture diagram pictures from the RFP. It provides:
1. **100% Visual Coverage:** An item-by-item audit of everything in the diagrams.
2. **Clear Functional Purpose:** A plain-language explanation of what each component does.
3. **Delivery Phase & Implementation Mapping:** Which feature, object, or phase builds it.
4. **Live Status Tracking:** Marks whether an item is `Pending`, `In Progress`, `Completed`, or `Phase 2 / External`.

---

## 2. Page 1: Proposed Logical Architecture Coverage

### 2.1 User Access & Identity Layer
| Diagram Box Label | Diagram Location | Functional Role & Purpose | MVP Scope & Object Mapping | Current Status |
| :--- | :--- | :--- | :--- | :---: |
| **DOH / MMAP Internal Users** | Top Left | State regulators, inspectors, and licensing officers requiring direct, unrestricted CRM access. | Standard Salesforce Core Users with custom Permission Sets. | `Completed` (Feature 8) |
| **Grower / Processor Users** | Top Banner | Commercial cultivators logging plant batches, harvest weights, and package creation. | Experience Cloud External Users linked to `Account` (Facility). | `Completed` (Feature 1 & 3) |
| **Dispensary Users** | Top Banner | Retail pharmacists and cashiers managing store vault inventory and retail checkouts. | Experience Cloud External Users linked to `Account` (Dispensary). | `Completed` (Feature 1 & 5) |
| **Approved Laboratory Users** | Top Banner | Certified chemists and lab techs entering sample screenings and signing official COAs. | Experience Cloud External Users linked to `Account` (Lab). | `Completed` (Feature 1 & 5) |
| **ACRC / Research Users** | Top Banner | University researchers managing clinical trials and research-tier cannabis inventory. | Experience Cloud External Users linked to `Account` (Research). | `Completed` (Feature 1) |
| **Patient / Caregiver Users** | Top Banner | Certified citizens applying for medical cards and tracking active purchase limits. | Experience Cloud External Users linked to `Contact` & `Patient_Registration__c`. | `Completed` (Feature 2) |
| **SSO / Identity Provider** | Middle Row | Centralized Commonwealth authentication broker (Okta / Microsoft Entra ID). | OpenID Connect / SAML Single Sign-On and Auth Provider setup. | `Phase 2` (Post-MVP Live SSO) |

---

### 2.2 External Portals (Experience Cloud)
| Diagram Box Label | Diagram Location | Functional Role & Purpose | MVP Scope & Object Mapping | Current Status |
| :--- | :--- | :--- | :--- | :---: |
| **Grower / Processor Portal** | Green Banner | Dedicated web interface for cultivators to manage plant rooms, RFID tags, and shipping manifests. | Experience Cloud Portal mapped to `Plant_Batch__c` & `Product_Package__c`. | `Completed` (Feature 3) |
| **Dispensary Portal** | Green Banner | Point-of-sale interface to scan patient barcode cards and verify 30-day limits. | Experience Cloud Portal mapped to `Dispense_Transaction__c`. | `Completed` (Feature 5) |
| **Approved Laboratory Portal** | Green Banner | Portal to ingest test samples, record chemical panel results, and issue pass/fail certificates. | Experience Cloud Portal mapped to `Lab_Test_Result__c`. | `Completed` (Feature 5) |
| **ACRC / Research Portal** | Green Banner | Interface for academic centers to report on clinical research supply and patient studies. | Experience Cloud Portal with specialized research record types. | `Completed` (Feature 8) |
| **Patient / Caregiver Portal** | Green Banner | Mobile-ready portal to submit medical card applications, upload proofs, and view quotas. | Experience Cloud Portal mapped to `Patient_Registration__c`. | `Completed` (Feature 2) |

---

### 2.3 Salesforce Government Cloud Plus Core Modules (The 12 Blue Boxes)
| Diagram Module Box | Functional Role & Regulatory Purpose | Technical Implementation in MVP | Current Status |
| :--- | :--- | :--- | :---: |
| **1. Licensing & Registration** | Commercial entity licensing, application intake wizard, statutory fee calculation, and premise mapping. | `Business_License__c`, `License_Application__c`, and `licenseApplicationWizard` LWC. | `Completed` (Features 1 & 9) |
| **2. Inventory & Production** | Plant batch stage tracking ($\text{Seedling} \to \text{Harvest}$) and usable weights. | `Plant_Batch__c` and `Product_Package__c` custom objects. | `Completed` (Feature 3) |
| **3. Patient & Caregiver Mgmt** | Patient registration card issuance, caregiver linkages, statutory quota tracking, and digital card experience. | `Patient_Registration__c` object linked to `Contact` and `patientRegistrationCard` interactive digital card. | `Completed` (Features 2 & 10) |
| **4. Practitioner Management** | Physician registration and statutory electronic medical recommendations for patients. | `Contact` (`Physician` role), `Physician_Certification__c` object, `VR_CERT_Valid_Duration` rule, and digital physician recommendation portal. | `Completed` (Features 2 & 10) |
| **5. Testing & Lab Management** | Chemical screening for pesticides, heavy metals, mold, and potency. | `Lab_Test_Result__c` object and automated COA pass/fail lock. | `Completed` (Feature 5) |
| **6. Dispensing & Sales** | Real-time retail sales recording and rolling 30-day quota deduction. | `Dispense_Transaction__c` object and purchase limit engine. | `Completed` (Feature 6) |
| **7. Transfers, Waste & Destruction** | Chain of custody manifests, destruction logging, vehicle manifests, and 3-step dual-signature handshakes. | `Product_Package__c`, `Transfer_Manifest__c`, `Manifest_Line_Item__c`, `TransferManifestTrigger`, and `dualSignaturePad` LWC. | `Completed` (Features 3, 4 & 11) |
| **8. Compliance, Invest. & Enforcement**| Field inspection scoring, violation citations, and statewide stop-sale quarantine engine. | `Inspection_Audit__c`, `Audit_Finding__c`, `QuarantineService`, `inspectionAuditManager` LWC, and standard `Case` object for violation records. | `Completed` (Features 8 & 12) |
| **9. Workflow & Approvals** | Multi-step approval paths for licenses, card renewals, and destruction. | Salesforce Lightning Flows and Native Approval Processes. | `Completed` (Feature 1 & 4) |
| **10. Case Management** | Public complaints, adverse event reports, and licensee dispute resolution. | Standard `Case` object with automated routing rules. | `Completed` (Feature 8) |
| **11. Notifications & Alerts** | Automated alerts for quarantine orders, expiring licenses, and overages. | Salesforce In-App Notification Center and Email Alerts. | `Completed` (Feature 6 & 8) |
| **12. Audit, Reporting & Compliance** | Full system change history and regulatory audit trail logging. | Salesforce Field Audit Trail and History Tracking. | `Completed` (Feature 1-8) |

---

### 2.4 Connected Analytics, Big Data & Integration Platforms
| Diagram Box Label | Diagram Location | Functional Role & Regulatory Purpose | Technical Implementation in MVP | Current Status |
| :--- | :--- | :--- | :--- | :---: |
| **Data 360** | Blue Oval (Right) | Governed big data lakehouse storing high-frequency RFID scans, sensor logs, and scheduled bulk telemetry archival with zero CRM database storage footprint. | Cross-Org Modern Named Credential (`Data360_API`), `data360Manager` LWC, `Data360TelemetryArchivalBatch`, and native Data Cloud Lakehouse Ingestion & Query v2 APIs (`MMAP_Telemetry_Event` DLO / `MMAP_Telemetry__dlm` DMO) verified live. | `Completed & Connected Live` (Features 7 & 13) |
| **Tableau** | Analytics Box | Executive visualization of statewide supply, sales heatmaps, and anti-diversion. | Tableau analytics dashboard connecting to Data 360 and Salesforce. | `Phase 2` (Post-MVP) |
| **MuleSoft** | Integration Tier | Enterprise API gateway routing data between Salesforce and external state systems. | Simulated via Salesforce Apex REST Services and Webhooks for MVP. | `Completed` (Feature 4-7) |

---

## 3. Page 2: External Systems & Infrastructure Coverage

### 3.1 Commonwealth Direct Systems (State Interoperability)
| External System Label | Diagram Location | Interoperability Purpose | MVP Architecture Alignment | Current Status |
| :--- | :--- | :--- | :--- | :---: |
| **PennDOT (DMV)** | Direct Integrations | Instant driver's license residency validation for patient applications. | Simulated via Apex verification service; points to state API. | `Completed` (Feature 2) |
| **Department of State** | Direct Integrations | Corporate registry check verifying licensee legal entity standing. | Managed through `Account` premise verification fields. | `Completed` (Feature 1) |
| **eLicensing System (ELS)** | Direct Integrations | Bi-directional synchronization with state professional license databases. | External ID mapping on `Business_License__c`. | `Completed` (Feature 1) |
| **Department of Agriculture** | Direct Integrations | Industrial hemp coordination and agricultural facility certifications. | Field attribute on `Plant_Batch__c` and `Account`. | `Completed` (Feature 3) |
| **Medical Marijuana Registry** | Direct Integrations | Master state patient database cross-referencing previous registrations. | Unified directly inside Salesforce Core (`Patient_Registration__c`).| `Completed` (Feature 2) |
| **Department of Health (DOH)** | Direct Integrations | Parent agency governing policy, medical regulations, and public alerts. | Native Salesforce Platform acting as the primary host. | `Completed` (Connected Org) |
| **MMAP Benefits Administrator**| Direct Integrations | Fee discount and subsidy eligibility checks for low-income patients. | Benefit discount picklist on `Patient_Registration__c`. | `Phase 2` (Post-MVP) |

---

### 3.2 Commonwealth ERP & Commercial B2B Systems
| External System Label | Diagram Location | Interoperability Purpose | MVP Architecture Alignment | Current Status |
| :--- | :--- | :--- | :--- | :---: |
| **Commonwealth ERP Gateway** | ERP Gateway | Transmission of state excise taxes, licensing fees, and accounting lines. | Standard financial fields on `Business_License__c` and Sales. | `Phase 2` (Post-MVP) |
| **Laboratory LIMS** | Entity Systems | Automatic ingestion of chemical panel test results directly from lab machines. | Inbound REST endpoint mapping to `Lab_Test_Result__c`. | `Completed` (Feature 5) |
| **3rd Party Logistics (3PL)** | Entity Systems | Vehicle manifests, driver license / VIN tracking, and multi-party chain-of-custody handshakes for licensed cannabis transporters. | `Transfer_Manifest__c`, `Manifest_Line_Item__c`, `dualSignaturePad` LWC, and automated package status transitions (`In_Transit` ➔ `In_Stock`). | `Completed` (Features 3, 4 & 11) |
| **Dispensary POS Systems** | Entity Systems | Integration with retail checkout cash registers to enforce rolling limits. | Real-time POS query endpoint mapping to `Dispense_Transaction__c`.| `Completed` (Feature 6) |
| **Labeling / Track & Trace** | Entity Systems | Third-party barcode/RFID printer software used at cultivation sites. | Standard 24-character `RFID_Tag__c` format for label compatibility.| `Completed` (Feature 4) |
| **ACRC / Research Systems** | Entity Systems | External university research data repositories studying medical outcomes. | API reporting endpoint on research packages. | `Phase 2` (Post-MVP) |

---

### 3.3 Infrastructure, Security & Compliance Requirements
| Infrastructure Requirement | Regulatory Standard | Salesforce Platform Realization | Current Status |
| :--- | :--- | :--- | :---: |
| **FedRAMP Authorized** | FedRAMP High Mandate | Hosted on Salesforce Government Cloud Plus infrastructure. | `Completed` (Org Architecture) |
| **Government Cloud Region** | US Sovereign Data | Dedicated US Gov Cloud Hyperforce instance (`USA1192`). | `Completed` (Verified in Org) |
| **Encryption in Transit & at Rest**| FIPS 140-2 Standards | TLS 1.3 for all web connections; Salesforce Shield Platform Encryption. | `Completed` (Org Standard) |
| **Monitoring & Audit** | State Compliance Mandate| Real-time Event Monitoring and Field Audit Trail. | `Completed` (Feature 8) |
| **Backup & Disaster Recovery** | RPO < 15m, RTO < 2h | Salesforce High Availability multi-zone automated backups. | `Completed` (Platform Native) |

---

## 4. Live Progress Tracking Summary

| Category | Total Diagram Items | Completed | In Progress | Pending MVP | Phase 2 / Post-MVP |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **User Roles & Portals** | 12 | 11 | 0 | 0 | 1 |
| **Core Blue Modules** | 12 | 12 | 0 | 0 | 0 |
| **Connected Platforms** | 3 | 2 | 0 | 0 | 1 |
| **Commonwealth Systems** | 7 | 6 | 0 | 0 | 1 |
| **Commercial B2B Systems** | 6 | 4 | 0 | 0 | 2 |
| **Infrastructure & Security**| 5 | 5 | 0 | 0 | 0 |
| **TOTALS** | **45** | **40** | **0** | **0** | **5** |

*Note: 100% of the 40 MVP Architecture diagram items are verified Completed. The remaining 5 items represent planned Phase 2 enterprise integrations (SSO Broker, Tableau Analytics, Commonwealth ERP Gateway, Benefits Administrator Webhook, and Academic Research Outcomes Registry).*
