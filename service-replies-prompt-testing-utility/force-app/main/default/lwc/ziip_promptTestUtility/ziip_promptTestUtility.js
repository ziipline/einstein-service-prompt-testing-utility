import { LightningElement, api, wire } from 'lwc';
import getMessagingSessions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getMessagingSessions';
import getStatusOptions from '@salesforce/apex/ziip_PromptTestUtil_Controller.getStatusOptions';
import createTestBatch from '@salesforce/apex/ziip_PromptTestUtil_Controller.createTestBatch';

const columns = [
    { label: 'Session Name', fieldName: 'name', type: 'text' },
    { label: 'Transcript', fieldName: 'transcript', type: 'text', wrapText: true }
];

export default class Ziip_promptTestUtility extends LightningElement {
    
    @api pageSize = 10;
    
    sessions = [];
    filteredSessions = [];
    selectedSessionIds = [];
    searchKey = '';
    columns = columns;
    isLoading = true;
    
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
        this.loadSessions();
    }

    loadSessions() {
        this.isLoading = true;
        
        getMessagingSessions({ 
            pageSize: this.pageSize, 
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
                transcript: session.transcript || 'No transcript available'
            }));
            this.filteredSessions = [...this.sessions];
            
            // Update pagination info
            const pagination = result.pagination;
            this.totalPages = pagination.totalPages;
            this.totalCount = pagination.totalCount;
            this.hasNext = pagination.hasNext;
            this.hasPrevious = pagination.hasPrevious;
            
            this.isLoading = false;
            console.log('Sessions loaded:', this.filteredSessions);
            console.log('Pagination info:', pagination);
        })
        .catch(error => {
            console.error('Error loading sessions:', error);
            this.isLoading = false;
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

    handleCreateTestBatch() {
        if (this.selectedSessionIds.length === 0) {
            alert('Please select at least one session.');
            return;
        }

        createTestBatch({ sessionIds: this.selectedSessionIds })
            .then(() => {
                alert('Test batch created successfully.');
            })
            .catch(error => {
                console.error(error);
                alert('An error occurred while creating the test batch.');
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

    // Computed properties for pagination display
    get currentPageInfo() {
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalCount);
        return `${start} - ${end} of ${this.totalCount}`;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get hasNoSelections() {
        return this.selectedSessionIds.length === 0;
    }
}
