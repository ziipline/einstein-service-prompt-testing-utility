import { LightningElement, api, wire } from 'lwc';
import getMessagingSessions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getMessagingSessions';
import getCases from '@salesforce/apex/ziip_PromptTestUtil_Controller.getCases';
import getVoiceCalls from '@salesforce/apex/ziip_PromptTestUtil_Controller.getVoiceCalls';
import getStatusOptions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getStatusOptions';
import getPromptTemplates from '@salesforce/apex/ziip_PromptTestUtil_Controller.getPromptTemplates';
import createAdvancedTestBatch from '@salesforce/apex/ziip_PromptTestUtil_Controller.createAdvancedTestBatch';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Base template table columns (actions will be added dynamically)
const baseTemplateColumns = [
    { label: 'Name', fieldName: 'Name', type: 'text', wrapText: true },
    { label: 'Template Type', fieldName: 'TemplateType', type: 'text' },
    { label: 'Status', fieldName: 'Status', type: 'text' }
];

// Session table columns
const sessionColumns = [
    { label: 'Session Name', fieldName: 'nameUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
    { label: 'Transcript Preview', fieldName: 'transcript', type: 'text', wrapText: true }
];

// Case table columns
const caseColumns = [
    { label: 'Case Number', fieldName: 'CaseNumber', type: 'text' },
    { label: 'Subject', fieldName: 'Subject', type: 'text', wrapText: true },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'Priority', fieldName: 'Priority', type: 'text' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' }
];

// Voice Call table columns
const voiceCallColumns = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Call Type', fieldName: 'CallType', type: 'text' },
    { label: 'Start Time', fieldName: 'CallStartDateTime', type: 'date' },
    { label: 'Duration (sec)', fieldName: 'CallDurationInSeconds', type: 'number' },
    { label: 'From', fieldName: 'FromPhoneNumber', type: 'text' },
    { label: 'To', fieldName: 'ToPhoneNumber', type: 'text' }
];

export default class Ziip_promptTestUtility extends LightningElement {
    
    @api messagingSessionsPageSize = 10;
    @api casesPageSize = 10;
    @api voiceCallsPageSize = 10;
    @api promptTemplatesPageSize = 20;
    @api defaultRetrieverId = '';
    @api defaultFaithfulnessTemplateId = '';
    @api defaultRelevancyTemplateId = '';
    @api defaultContextQualityTemplateId = '';
    
    // Step Management
    showTestTypeSelection = true;
    showTemplateSelection = false;
    showRecordSelection = false;
    
    // Test Type Selection
    selectedTestType = '';
    testTypeOptions = [
        { label: 'Service Replies', value: 'Service Replies' },
        { label: 'Case Summary', value: 'Case Summary' },
        { label: 'Work Summary', value: 'Work Summary' }
    ];
    
    // Template Selection Properties
    promptTemplates = [];
    selectedPrimaryTemplate = null;
    selectedSecondaryTemplate = null;
    selectedRetrieverId = '';
    isLoadingTemplates = false;
    
    // Quality Assessment Properties
    enableQualityAssessment = false;
    faithfulnessTemplateId = '';
    relevancyTemplateId = '';
    contextQualityTemplateId = '';
    
    // Knowledge Grounding Properties
    primaryUsesKnowledgeGrounding = false;
    secondaryUsesKnowledgeGrounding = false;
    
    // Template Filter Properties
    templateNameFilter = '';
    templateTypeFilter = '';
    templateStatusFilter = '';
    templateTypeOptions = [];
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
    
    // Data Selection Properties
    dataRecords = [];
    filteredDataRecords = [];
    selectedRecordIds = [];
    dataColumns = sessionColumns; // Will be updated based on test type
    searchKey = '';
    isLoadingData = false;
    
    // Data Source Type for Work Summary
    workSummaryDataType = 'MessagingSession'; // 'MessagingSession' or 'VoiceCall'
    workSummaryDataOptions = [
        { label: 'Messaging Sessions', value: 'MessagingSession' },
        { label: 'Voice Calls', value: 'VoiceCall' }
    ];
    
    // Pagination properties
    currentPage = 1;
    totalPages = 1;
    totalCount = 0;
    hasNext = false;
    hasPrevious = false;
    
    // Filter properties
    startDate = '';
    endDate = '';
    recordName = '';
    selectedStatus = '';
    statusOptions = [];
    
    // Additional filter properties for different record types
    sessionName = '';
    caseSubject = '';
    selectedCaseStatus = '';
    selectedCallType = '';
    selectedVoiceCallStatus = '';
    
    // Status option arrays for different record types
    caseStatusOptions = [];
    callTypeOptions = [];
    voiceCallStatusOptions = [];
    
    @wire(getStatusOptions)
    wiredStatusOptions({ error, data }) {
        if (data) {
            this.statusOptions = data;
        } else if (error) {
            console.error('Error loading status options:', error);
        }
    }

    connectedCallback() {
        this.selectedRetrieverId = this.defaultRetrieverId || '';
        this.faithfulnessTemplateId = this.defaultFaithfulnessTemplateId || '';
        this.relevancyTemplateId = this.defaultRelevancyTemplateId || '';
        this.contextQualityTemplateId = this.defaultContextQualityTemplateId || '';
    }

    // STEP 1: TEST TYPE SELECTION

    handleSelectServiceReplies(event) {
        this.selectedTestType = 'Service Replies';
        this.resetSelections();
    }

    handleSelectCaseSummary(event) {
        this.selectedTestType = 'Case Summary';
        this.resetSelections();
    }

    handleSelectWorkSummary(event) {
        this.selectedTestType = 'Work Summary';
        this.resetSelections();
    }

    resetSelections() {
        // Reset selections when test type changes
        this.selectedPrimaryTemplate = null;
        this.selectedSecondaryTemplate = null;
        this.selectedRecordIds = [];
        this.dataRecords = [];
        this.filteredDataRecords = [];
        
        // Update data columns based on test type
        this.updateDataColumns();
    }

    handleTestTypeChange(event) {
        this.selectedTestType = event.target.value;
        this.resetSelections();
    }
    
    updateDataColumns() {
        switch (this.selectedTestType) {
            case 'Service Replies':
            case 'Work Summary':
                if (this.workSummaryDataType === 'VoiceCall') {
                    this.dataColumns = voiceCallColumns;
                } else {
                    this.dataColumns = sessionColumns;
                }
                break;
            case 'Case Summary':
                this.dataColumns = caseColumns;
                break;
            default:
                this.dataColumns = sessionColumns;
        }
    }

    handleContinueToTemplates() {
        if (!this.selectedTestType) {
            this.showToast('Error', 'Please select a test type first.', 'error');
            return;
        }
        
        this.showTestTypeSelection = false;
        this.showTemplateSelection = true;
        this.loadTemplates();
    }

    handleBackToTestTypes() {
        this.showTemplateSelection = false;
        this.showTestTypeSelection = true;
    }

    // STEP 2: TEMPLATE SELECTION

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
            
            if (result.templateTypeOptions) {
                this.templateTypeOptions = result.templateTypeOptions;
            }
            
            const pagination = result.pagination;
            this.templateTotalPages = pagination.totalPages;
            this.templateTotalCount = pagination.totalCount;
            this.templateHasNext = pagination.hasNext;
            this.templateHasPrevious = pagination.hasPrevious;
            
            this.isLoadingTemplates = false;
        })
        .catch(error => {
            console.error('Error loading templates:', error);
            this.isLoadingTemplates = false;
            this.showToast('Error', 'Failed to load prompt templates: ' + error.body?.message, 'error');
        });
    }

    handleTemplateAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'select_primary') {
            this.selectedPrimaryTemplate = { ...row };
            this.showToast('Success', 'Primary template selected: ' + row.Name, 'success');
        } else if (actionName === 'select_secondary') {
            this.selectedSecondaryTemplate = { ...row };
            this.showToast('Success', 'Secondary template selected: ' + row.Name, 'success');
        }
    }

    handleRetrieverIdChange(event) {
        this.selectedRetrieverId = event.target.value;
    }

    // Template filter methods
    handleTemplateNameFilterChange(event) {
        this.templateNameFilter = event.target.value;
    }

    handleTemplateTypeFilterChange(event) {
        this.templateTypeFilter = event.target.value;
        // Automatically apply filter when template type changes
        this.templateCurrentPage = 1;
        this.loadTemplates();
    }

    handleTemplateStatusFilterChange(event) {
        this.templateStatusFilter = event.target.value;
    }

    handleApplyTemplateFilters() {
        this.templateCurrentPage = 1;
        this.loadTemplates();
    }

    handleClearTemplateFilters() {
        this.templateNameFilter = '';
        this.templateTypeFilter = '';
        this.templateStatusFilter = '';
        this.templateCurrentPage = 1;
        this.loadTemplates();
    }

    // Template pagination
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

    handleContinueToRecords() {
        if (this.continueToRecordsDisabled) {
            return;
        }
        
        this.showTemplateSelection = false;
        this.showRecordSelection = true;
        this.updateDataColumns();
        this.loadDataRecords();
    }

    handleContinueToData() {
        if (this.continueToDataDisabled) {
            return;
        }
        
        this.showTemplateSelection = false;
        this.showDataSelection = true;
        this.updateDataColumns();
        this.loadDataRecords();
    }

    handleBackToTestType() {
        this.showTemplateSelection = false;
        this.showTestTypeSelection = true;
    }

    // STEP 3: DATA SELECTION

    handleWorkSummaryDataTypeChange(event) {
        this.workSummaryDataType = event.target.value;
        this.updateDataColumns();
        this.currentPage = 1;
        this.loadDataRecords();
    }

    loadDataRecords() {
        this.isLoadingData = true;
        
        let loadMethod;
        let methodParams = {
            pageSize: this.getPageSizeForTestType(),
            pageNumber: this.currentPage,
            startDate: this.startDate || null,
            endDate: this.endDate || null
        };
        
        switch (this.selectedTestType) {
            case 'Service Replies':
                loadMethod = getMessagingSessions;
                methodParams.sessionName = this.recordName || null;
                methodParams.status = this.selectedStatus || null;
                break;
            case 'Case Summary':
                loadMethod = getCases;
                methodParams.subject = this.recordName || null;
                methodParams.status = this.selectedStatus || null;
                break;
            case 'Work Summary':
                if (this.workSummaryDataType === 'VoiceCall') {
                    loadMethod = getVoiceCalls;
                    methodParams.callType = null; // Could add filter later
                    methodParams.status = this.selectedStatus || null;
                } else {
                    loadMethod = getMessagingSessions;
                    methodParams.sessionName = this.recordName || null;
                    methodParams.status = this.selectedStatus || null;
                }
                break;
        }
        
        loadMethod(methodParams)
        .then(result => {
            this.processDataResult(result);
            this.isLoadingData = false;
        })
        .catch(error => {
            console.error('Error loading data records:', error);
            this.isLoadingData = false;
            this.showToast('Error', 'Failed to load data records: ' + error.body?.message, 'error');
        });
    }
    
    processDataResult(result) {
        let records = [];
        
        switch (this.selectedTestType) {
            case 'Service Replies':
            case 'Work Summary':
                if (this.workSummaryDataType === 'VoiceCall') {
                    records = result.voiceCalls || [];
                } else {
                    records = (result.sessions || []).map(session => ({
                        id: session.Id,
                        name: session.Name,
                        nameUrl: `/lightning/r/MessagingSession/${session.Id}/view`,
                        transcript: session.transcript ? this.truncateTranscriptByUtterances(session.transcript, 6) : 'No transcript available'
                    }));
                }
                break;
            case 'Case Summary':
                records = (result.cases || []).map(caseRecord => ({
                    id: caseRecord.Id,
                    ...caseRecord
                }));
                break;
        }
        
        this.dataRecords = records;
        this.filteredDataRecords = [...records];
        
        // Update pagination
        const pagination = result.pagination;
        this.totalPages = pagination.totalPages;
        this.totalCount = pagination.totalCount;
        this.hasNext = pagination.hasNext;
        this.hasPrevious = pagination.hasPrevious;
    }
    
    getPageSizeForTestType() {
        switch (this.selectedTestType) {
            case 'Case Summary':
                return this.casesPageSize;
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? this.voiceCallsPageSize : this.messagingSessionsPageSize;
            default:
                return this.messagingSessionsPageSize;
        }
    }

    // Data filter methods
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleRecordNameChange(event) {
        this.recordName = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleApplyFilters() {
        this.currentPage = 1;
        this.loadDataRecords();
    }

    handleClearFilters() {
        this.startDate = '';
        this.endDate = '';
        this.recordName = '';
        this.selectedStatus = '';
        this.currentPage = 1;
        this.loadDataRecords();
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.filteredDataRecords = this.dataRecords.filter(record =>
            record.name?.toLowerCase().includes(this.searchKey) ||
            record.Subject?.toLowerCase().includes(this.searchKey) ||
            record.CaseNumber?.toLowerCase().includes(this.searchKey)
        );
    }

    handleRowSelection(event) {
        this.selectedRecordIds = event.detail.selectedRows.map(row => row.id);
    }

    // Data pagination
    handlePreviousPage() {
        if (this.hasPrevious) {
            this.currentPage--;
            this.loadDataRecords();
        }
    }

    handleNextPage() {
        if (this.hasNext) {
            this.currentPage++;
            this.loadDataRecords();
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.loadDataRecords();
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.loadDataRecords();
    }

    handleBackToTemplates() {
        this.showRecordSelection = false;
        this.showTemplateSelection = true;
        
        // Clear data selections when going back
        this.selectedRecordIds = [];
        this.dataRecords = [];
        this.filteredDataRecords = [];
    }

    // Additional filter handlers for different record types
    handleSessionNameChange(event) {
        this.recordName = event.target.value;
    }

    handleCaseSubjectChange(event) {
        this.recordName = event.target.value;
    }

    handleCaseStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleCallTypeChange(event) {
        this.selectedCallType = event.target.value;
    }

    handleVoiceCallStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    // Quality Assessment Methods
    handleQualityAssessmentToggle(event) {
        this.enableQualityAssessment = event.target.checked;
        
        // Clear quality template IDs if disabling
        if (!this.enableQualityAssessment) {
            this.faithfulnessTemplateId = '';
            this.relevancyTemplateId = '';
            this.contextQualityTemplateId = '';
        }
    }

    handleFaithfulnessTemplateChange(event) {
        this.faithfulnessTemplateId = event.target.value;
    }

    handleRelevancyTemplateChange(event) {
        this.relevancyTemplateId = event.target.value;
    }

    handleContextQualityTemplateChange(event) {
        this.contextQualityTemplateId = event.target.value;
    }

    // Knowledge Grounding Methods
    handlePrimaryKnowledgeGroundingChange(event) {
        this.primaryUsesKnowledgeGrounding = event.target.checked;
    }

    handleSecondaryKnowledgeGroundingChange(event) {
        this.secondaryUsesKnowledgeGrounding = event.target.checked;
    }

    handleQualityTemplateAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'select_faithfulness') {
            this.selectedFaithfulnessTemplate = { ...row };
            this.showToast('Success', 'Faithfulness template selected: ' + row.Name, 'success');
        } else if (actionName === 'select_relevancy') {
            this.selectedRelevancyTemplate = { ...row };
            this.showToast('Success', 'Relevancy template selected: ' + row.Name, 'success');
        } else if (actionName === 'select_context_quality') {
            this.selectedContextQualityTemplate = { ...row };
            this.showToast('Success', 'Context Quality template selected: ' + row.Name, 'success');
        }
    }

    // STEP 4: CREATE TEST BATCH

    handleCreateAdvancedTestBatch() {
        if (this.selectedRecordIds.length === 0) {
            this.showToast('Error', 'Please select at least one record.', 'error');
            return;
        }

        // Enhanced validation and debugging
        console.log('=== JS DEBUG: handleCreateAdvancedTestBatch START ===');
        console.log('selectedTestType:', this.selectedTestType);
        console.log('selectedRecordIds:', this.selectedRecordIds);
        console.log('selectedPrimaryTemplate:', this.selectedPrimaryTemplate);
        console.log('selectedSecondaryTemplate:', this.selectedSecondaryTemplate);
        console.log('selectedRetrieverId:', this.selectedRetrieverId);
        console.log('enableQualityAssessment:', this.enableQualityAssessment);
        console.log('faithfulnessTemplateId:', this.faithfulnessTemplateId);
        console.log('relevancyTemplateId:', this.relevancyTemplateId);
        console.log('contextQualityTemplateId:', this.contextQualityTemplateId);

        // Validate required fields
        if (!this.selectedPrimaryTemplate || !this.selectedPrimaryTemplate.Id) {
            this.showToast('Error', 'Primary template is required but not selected or missing ID.', 'error');
            return;
        }

        if (this.selectedTestType === 'Service Replies' && (!this.selectedSecondaryTemplate || !this.selectedSecondaryTemplate.Id)) {
            this.showToast('Error', 'Secondary template is required for Service Replies but not selected or missing ID.', 'error');
            return;
        }

        this.showToast('Processing', 'Creating test batch...', 'info');

        const params = {
            testType: this.selectedTestType,
            recordIds: this.selectedRecordIds,
            primaryTemplateId: this.selectedPrimaryTemplate.Id,
            secondaryTemplateId: this.selectedSecondaryTemplate?.Id || null,
            retrieverId: this.selectedRetrieverId || null,
            enableQualityAssessment: this.enableQualityAssessment,
            faithfulnessTemplateId: this.faithfulnessTemplateId || null,
            relevancyTemplateId: this.relevancyTemplateId || null,
            contextQualityTemplateId: this.contextQualityTemplateId || null,
            primaryUsesKnowledgeGrounding: this.primaryUsesKnowledgeGrounding,
            secondaryUsesKnowledgeGrounding: this.secondaryUsesKnowledgeGrounding
        };

        console.log('=== JS DEBUG: UI Knowledge Grounding Values ===');
        console.log('this.primaryUsesKnowledgeGrounding:', this.primaryUsesKnowledgeGrounding);
        console.log('this.secondaryUsesKnowledgeGrounding:', this.secondaryUsesKnowledgeGrounding);
        console.log('params.primaryUsesKnowledgeGrounding:', params.primaryUsesKnowledgeGrounding);
        console.log('params.secondaryUsesKnowledgeGrounding:', params.secondaryUsesKnowledgeGrounding);

        console.log('=== JS DEBUG: Calling Apex with params ===');
        console.log('params:', JSON.stringify(params, null, 2));

        createAdvancedTestBatch(params)
        .then(result => {
            console.log('Test batch creation result:', result);
            
            let message = `${result.testType} test batch created successfully!\n`;
            message += `Batch ID: ${result.batchId}\n`;
            message += `Test Records Created: ${result.testRecordsCreated}\n`;
            message += `Records Processed: ${result.recordsProcessed}`;
            
            if (result.totalCustomerUtterances) {
                message += `\nCustomer Utterances Found: ${result.totalCustomerUtterances}`;
            }
            
            if (result.recordsSkipped > 0) {
                message += `\nRecords Skipped: ${result.recordsSkipped}`;
            }
            
            if (result.dataSourceType) {
                message += `\nData Source Type: ${result.dataSourceType}`;
            }
            
            this.showToast('Success', message, 'success');
            
            // Clear selected records but stay on step 3 for creating more batches
            this.selectedRecordIds = [];
            
            // Clear any row selections in the data table
            const datatable = this.template.querySelector('lightning-datatable');
            if (datatable) {
                datatable.selectedRows = [];
            }
        })
        .catch(error => {
            console.error('Error creating test batch:', error);
            this.showToast('Error', 'Failed to create test batch: ' + error.body?.message, 'error');
        });
    }

    handleCreateTestBatch() {
        // Alias for handleCreateAdvancedTestBatch
        this.handleCreateAdvancedTestBatch();
    }
    
    resetComponent() {
        // Reset all selections and go back to test type selection
        this.selectedTestType = '';
        this.selectedPrimaryTemplate = null;
        this.selectedSecondaryTemplate = null;
        this.selectedRecordIds = [];
        this.dataRecords = [];
        this.filteredDataRecords = [];
        
        // Reset steps
        this.showDataSelection = false;
        this.showTemplateSelection = false;
        this.showTestTypeSelection = true;
    }

    // COMPUTED PROPERTIES

    // Step 1 - Test Type Selection
    get testTypeDescription() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Test Einstein service reply suggestions for chat conversations using contextual and grounded templates.';
            case 'Case Summary':
                return 'Test Einstein case summarization for support cases using a single summary template.';
            case 'Work Summary':
                return 'Test Einstein work summarization for conversations and calls using a single summary template.';
            default:
                return '';
        }
    }

    // Step 2 - Template Selection
    get requiresPrimaryTemplate() {
        return this.selectedTestType !== '';
    }

    get requiresSecondaryTemplate() {
        return this.selectedTestType === 'Service Replies';
    }

    get primaryTemplateLabel() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Contextual Template';
            case 'Case Summary':
                return 'Summary Template';
            case 'Work Summary':
                return 'Summary Template';
            default:
                return 'Primary Template';
        }
    }

    get secondaryTemplateLabel() {
        return 'Grounded Template';
    }

    get showRetrieverConfig() {
        return this.selectedTestType === 'Service Replies';
    }

    get showKnowledgeGroundingConfig() {
        return this.selectedPrimaryTemplate || this.selectedSecondaryTemplate;
    }

    get continueToRecordsLabel() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Continue to Messaging Sessions';
            case 'Case Summary':
                return 'Continue to Cases';
            case 'Work Summary':
                return 'Continue to Records';
            default:
                return 'Continue to Record Selection';
        }
    }

    get continueToRecordsDisabled() {
        if (!this.selectedPrimaryTemplate) return true;
        if (this.selectedTestType === 'Service Replies' && !this.selectedSecondaryTemplate) return true;
        if (this.selectedTestType === 'Service Replies' && !this.selectedRetrieverId) return true;
        return false;
    }

    // Step 3 - Record Selection
    get recordSelectionTitle() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Step 3: Select Messaging Sessions';
            case 'Case Summary':
                return 'Step 3: Select Cases';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'Step 3: Select Voice Calls' : 'Step 3: Select Messaging Sessions';
            default:
                return 'Step 3: Select Records';
        }
    }

    get recordSelectionIcon() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'standard:live_chat';
            case 'Case Summary':
                return 'standard:case';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'standard:voice_call' : 'standard:live_chat';
            default:
                return 'standard:record';
        }
    }

    get isLoadingRecords() {
        return this.isLoadingData;
    }

    get loadingRecordsMessage() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Loading messaging sessions...';
            case 'Case Summary':
                return 'Loading cases...';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'Loading voice calls...' : 'Loading messaging sessions...';
            default:
                return 'Loading records...';
        }
    }

    get filteredRecords() {
        return this.filteredDataRecords;
    }

    get recordColumns() {
        return this.dataColumns;
    }

    get showMessagingFilters() {
        return (this.selectedTestType === 'Service Replies') || 
               (this.selectedTestType === 'Work Summary' && this.workSummaryDataType === 'MessagingSession');
    }

    get showCaseFilters() {
        return this.selectedTestType === 'Case Summary';
    }

    get showVoiceCallFilters() {
        return this.selectedTestType === 'Work Summary' && this.workSummaryDataType === 'VoiceCall';
    }

    get quickSearchLabel() {
        switch (this.selectedTestType) {
            case 'Case Summary':
                return 'Quick Search Cases';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'Quick Search Voice Calls' : 'Quick Search Sessions';
            default:
                return 'Quick Search Sessions';
        }
    }

    get recordTypeLabel() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'messaging session';
            case 'Case Summary':
                return 'case';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'voice call' : 'messaging session';
            default:
                return 'record';
        }
    }

    get recordSelectionDescription() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'These sessions will be processed for customer utterances to test service reply suggestions.';
            case 'Case Summary':
                return 'These cases will be processed to test case summarization.';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'These voice calls will be processed to test work summarization.' : 'These sessions will be processed to test work summarization.';
            default:
                return 'These records will be processed for testing.';
        }
    }

    get hasNoSelections() {
        return this.selectedRecordIds.length === 0;
    }

    get continueToDataDisabled() {
        if (!this.selectedPrimaryTemplate) return true;
        if (this.selectedTestType === 'Service Replies' && !this.selectedSecondaryTemplate) return true;
        if (this.selectedTestType === 'Service Replies' && !this.selectedRetrieverId) return true;
        return false;
    }

    get createBatchDisabled() {
        return this.selectedRecordIds.length === 0;
    }

    get showSecondaryTemplate() {
        return this.selectedTestType === 'Service Replies';
    }

    get showRetrieverId() {
        return this.selectedTestType === 'Service Replies';
    }

    get showWorkSummaryDataType() {
        return this.selectedTestType === 'Work Summary';
    }

    get dataSelectionTitle() {
        switch (this.selectedTestType) {
            case 'Service Replies':
                return 'Select Messaging Sessions';
            case 'Case Summary':
                return 'Select Cases';
            case 'Work Summary':
                return this.workSummaryDataType === 'VoiceCall' ? 'Select Voice Calls' : 'Select Messaging Sessions';
            default:
                return 'Select Records';
        }
    }

    get recordNamePlaceholder() {
        switch (this.selectedTestType) {
            case 'Case Summary':
                return 'Search by case subject...';
            default:
                return 'Search by name...';
        }
    }

    get recordNameLabel() {
        switch (this.selectedTestType) {
            case 'Case Summary':
                return 'Case Subject';
            default:
                return 'Record Name';
        }
    }

    // Template computed properties
    get templateCurrentPageInfo() {
        if (this.templateTotalCount === 0) return '0 - 0 of 0';
        const start = (this.templateCurrentPage - 1) * this.promptTemplatesPageSize + 1;
        const end = Math.min(this.templateCurrentPage * this.promptTemplatesPageSize, this.templateTotalCount);
        return `${start} - ${end} of ${this.templateTotalCount}`;
    }

    get templateShowPagination() {
        return this.templateTotalPages > 1;
    }

    // Data computed properties
    get currentPageInfo() {
        const pageSize = this.getPageSizeForTestType();
        const start = (this.currentPage - 1) * pageSize + 1;
        const end = Math.min(this.currentPage * pageSize, this.totalCount);
        return `${start} - ${end} of ${this.totalCount}`;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get isTemplateTypeFilterDisabled() {
        return this.isLoadingTemplates || this.templateTypeOptions.length === 0;
    }

    // Dynamic template columns based on test type
    get templateColumns() {
        const columns = [...baseTemplateColumns];
        
        if (this.selectedTestType === 'Service Replies') {
            // Service Replies needs both contextual and grounded template selection
            columns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Select as Contextual', name: 'select_primary' },
                        { label: 'Select as Grounded', name: 'select_secondary' }
                    ]
                }
            });
        } else if (this.selectedTestType === 'Case Summary' || this.selectedTestType === 'Work Summary') {
            // Case Summary and Work Summary only need one summary template
            columns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Select as Summary', name: 'select_primary' }
                    ]
                }
            });
        } else {
            // Default fallback
            columns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'Select as Primary', name: 'select_primary' },
                        { label: 'Select as Secondary', name: 'select_secondary' }
                    ]
                }
            });
        }
        
        return columns;
    }

    // Quality Assessment computed properties
    get qualityAssessmentStatusLabel() {
        if (!this.enableQualityAssessment) {
            return 'Disabled';
        }
        
        const hasTemplates = this.faithfulnessTemplateId || 
                           this.relevancyTemplateId || 
                           this.contextQualityTemplateId;
        
        if (!hasTemplates) {
            return 'No Templates Configured';
        }
        
        let configuredCount = 0;
        if (this.faithfulnessTemplateId) configuredCount++;
        if (this.relevancyTemplateId) configuredCount++;
        if (this.contextQualityTemplateId) configuredCount++;
        
        return `${configuredCount} Metric${configuredCount > 1 ? 's' : ''} Configured`;
    }

    get qualityAssessmentStatusVariant() {
        if (!this.enableQualityAssessment) {
            return 'inverse';
        }
        
        const hasTemplates = this.faithfulnessTemplateId || 
                           this.relevancyTemplateId || 
                           this.contextQualityTemplateId;
        
        if (!hasTemplates) {
            return 'warning';
        }
        
        return 'success';
    }

    // UTILITY METHODS

    truncateTranscriptByUtterances(transcript, maxUtterances = 6) {
        if (!transcript) return 'No transcript available';
        
        // Try to split by common utterance delimiters
        // Look for patterns like "Agent:", "Customer:", "User:", or line breaks that indicate new speakers
        let utterances = [];
        
        // Split by lines and filter out empty lines
        const lines = transcript.split('\n').filter(line => line.trim());
        
        // If we have line-based utterances, use those
        if (lines.length > 1) {
            utterances = lines;
        } else {
            // Fallback: try to split by common speaker patterns
            const speakerPattern = /(?:Agent|Customer|User|Bot|System|Rep):/gi;
            const parts = transcript.split(speakerPattern);
            
            if (parts.length > 1) {
                // Reconstruct with speakers - skip first empty part if it exists
                const speakers = transcript.match(speakerPattern) || [];
                utterances = [];
                let startIndex = parts[0].trim() === '' ? 1 : 0;
                
                for (let i = startIndex; i < parts.length && i - startIndex < speakers.length; i++) {
                    if (parts[i].trim()) {
                        utterances.push((speakers[i - startIndex] || '') + parts[i].trim());
                    }
                }
            } else {
                // Final fallback: split by sentence-like patterns or use character limit
                const sentences = transcript.split(/[.!?]+/).filter(s => s.trim());
                if (sentences.length > 1) {
                    utterances = sentences.map(s => s.trim() + '.');
                } else {
                    // No clear utterance boundaries found, use original character-based truncation
                    return transcript.length > 300 ? transcript.substring(0, 300) + '...' : transcript;
                }
            }
        }
        
        // Take the first maxUtterances
        const selectedUtterances = utterances.slice(0, maxUtterances);
        let result = selectedUtterances.join('\n');
        
        // Add ellipsis if we truncated
        if (utterances.length > maxUtterances) {
            result += '\n...';
        }
        
        // Ensure we don't return an overly long result (safety check)
        if (result.length > 500) {
            result = result.substring(0, 500) + '...';
        }
        
        return result;
    }

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
