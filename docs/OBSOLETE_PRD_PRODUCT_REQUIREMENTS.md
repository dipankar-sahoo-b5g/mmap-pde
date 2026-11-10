# 🌿 Product Requirements Document (PRD)
## Commonwealth Medical Marijuana Advisory Program (MMAP)
### Seed-to-Sale Regulatory Platform & Patient Registry
**Document Type:** Product Requirements Document (PRD)  
**Version:** 1.0 • **Status:** Approved for Technical Design  

---

## 1. Product Overview & Vision

### 1.1 The Business Problem
The Commonwealth Department of Health (DOH) oversees the legal medical cannabis program to ensure public safety, guarantee medicine quality, and protect registered patients. Currently, regulatory operations face several critical operational gaps:
* **Manual Compliance Verification:** Facility licensing, background investigations, and renewals involve disconnected paperwork and manual reviews.
* **Diversion Risk:** Without continuous chain-of-custody tracking, product can leak into illicit markets or untested cannabis can enter legal dispensaries.
* **Patient Limit Loopholes:** Patients can visit multiple dispensaries on the same day ("dispensary hopping") because purchase limits are not synchronized state-wide in real time.
* **Unstructured Lab Results:** Test results from independent laboratories arrive in varied formats without an automated gatekeeper to prevent contaminated batches from hitting retail shelves.

### 1.2 Product Vision
A unified, state-wide cloud platform that serves as the single source of truth for all medical marijuana activity. The platform regulates the entire lifecycle—from the moment a plant is cultivated, through lab safety testing and secure transport, to patient certification and retail dispensing.

---

## 2. User Personas & Operational Roles

| Stakeholder Persona | Core Role in Program | Primary Operational Needs |
| :--- | :--- | :--- |
| **🏛️ State Health Regulators** | Policy enforcement, compliance investigations, facility licensing | Automated audit alerts, digital inspection workflows, and stop-sale enforcement tools. |
| **🌱 Commercial Cultivators** | Plant propagation, growth monitoring, harvesting, and packaging | Fast batch creation, automatic 24-character RFID assignment, and paperless shipping manifests. |
| **🔬 Testing Laboratories** | Sample chemical analysis, potency verification, contaminant screening | Direct digital entry of test findings and automated issuance of verified Certificates of Analysis (COA). |
| **🏪 Dispensary Pharmacists** | Patient check-in, quota verification, retail sales, and inventory | Real-time 30-day limit validation at checkout to prevent statewide over-dispensing. |
| **🩺 Certifying Physicians** | Patient medical evaluations, diagnosis of qualifying conditions | Simple, secure electronic form to submit and renew patient recommendations. |
| **🧑‍⚕️ Patients & Caregivers** | Legal registration, card renewals, medicine purchase at dispensaries | User-friendly online application, digital card with barcode, and clear visibility into purchase quotas. |

---

## 3. Epics & Detailed User Stories

### Epic 1: Facility & Business Licensing
* **US-1.1 Application Intake:** As a prospective grower, lab operator, or dispensary owner, I want to submit my facility license application online with facility floor plans and ownership details so that the state can review my business.
  * **Acceptance Criteria:**
    * Applicant can choose license type (Grower/Processor, Lab, Dispensary).
    * Required document uploads (premise diagrams, security plans) are validated before submission.
    * Application is assigned a tracking number and placed in the DOH review queue.
* **US-1.2 Facility Inspection & Approval:** As a DOH licensing officer, I want to review submitted documents, record on-site audit findings, and issue an official state license number so that the facility can legally operate.
  * **Acceptance Criteria:**
    * Inspector can approve, reject, or request revisions.
    * Approved licenses generate an active license record with an annual expiration date.

### Epic 2: Patient Registration & Doctor Certification
* **US-2.1 Physician Recommendation:** As a state-certified doctor, I want to search for a patient and submit a qualifying condition certification online so that my patient can legally apply for medical cannabis.
  * **Acceptance Criteria:**
    * Doctor enters patient name, date of birth, and diagnosis category.
    * System timestamps the electronic signature and sets an expiration date (up to 12 months).
* **US-2.2 Patient Card Issuance:** As a qualified patient, I want to verify my state residency and receive a barcoded medical cannabis registration card so that I can purchase medicine at licensed dispensaries.
  * **Acceptance Criteria:**
    * Residency is verified against state records.
    * Once doctor certification is matched, the system issues an active registration card with a unique barcode ID.

### Epic 3: Seed-to-Sale Cultivation & RFID Tracking
* **US-3.1 Plant Batch Creation:** As a cultivation manager, I want to log new plant batches by strain and assign unique state RFID tags so that every plant group is traceable.
  * **Acceptance Criteria:**
    * Each batch must specify Strain, Room Location, and Initial Plant Count.
    * System generates and assigns a unique 24-character Commonwealth tracking tag.
* **US-3.2 Stage Progression & Harvest:** As a grower, I want to update plant stages (Vegetative $\to$ Flowering $\to$ Harvest) and record dry harvest weights so that the state ledger reflects accurate inventory.
  * **Acceptance Criteria:**
    * User records total harvest weight and waste trim weight.
    * Batch status updates automatically upon harvest completion.

### Epic 4: Laboratory Safety Testing & Quality Assurance
* **US-4.1 Sample Selection:** As a processor, I want to generate a representative test package from a finished batch and transfer custody to an approved laboratory.
  * **Acceptance Criteria:**
    * Sample package inherits batch genealogy and RFID origin.
    * Parent batch is automatically locked in `In Testing` status.
* **US-4.2 Certificate of Analysis (COA) Submission:** As a lab technician, I want to enter potency and contaminant test results so that the state can determine if the product is safe for consumption.
  * **Acceptance Criteria:**
    * Lab enters values for THC/CBD percentages, heavy metals, pesticides, and mold.
    * If all panels pass, status is marked `Passed`. If any panel fails, status is marked `Failed`.
* **US-4.3 Automated Safety Gate:** As a compliance officer, I need the system to prohibit any untested or failed product from being transferred to a dispensary.
  * **Acceptance Criteria:**
    * Packages cannot be added to a shipping manifest or marked `Ready for Sale` unless linked to a `Passed` COA.
    * Any `Failed` batch automatically moves to `Quarantined` status.

### Epic 5: Dispensary Point of Sale & Patient Limits
* **US-5.1 Patient Check-In & Quota Verification:** As a dispensary cashier, I want to scan a patient's card barcode to verify their active status and check their remaining 30-day purchase limit.
  * **Acceptance Criteria:**
    * Scanner retrieves patient record instantly.
    * System calculates total grams purchased across all state dispensaries over the last rolling 30 days.
    * System displays remaining grams allowed for purchase.
* **US-5.2 Checkout & Inventory Deduction:** As a dispensary cashier, I want to record completed sales so that the patient's limit is updated and the dispensary's vault inventory is reduced.
  * **Acceptance Criteria:**
    * Sale is blocked if transaction quantity exceeds the patient's remaining 30-day allowance.
    * Completed transactions immediately update the statewide limit and deduct product packages from inventory.

### Epic 6: High-Volume Telemetry & Archival (Data 360 Lakehouse)
* **US-6.1 Direct Data Cloud Lakehouse Storage:** As a system administrator, I want high-frequency RFID scans, environmental sensor telemetry, and terminal package logs to be stored directly in Data Cloud Lakehouse (`MMAP_Telemetry__dlm`), so that multi-terabyte (1 TB+) regulatory history is maintained with zero consumption of Salesforce Core CRM relational storage.
  * **Acceptance Criteria:**
    * Bulk operational events stream securely across org boundaries into Data Cloud Lakehouse tables.
    * Core CRM database storage is protected from data ballooning, maintaining zero custom object telemetry footprint.
* **US-6.2 Cross-Org Cloud CRUD Management:** As an auditor or compliance officer operating within `marijuana Salesforce`, I want to execute full CRUD operations (Create, Read, Update, Soft-Delete/Archive) directly against Data Cloud so that changes immediately reflect in the Data Cloud Lakehouse without leaving the Salesforce interface.
  * **Acceptance Criteria:**
    * Creating, updating, or archiving a telemetry event in `marijuana Salesforce` immediately reflects live in `marijuana Data360`.
    * Users query and inspect historical Lakehouse records in real-time via the `Data 360 Lakehouse Telemetry` component without copying data into CRM storage.

### Epic 7: On-Site Regulatory Auditing & Statewide Stop-Sale Quarantine
* **US-7.1 Field Inspection & Citation Management:** As a state health inspector, I want to execute structured on-site regulatory audits, score facility compliance, and record statutory violation citations with required corrective action plans so that licensed premises operate safely and transparently.
  * **Acceptance Criteria:**
    * Inspector can record facility inspection date, type (Annual Routine, Unannounced Compliance, Follow-Up Re-Inspection, Adverse Event Investigation), and numeric score (0 to 100).
    * Validation rule `VR_AUDIT_Valid_Score` strictly blocks audit scores below 0 or above 100.
    * System automatically calculates compliance grade (`Pass` for scores $\ge 80$, `Conditional Pass` for $65 \le \text{Score} < 80$, `Failed - Immediate Revocation` for $\text{Score} < 65$).
    * Inspector can log individual child findings categorized by biosecurity, scale calibration, pesticide storage, diversion, or security, specifying severity and statutory fines.
* **US-7.2 Statewide Emergency Stop-Sale Quarantine:** As a state regulatory authority, I want to immediately enact an emergency stop-sale quarantine order against high-risk or failing facilities so that non-compliant, adulterated, or diverted cannabis is immediately frozen from entering retail distribution.
  * **Acceptance Criteria:**
    * Stop-sale orders can be enacted directly from failing audits or emergency enforcement reviews.
    * Transaction executes an atomic lockdown: transitions audit status to `Quarantine Enacted`, sets facility compliance status to `Suspended`, and atomically marks all holding facility packages to `Quarantined`.
    * Packages under quarantine cannot be sold or transferred.
* **US-7.3 Remediation & Quarantine Rescission:** As a compliance director, I want to lift a stop-sale quarantine order once corrective action plans have been validated and state re-inspection confirms compliance.
  * **Acceptance Criteria:**
    * Rescission action updates audit status to `Completed`, unchecks the stop-sale flag, and returns facility compliance status to `Compliant`.
    * Audit trail preserves original quarantine timestamp and order history.

---

## 4. End-to-End Business Workflows

### Workflow 1: Patient Certification & Dispensation
1. **Physician Certification:** Certified doctor submits qualifying condition diagnosis through the Practitioner Portal.
2. **State Validation:** DOH and PennDOT instantly verify patient identity and state residency.
3. **Card Issuance:** DOH generates a unique patient registration ID and issues a scannable barcoded medical card.
4. **Dispensary Check-In:** Dispensary scans patient barcode; system verifies active status and calculates rolling 30-day limit.
5. **Retail Checkout:** Pharmacist records grams sold; system automatically deducts quota and decrements facility inventory.

### Workflow 2: Cultivation, Safety Testing & Transfer
1. **Plant Batch Creation:** Grower logs strain and plant count; system assigns a serialized 24-character RFID tag.
2. **Harvest & Packaging:** Cultivator records dry/wet harvest weight; inventory is packed into sellable packages.
3. **Mandatory Lab Testing:** A representative sample is transferred to an approved laboratory for chemical screening.
4. **COA Pass/Fail Gate:** Batch is locked until the lab posts a verified `Passed` Certificate of Analysis.
5. **Secure Shipping Manifest:** Transporter and dispensary sign electronic chain-of-custody manifest upon delivery.
6. **Dispensary Vault Reception:** Verified inventory is received into retail point-of-sale systems.

### Workflow 3: Regulatory Field Inspection & Emergency Stop-Sale Quarantine
1. **On-Site Inspection Execution:** State inspector visits licensed facility, conducts physical premise review, and logs observations in the field inspection scorecard.
2. **Score & Citation Evaluation:** Inspector enters numeric score and itemized violation findings with statutory fines. System computes grade.
3. **Critical Hazard Escalation:** If critical safety hazards (unregistered pesticides, diversion discrepancies) or failing scores are detected, regulator triggers emergency stop-sale order.
4. **Statewide Supply Chain Freeze:** Engine instantly suspends facility operating privileges and flags all on-site packages as `Quarantined`, locking transfers and sales statewide.
5. **Remediation & Rescission:** Facility completes corrective decontamination and inventory reconciliation; regulator inspects and lifts quarantine.

---

## 5. Non-Functional & Operational Requirements

| Category | Requirement | Target Metric |
| :--- | :--- | :--- |
| **Availability** | System uptime during dispensary operating hours | 99.9% availability |
| **Response Time** | Patient barcode scan and 30-day limit calculation | $< 1.5$ seconds |
| **Data Retention** | Regulatory audit trail and seed-to-sale history | 7+ years in Data 360 lakehouse |
| **Security** | Role-based permissions by facility and user persona | Least-privilege profile enforcement |
| **Compliance** | Health record privacy and chain of custody tracking | Full audit trail on all record modifications |

---

## 6. Success Metrics & Business KPIs

* **100% Contaminant Interception:** Zero failed or untested batches reach dispensary shelves.
* **Zero Purchase Limit Overages:** Automated calculation eliminates 100% of multi-dispensary limit evasion.
* **Paperless Audits:** 100% digital manifests and lab certificates with instant chain-of-custody verification.
* **Optimized Storage Costs:** Over 90% of bulk historical events offloaded to Data 360, keeping operational Salesforce storage lean and performant.
