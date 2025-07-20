import { LightningElement, api, wire } from 'lwc';
import getMessagingSessions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getMessagingSessions';
import getStatusOptions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getStatusOptions';
import getPromptTemplates from '@salesforce/apex/ziip_PromptTestUtil_Controller.getPromptTemplates';
import createAdvancedTestBatch from '@salesforce/apex/ziip_PromptTestUtil_Controller.createAdvancedTestBatch';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Template table columns
const templateColumns = [
    { label: 'Name', fieldName: 'Name', type: 'text', wrapText: true },
    { label: 'Template Type', fieldName: 'TemplateType', type: 'text' },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'Description', fieldName: 'Description', type: 'text', wrapText: true },
    { 
        type: 'action', 
        typeAttributes: { 
            rowActions: [
                { label: 'Select as Contextual', name: 'select_contextual' },
                { label: 'Select as Grounded', name: 'select_grounded' }
            ] 
        } 
    }
];

// Session table columns
const sessionColumns = [
    { label: 'Session Name', fieldName: 'name', type: 'text' },
    { label: 'Transcript Preview', fieldName: 'transcript', type: 'text', wrapText: true }
];

export default class Ziip_promptTestUtility extends LightningElement {
    
    @api messagingSessionsPageSize = 10;
    @api promptTemplatesPageSize = 20;
    
    // Step Management
    showTemplateSelection = true;
    showSessionSelection = false;
    
    // Template Selection Properties
    promptTemplates = []; // Current page of templates from server
    templateColumns = templateColumns;
    selectedContextualTemplate = null;
    selectedGroundedTemplate = null;
    isLoadingTemplates = false;
    
    // Template Filter Properties
    templateNameFilter = '';
    templateTypeFilter = '';
    templateStatusFilter = '';
    templateTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Grounded', value: 'Grounded' },
        { label: 'Standard', value: 'Standard' }
    ];
    templateStatusOptions = [
        { label: 'All Status', value: '' },
        { label: 'Active', value: 'Active' },
        { label: 'Inactive', value: 'Inactive' }
    ];
    
    // Template Pagination Properties
    templateCurrentPage = 1;
    templateTotalPages = 1;
    templateTotalCount = 0;
    templateHasNext = false;
    templateHasPrevious = false;
    
    // Session Selection Properties  
    sessions = [];
    filteredSessions = [];
    selectedSessionIds = [];
    sessionColumns = sessionColumns;
    searchKey = '';
    isLoadingSessions = false;
    
    // Pagination properties
    currentPage = 1;
    totalPages = 1;
    totalCount = 0;
    hasNext = false;
    hasPrevious = false;
    
    // Filter properties
    startDate = '';
    endDate = '';
    sessionName = '';
    selectedStatus = '';
    statusOptions = [];
    
    @wire(getStatusOptions)
    wiredStatusOptions({ error, data }) {
        if (data) {
            this.statusOptions = data;
        } else if (error) {
            console.error('Error loading status options:', error);
        }
    }

    connectedCallback() {
        // Load templates on component initialization
        this.loadTemplates();
    }

    // TEMPLATE LOADING AND PAGINATION METHODS

    loadTemplates() {
        this.isLoadingTemplates = true;
        
        getPromptTemplates({ 
            pageSize: this.promptTemplatesPageSize, 
            pageNumber: this.templateCurrentPage,
            templateName: this.templateNameFilter || null,
            templateType: this.templateTypeFilter || null,
            templateStatus: this.templateStatusFilter || null
        })
        .then(result => {
            this.promptTemplates = result.templates || [];
            
            // Update pagination info
            const pagination = result.pagination;
            this.templateTotalPages = pagination.totalPages;
            this.templateTotalCount = pagination.totalCount;
            this.templateHasNext = pagination.hasNext;
            this.templateHasPrevious = pagination.hasPrevious;
            
            this.isLoadingTemplates = false;
            console.log('Templates loaded:', this.promptTemplates.length, 'templates');
            console.log('Template pagination info:', pagination);
        })
        .catch(error => {
            console.error('Error loading templates:', error);
            this.isLoadingTemplates = false;
            this.showToast('Error', 'Failed to load prompt templates: ' + error.body?.message, 'error');
        });
    }

    // Template pagination handlers - now work with server-side data
    handleTemplatePreviousPage() {
        if (this.templateHasPrevious) {
            this.templateCurrentPage--;
            this.loadTemplates();
        }
    }

    handleTemplateNextPage() {
        if (this.templateHasNext) {
            this.templateCurrentPage++;
            this.loadTemplates();
        }
    }

    handleTemplateFirstPage() {
        this.templateCurrentPage = 1;
        this.loadTemplates();
    }

    handleTemplateLastPage() {
        this.templateCurrentPage = this.templateTotalPages;
        this.loadTemplates();
    }

    // TEMPLATE FILTER METHODS

    handleTemplateNameFilterChange(event) {
        this.templateNameFilter = event.target.value;
    }

    handleTemplateTypeFilterChange(event) {
        this.templateTypeFilter = event.target.value;
    }

    handleTemplateStatusFilterChange(event) {
        this.templateStatusFilter = event.target.value;
    }

    handleApplyTemplateFilters() {
        this.templateCurrentPage = 1; // Reset to first page when applying filters
        this.loadTemplates();
    }

    handleClearTemplateFilters() {
        this.templateNameFilter = '';
        this.templateTypeFilter = '';
        this.templateStatusFilter = '';
        this.templateCurrentPage = 1;
        this.loadTemplates();
    }

    // STEP 1: TEMPLATE SELECTION METHODS

    handleTemplateAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'select_contextual') {
            this.selectedContextualTemplate = { ...row };
            this.showToast('Success', 'Contextual Service Reply template selected: ' + row.Name, 'success');
        } else if (actionName === 'select_grounded') {
            this.selectedGroundedTemplate = { ...row };
            this.showToast('Success', 'Grounded Service Reply template selected: ' + row.Name, 'success');
        }
    }

    handleContinueToSessions() {
        if (this.continueDisabled) {
            return;
        }
        
        this.showTemplateSelection = false;
        this.showSessionSelection = true;
        this.loadSessions();
    }

    handleBackToTemplates() {
        this.showSessionSelection = false;
        this.showTemplateSelection = true;
        
        // Clear session selections when going back
        this.selectedSessionIds = [];
        this.sessions = [];
        this.filteredSessions = [];
    }

    // STEP 2: SESSION SELECTION METHODS

    loadSessions() {
        this.isLoadingSessions = true;
        
        getMessagingSessions({ 
            pageSize: this.messagingSessionsPageSize, 
            pageNumber: this.currentPage,
            startDate: this.startDate || null,
            endDate: this.endDate || null,
            sessionName: this.sessionName || null,
            status: this.selectedStatus || null
        })
        .then(result => {
            this.sessions = result.sessions.map(session => ({
                id: session.Id,
                name: session.Name,
                transcript: session.transcript ? session.transcript.substring(0, 200) + '...' : 'No transcript available'
            }));
            this.filteredSessions = [...this.sessions];
            
            // Update pagination info
            const pagination = result.pagination;
            this.totalPages = pagination.totalPages;
            this.totalCount = pagination.totalCount;
            this.hasNext = pagination.hasNext;
            this.hasPrevious = pagination.hasPrevious;
            
            this.isLoadingSessions = false;
            console.log('Sessions loaded:', this.filteredSessions);
            console.log('Pagination info:', pagination);
        })
        .catch(error => {
            console.error('Error loading sessions:', error);
            this.isLoadingSessions = false;
            this.showToast('Error', 'Failed to load messaging sessions: ' + error.body?.message, 'error');
        });
    }

    // Filter handlers
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleSessionNameChange(event) {
        this.sessionName = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleApplyFilters() {
        this.currentPage = 1; // Reset to first page when applying filters
        this.loadSessions();
    }

    handleClearFilters() {
        this.startDate = '';
        this.endDate = '';
        this.sessionName = '';
        this.selectedStatus = '';
        this.currentPage = 1;
        this.loadSessions();
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.filteredSessions = this.sessions.filter(session =>
            session.name.toLowerCase().includes(this.searchKey)
        );
    }

    handleRowSelection(event) {
        this.selectedSessionIds = event.detail.selectedRows.map(row => row.id);
    }

    handleCreateAdvancedTestBatch() {
        if (this.selectedSessionIds.length === 0) {
            this.showToast('Error', 'Please select at least one messaging session.', 'error');
            return;
        }

        const loadingToast = this.showToast('Processing', 'Creating advanced test batch...', 'info');

        createAdvancedTestBatch({ 
            sessionIds: this.selectedSessionIds,
            contextualTemplateId: this.selectedContextualTemplate.Id,
            groundedTemplateId: this.selectedGroundedTemplate.Id
        })
        .then(result => {
            console.log('Advanced test batch creation result:', result);
            
            let message = `Advanced test batch created successfully!<br/>`;
            message += `Batch ID: ${result.batchId}<br/>`;
            message += `Test Records Created: ${result.testRecordsCreated}<br/>`;
            message += `Sessions Processed: ${result.sessionsProcessed}<br/>`;
            message += `Customer Utterances Found: ${result.totalCustomerUtterances}`;
            
            if (result.sessionsSkipped > 0) {
                message += `<br/>Sessions Skipped (no customer utterances): ${result.sessionsSkipped}`;
            }
            
            this.showToast('Success', message, 'success');
            
            // Reset selections
            this.selectedSessionIds = [];
            
            // Go back to template selection for next batch
            this.handleBackToTemplates();
        })
        .catch(error => {
            console.error('Error creating advanced test batch:', error);
            this.showToast('Error', 'Failed to create test batch: ' + error.body?.message, 'error');
        });
    }

    // Pagination handlers
    handlePreviousPage() {
        if (this.hasPrevious) {
            this.currentPage--;
            this.loadSessions();
        }
    }

    handleNextPage() {
        if (this.hasNext) {
            this.currentPage++;
            this.loadSessions();
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.loadSessions();
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.loadSessions();
    }

    // COMPUTED PROPERTIES

    // Template computed properties for server-side pagination
    get templateCurrentPageInfo() {
        if (this.templateTotalCount === 0) {
            return '0 - 0 of 0';
        }
        const start = (this.templateCurrentPage - 1) * this.promptTemplatesPageSize + 1;
        const end = Math.min(this.templateCurrentPage * this.promptTemplatesPageSize, this.templateTotalCount);
        return `${start} - ${end} of ${this.templateTotalCount}`;
    }

    get templateShowPagination() {
        return this.templateTotalPages > 1;
    }

    // Session computed properties
    get continueDisabled() {
        return !this.selectedContextualTemplate || !this.selectedGroundedTemplate;
    }

    get currentPageInfo() {
        const start = (this.currentPage - 1) * this.messagingSessionsPageSize + 1;
        const end = Math.min(this.currentPage * this.messagingSessionsPageSize, this.totalCount);
        return `${start} - ${end} of ${this.totalCount}`;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get hasNoSelections() {
        return this.selectedSessionIds.length === 0;
    }

    // UTILITY METHODS

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'success' ? 'dismissable' : 'sticky'
        });
        this.dispatchEvent(evt);
    }
}
