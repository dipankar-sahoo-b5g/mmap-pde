import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getUserNavigationContext from '@salesforce/apex/PortalNavigationController.getUserNavigationContext';

export default class PortalHomeDispatcher extends NavigationMixin(LightningElement) {
    @track navContext;
    isLoading = true;
    isRedirecting = false;
    showHub = false;
    redirectTimer = null;

    @wire(getUserNavigationContext)
    wiredContext({ error, data }) {
        if (data) {
            this.navContext = data;
            this.evaluateNavigation();
        } else if (error) {
            console.error('Error fetching navigation context', error);
            this.isLoading = false;
            this.showHub = true;
        }
    }

    evaluateNavigation() {
        if (!this.navContext) {
            this.isLoading = false;
            this.showHub = true;
            return;
        }

        const storedLoginTime = sessionStorage.getItem('mmap_last_dispatched_login');
        const currentLoginTime = String(this.navContext.lastLoginTime);

        // Check if user explicitly asked to stay on Home via URL query param (?stay=true or ?home=true)
        const urlParams = new URLSearchParams(window.location.search);
        const stayParam = urlParams.get('stay') === 'true' || urlParams.get('home') === 'true';

        // Check if this is a fresh login event for a single-role operational persona
        const isFreshLogin = (storedLoginTime !== currentLoginTime);
        const hasTargetWorkspace = Boolean(this.navContext.targetWorkspaceUrl);

        if (isFreshLogin && hasTargetWorkspace && !stayParam) {
            // Flag this specific login session as dispatched in browser session
            sessionStorage.setItem('mmap_last_dispatched_login', currentLoginTime);
            this.isLoading = false;
            this.isRedirecting = true;

            // Allow a graceful 1.5-second prompt before dispatching, giving user option to cancel
            this.redirectTimer = setTimeout(() => {
                this.navigateToTarget(this.navContext.targetWorkspaceUrl);
            }, 1200);
        } else {
            // Active session (already dispatched), multi-role/admin, or user explicitly staying
            this.isLoading = false;
            this.isRedirecting = false;
            this.showHub = true;
        }
    }

    navigateToTarget(routeUrl) {
        if (!routeUrl) return;
        const targetUrl = routeUrl.startsWith('/s/') 
            ? routeUrl 
            : ('/s' + (routeUrl.startsWith('/') ? routeUrl : '/' + routeUrl));

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: targetUrl
            }
        });
    }

    handleStayOnHome() {
        if (this.redirectTimer) {
            clearTimeout(this.redirectTimer);
            this.redirectTimer = null;
        }
        this.isRedirecting = false;
        this.showHub = true;
    }

    handleGoNow() {
        if (this.redirectTimer) {
            clearTimeout(this.redirectTimer);
            this.redirectTimer = null;
        }
        if (this.navContext && this.navContext.targetWorkspaceUrl) {
            this.navigateToTarget(this.navContext.targetWorkspaceUrl);
        }
    }

    handleLaunchPrimary() {
        if (this.navContext && this.navContext.targetWorkspaceUrl) {
            this.navigateToTarget(this.navContext.targetWorkspaceUrl);
        }
    }

    handleCardClick(event) {
        const routeUrl = event.currentTarget.dataset.route;
        this.navigateToTarget(routeUrl);
    }

    get userName() {
        return this.navContext ? this.navContext.userName : '';
    }

    get targetWorkspaceTitle() {
        return this.navContext ? this.navContext.targetWorkspaceTitle : '';
    }

    get hasPrimaryTarget() {
        return Boolean(this.navContext && this.navContext.targetWorkspaceUrl);
    }

    get primaryActionLabel() {
        return 'Open ' + (this.targetWorkspaceTitle || 'Workspace') + ' →';
    }

    disconnectedCallback() {
        if (this.redirectTimer) {
            clearTimeout(this.redirectTimer);
            this.redirectTimer = null;
        }
    }
}

