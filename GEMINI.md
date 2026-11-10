# Project Rules & Guidelines

## 1. Browser Usage Policy
- **Do not unnecessarily open the browser**: Do not launch or open a web browser (e.g., via `sf org open` or browser automation) unless explicitly requested by the user or when there are no other options.
- **CLI & Headless First**: For Salesforce org access or verification, retrieve information directly via CLI commands, SOQL queries, or generate login URLs using `--url-only` instead of automatically opening browser windows.

---

## 2. Markdown Formatting & Desktop Visual Standards
- **Zero ASCII / Fixed-Width Text Boxes**: NEVER output ASCII text art or pseudo-tables (`+----+`, `| ... |`, `[ Box ] ---> [ Box ]`). In desktop browsers and Markdown viewers, these render inside `<pre><code>` blocks, break responsive wrapping, trigger ugly horizontal scrollbars, and cut off text on the right.
- **Native Markdown Tables Only**: Always use standard GitHub-Flavored Markdown tables for tabular data. Ensure every cell has complete content (never leave blank/empty cells for merged concepts). Native tables dynamically wrap text and fit any window width without horizontal scrollbars.
- **Structured Workflows Over Text Art**: For business processes and user journeys, use clean, bold numbered lists or step-by-step bulleted workflows instead of typewriter-style text arrows.
- **Visual Alert Callouts**: Use standard GitHub-style alerts (`> [!IMPORTANT]`, `> [!NOTE]`) for executive summaries, mandates, and critical callouts.

---

## 3. Mermaid Flowchart Design Guidelines for Desktop
- **Explicit Large Font Size**: Always configure large, readable font sizes in every Mermaid diagram header:
  `%%{init: {'theme': 'base', 'themeVariables': { 'fontSize': '16px', 'fontFamily': 'system-ui, -apple-system, sans-serif' }}}%%`
- **Compact Width / No Horizontal Squishing**: Keep diagram width compact (maximum 2 to 3 nodes wide). NEVER place 4+ nodes side-by-side in a single horizontal row (`graph TD`). When diagrams are too wide, the browser SVG renderer scales down the entire graphic to fit the window, making text microscopic and truncated.
- **Zero Nested Subgraphs**: Strictly avoid nesting subgraphs inside subgraphs (`subgraph` inside `subgraph`). Dagre layout calculation in browser preview extensions truncates nested subgraph titles (`overflow: hidden`), misaligns borders, and creates asymmetric whitespace. Use flat, single-level subgraphs or styled individual nodes with clear connectors.
- **Card-Style Nodes with Line Breaks**: Use `<br/>` for line wraps inside node labels so boxes resemble clean executive cards rather than stretched rectangles. Apply rounded borders (`rx: 8px`), bold titles, and high-contrast pastel styling.

---

## 4. Document Types & Separation of Concerns
- **Product Requirements Document (PRD)**:
  - Must focus strictly on **Product & Business Requirements**: problem statements, target user personas, pain points, epics, detailed user stories with acceptance criteria, end-to-end business workflows, and success metrics/KPIs.
  - Do NOT reduce a PRD to just a re-hashed technical specification.
- **Technical Architecture Design (TAD)**:
  - Must focus strictly on **Technical Implementation**: system architecture, object schema dictionaries, Entity-Relationship Diagrams (ERDs), Apex automation logic, integration patterns, API contracts, and LWC component technical designs.

---

## 5. Technology Stack & Content Boundaries
- **Core Approved Stack**: Strictly limit architecture to **Salesforce Platform** (Core, Gov Cloud, Experience Cloud, Apex, LWC), **Microsoft Ecosystem** (Azure AD / Entra ID for Identity, Microsoft 365 / SharePoint), **Central Identity Database (SSO)**, and **Data 360 (Data Cloud)**.
- **Prohibited Stack Mentions**: NEVER mention, reference, or disclaim unrelated stacks (e.g., Firebase, SSH servers, custom auth servers, or extraneous firewall technologies)—not even to state that they are not being used. The target audience is Salesforce-native.
- **Tone & Audience**: Write clearly, professionally, and naturally so that Technical Architects, Salesforce Admins, and Business Analysts can all understand the documents seamlessly. Do NOT add meta-commentary like "This is great for business analysts, technical architects...". State facts and specifications directly.

---

## 6. Step-by-Step Confirmation Protocol
- **Explain First, Then Wait for Approval**: Before initiating any feature build, creating code/metadata, or launching subagents, always explain exactly what is going to be built, the specific objects/fields involved, and where to find it in the documentation.
- **Never Build Autonomously**: Do not start execution or trigger agents on your own. Explicitly wait for the user to confirm and give permission before proceeding with each feature or action.

---

## 7. Dual-Org Architecture & Workspace Repository Locations
- **Two Authoritative Repositories on Desktop Only**:
  - **Core Salesforce Platform Org (`pmarijuna-partner-dev-org`)**:  
    Located at `c:\Users\DipankarSahoo\Desktop\marijuana`.  
    Contains core CRM data models (Plant Batches, Packages, Manifests, Audits, Dispense Transactions), Apex business logic, LWC components, Experience Cloud portal configurations, and Named Credentials.
  - **Data Cloud Lakehouse Org (`data-cloud-dev-org-1`)**:  
    Located at `c:\Users\DipankarSahoo\Desktop\marijuana Data Cloud`.  
    Contains External Client Application (ECA) metadata (`Data360_Lakehouse_ECA`), Ingestion REST API schemas (`MMAP_Telemetry`), Lakehouse Data Source Objects, and Ingest Permission Sets.
- **Zero Duplicate Folders**:
  - Do NOT create, duplicate, or extract parallel project folders in `Downloads`, `tmp`, or elsewhere.
  - The historical `Downloads\marijuana Salesforce` and `Downloads\marijuana Data Cloud` directories have been permanently consolidated and removed.
- **Mandatory Path Resolution for Gemini / AI Agents**:
  - Whenever working on Data Cloud ingestion APIs, Lakehouse schemas, ECA tokens, or Lakehouse metadata, **Gemini must always navigate directly to and work within `c:\Users\DipankarSahoo\Desktop\marijuana Data Cloud`**.
  - Whenever working on Core CRM objects, LWC, Apex services, or manifest packages, **Gemini must always work within `c:\Users\DipankarSahoo\Desktop\marijuana`**.
  - Never scatter files across Downloads or create redundant local copies. Both active projects reside exclusively side-by-side on the Desktop.

---

## 8. Feature Manifest Protocol
- **Dedicated Package Manifest Naming Convention**: For EVERY feature, task, or phase build, a dedicated package manifest `manifest/package-<task-name>-<description>-dipankar.xml` MUST be created before/during deployment and committed to the repository (e.g., `manifest/package-t26-mock-registry-dipankar.xml`, `manifest/package-t07-portal-container-dipankar.xml`, `manifest/package-t07-workspaces-dipankar.xml`). The name MUST include the task name and end with `-dipankar.xml` so the owner and task scope are immediately identifiable.
- **Comprehensive Component Coverage**: Every package manifest must explicitly list all new and modified components for that feature (Apex classes, tests, custom fields, permissions, layouts, flexipages, sites, networks, experience bundles).
- **Master Manifest Synchronization**: The master `manifest/package.xml` must also be updated to include all newly introduced metadata components so the entire repository remains 100% deployable as a cohesive whole.
- **Obsolete Manifest Segregation**: Any historical or legacy manifests created outside the authoritative Excel Demo Plan (`docs/PA Seed-to-Sale Demo Plan_7.xlsx`) must be segregated into `manifest/obsolete/` and never used for active deployments.

---

## 9. Business Analyst & Product Owner Manual Test Protocol
- **Mandatory Manual Test Walkthrough for Every Feature/Task**: For EVERY feature, task, or phase build in implementation plans and completion reports, a dedicated **"Business Analyst & Product Owner Manual Test Walkthrough"** MUST be documented.
- **Actionable Step-by-Step UI Instructions**: Every walkthrough must explicitly define:
  1. **Exact UI Navigation Path**: Setup menus, App Launcher apps, Object Tabs, Experience Builder page selectors, or portal URLs.
  2. **Records, List Views & Canvas to Inspect**: The exact record names, filter names, layouts, or components to open.
  3. **Data & Badge Verifications**: Specific field values, picklists, badges, or UI behaviors to inspect.
  4. **Acceptance Criteria**: Crystal-clear expected outcomes (e.g., zero record visibility under Private OWD, automatic workspace dispatch, etc.).
- **Zero Technical Jargon Barrier**: Write test instructions so that a Business Analyst, Product Owner, or non-technical regulatory stakeholder can log into the org and independently verify the business functionality in under 2 minutes without writing SOQL or running CLI commands.

