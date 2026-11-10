/**
 * @description Controller for dynamic login-event navigation dispatch and Permittee Hub launcher.
 *              Evaluates User.LastLoginDate and assigned Persona Permission Sets to route
 *              permittee users to their designated operational workspace upon login,
 *              while allowing unrestricted browsing of the Home page during an active session.
 * @author Dipankar (Developer Phase 3 - Task T07)
 */
public with sharing class PortalNavigationController {

    public class WorkspaceCard {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String routeUrl;
        @AuraEnabled public String iconName;
        @AuraEnabled public String description;
        @AuraEnabled public String badgeLabel;
        @AuraEnabled public String badgeClass;

        public WorkspaceCard(String id, String title, String routeUrl, String iconName, String description, String badgeLabel, String badgeClass) {
            this.id = id;
            this.title = title;
            this.routeUrl = routeUrl;
            this.iconName = iconName;
            this.description = description;
            this.badgeLabel = badgeLabel;
            this.badgeClass = badgeClass;
        }
    }

    public class NavigationContext {
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Long lastLoginTime;
        @AuraEnabled public String targetWorkspaceUrl;
        @AuraEnabled public String targetWorkspaceTitle;
        @AuraEnabled public Boolean isMultiRoleOrAdmin;
        @AuraEnabled public List<WorkspaceCard> allowedWorkspaces;
        @AuraEnabled public List<String> assignedRoles;

        public NavigationContext() {
            this.allowedWorkspaces = new List<WorkspaceCard>();
            this.assignedRoles = new List<String>();
        }
    }

    /**
     * @description Fetches navigation context including last login epoch timestamp,
     *              target operational workspace URL, and authorized workspace cards.
     * @return NavigationContext strongly-typed DTO
     */
    @AuraEnabled(cacheable=true)
    public static NavigationContext getUserNavigationContext() {
        Id currentUserId = UserInfo.getUserId();
        User currentUser = [
            SELECT Id, Name, LastLoginDate, Profile.Name 
            FROM User 
            WHERE Id = :currentUserId 
            LIMIT 1
        ];

        NavigationContext ctx = new NavigationContext();
        ctx.userId = currentUser.Id;
        ctx.userName = currentUser.Name;
        ctx.lastLoginTime = currentUser.LastLoginDate != null ? currentUser.LastLoginDate.getTime() : 0;

        // Query active assigned permission sets
        List<PermissionSetAssignment> psaList = [
            SELECT PermissionSet.Name, PermissionSet.Label 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :currentUserId
        ];

        Set<String> permSetNames = new Set<String>();
        for (PermissionSetAssignment psa : psaList) {
            if (psa.PermissionSet != null && psa.PermissionSet.Name != null) {
                permSetNames.add(psa.PermissionSet.Name.toLowerCase());
            }
        }

        return evaluateContext(currentUser, permSetNames, ctx);
    }

    /**
     * @description Pure evaluation helper to support deterministic unit testing with mocked permissions.
     */
    @TestVisible
    private static NavigationContext evaluateContext(User u, Set<String> permSetNames, NavigationContext ctx) {
        Boolean isSysAdmin = u.Profile != null && u.Profile.Name != null && u.Profile.Name.equalsIgnoreCase('System Administrator');
        Boolean isAdminPerm = permSetNames.contains('mmap_admin_permset') || permSetNames.contains('mmap_inspector_permset');

        // Check persona flags across MMAP and PA naming aliases
        Boolean hasCultivation = permSetNames.contains('mmap_gp_cultivation') || permSetNames.contains('pa_cultivation_operator');
        Boolean hasProcessing = permSetNames.contains('mmap_gp_processing') || permSetNames.contains('pa_manufacturing_processor');
        Boolean hasCompliance = permSetNames.contains('mmap_gp_compliance');
        Boolean hasLab = permSetNames.contains('mmap_lab_analyst') || permSetNames.contains('pa_testing_lab_director');
        Boolean hasTransfers = permSetNames.contains('pa_transfers_transporter') || hasCompliance;
        Boolean hasDispensary = permSetNames.contains('mmap_dispensary_mgr') || permSetNames.contains('pa_dispensary_agent');

        WorkspaceCard cardCultivation = new WorkspaceCard(
            'cultivation',
            'Cultivation Workspace',
            '/cultivation',
            'standard:forests',
            'Plant batches, vegetative/flowering growth tracking, harvest yields, and wet/dry weights.',
            'Phase 1: G/P Cultivation',
            'slds-theme_success'
        );
        WorkspaceCard cardManufacturing = new WorkspaceCard(
            'manufacturing',
            'Manufacturing Workspace',
            '/manufacturing',
            'standard:work_capacity_usage',
            'Extraction batches, product formulation, packaged inventory, and 4x6 barcode labels.',
            'Phase 2: Manufacturing',
            'slds-theme_warning'
        );
        WorkspaceCard cardTestingLab = new WorkspaceCard(
            'testingLab',
            'Testing Lab Workspace',
            '/testing-lab',
            'standard:care_request_reviewer',
            'Sample intake, potency/pesticide assays, COA sign-off, and recursive quarantine triggers.',
            'Phase 3: Lab COA',
            'slds-theme_error'
        );
        WorkspaceCard cardTransfers = new WorkspaceCard(
            'transfers',
            'Transfers Console',
            '/transfers',
            'standard:assigned_resource',
            'Inter-licensee manifest creation, driver dispatch, vehicle verification, and chain of custody.',
            'Phase 4: Transport',
            'slds-theme_info'
        );
        WorkspaceCard cardDispensary = new WorkspaceCard(
            'dispensary',
            'Dispensary Counter Workspace',
            '/dispensary-counter',
            'standard:store',
            'Patient registry verification, 90-day MMU quota checks, and real-time point of sale dispensing.',
            'Phase 5: Retail Dispensary',
            'slds-theme_alt-inverse'
        );

        // System Administrator, Regulator Inspector, or generic account without operational roles
        if (isSysAdmin || isAdminPerm || (!hasCultivation && !hasProcessing && !hasLab && !hasTransfers && !hasDispensary)) {
            ctx.isMultiRoleOrAdmin = true;
            ctx.targetWorkspaceUrl = null;
            ctx.targetWorkspaceTitle = 'Executive Permittee Hub';
            ctx.allowedWorkspaces.add(cardCultivation);
            ctx.allowedWorkspaces.add(cardManufacturing);
            ctx.allowedWorkspaces.add(cardTestingLab);
            ctx.allowedWorkspaces.add(cardTransfers);
            ctx.allowedWorkspaces.add(cardDispensary);
            ctx.assignedRoles.add('System Administrator / Regulator');
            return ctx;
        }

        // Granular operational persona evaluation
        Integer operationalRolesCount = 0;
        String singleTargetUrl = null;
        String singleTargetTitle = null;

        if (hasCultivation) {
            ctx.allowedWorkspaces.add(cardCultivation);
            ctx.assignedRoles.add('Cultivation Lead');
            operationalRolesCount++;
            singleTargetUrl = '/cultivation';
            singleTargetTitle = 'Cultivation Workspace';
        }
        if (hasProcessing) {
            ctx.allowedWorkspaces.add(cardManufacturing);
            ctx.assignedRoles.add('Processing & Packaging');
            operationalRolesCount++;
            singleTargetUrl = '/manufacturing';
            singleTargetTitle = 'Manufacturing Workspace';
        }
        if (hasLab) {
            ctx.allowedWorkspaces.add(cardTestingLab);
            ctx.assignedRoles.add('Lab Analyst');
            operationalRolesCount++;
            singleTargetUrl = '/testing-lab';
            singleTargetTitle = 'Testing Lab Workspace';
        }
        if (hasTransfers) {
            ctx.allowedWorkspaces.add(cardTransfers);
            ctx.assignedRoles.add('Logistics & Transport');
            operationalRolesCount++;
            if (singleTargetUrl == null) {
                singleTargetUrl = '/transfers';
                singleTargetTitle = 'Transfers Console';
            }
        }
        if (hasDispensary) {
            ctx.allowedWorkspaces.add(cardDispensary);
            ctx.assignedRoles.add('Dispensary Agent');
            operationalRolesCount++;
            if (singleTargetUrl == null) {
                singleTargetUrl = '/dispensary-counter';
                singleTargetTitle = 'Dispensary Counter Workspace';
            }
        }

        if (operationalRolesCount == 1) {
            ctx.isMultiRoleOrAdmin = false;
            ctx.targetWorkspaceUrl = singleTargetUrl;
            ctx.targetWorkspaceTitle = singleTargetTitle;
        } else {
            ctx.isMultiRoleOrAdmin = true;
            ctx.targetWorkspaceUrl = null;
            ctx.targetWorkspaceTitle = 'Multi-Role Permittee Hub';
        }

        return ctx;
    }
}

