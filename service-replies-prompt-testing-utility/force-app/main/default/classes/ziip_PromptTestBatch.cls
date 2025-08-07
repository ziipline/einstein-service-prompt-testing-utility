/**
 * @description Simplified batch class for processing Prompt Tests with Einstein AI templates
 * Now uses utility classes for formatting, parsing, and debug logging
 * Supports multiple test types: Service Replies, Case Summary, Work Summary
 * @author Ziipline
 */
public class ziip_PromptTestBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    /**
     * @description Wrapper class to hold prompt execution results
     */
    public class PromptExecutionResult {
        public String resultText;
        public String resolvedPrompt;
        public String requestId;
        
        public PromptExecutionResult(String resultText, String resolvedPrompt, String requestId) {
            this.resultText = resultText;
            this.resolvedPrompt = resolvedPrompt;
            this.requestId = requestId;
        }
    }
    
    // ===========================================
    // STATUS CONSTANTS
    // ===========================================
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_IN_PROGRESS = 'In Progress';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_FAILED = 'Failed';
    
    // ===========================================
    // TEMPLATE TYPE CONSTANTS
    // ===========================================
    private static final String TEMPLATE_TYPE_SERVICE_CONTEXTUAL = 'Service Reply - Contextual';
    private static final String TEMPLATE_TYPE_SERVICE_GROUNDED = 'Service Reply - Grounded';
    
    // ===========================================
    // EINSTEIN AI INPUT PARAMETER CONSTANTS
    // ===========================================
    private static final String INPUT_CONVERSATION_TRANSCRIPT = 'Input:conversation_transcript';
    private static final String INPUT_CASE_TO_SUMMARIZE = 'Input:caseToSummarize';
    private static final String INPUT_RETRIEVER_ID_OR_NAME = 'Input:RetrieverIdOrName';
    private static final String INPUT_SEARCH_QUERY = 'Input:search_query';
    private static final String INPUT_MESSAGING_SESSION = 'Input:MessagingSession';
    private static final String INPUT_VOICE_CALL = 'Input:VoiceCall';
    
    // ===========================================
    // PROCESSING CONFIGURATION CONSTANTS
    // ===========================================
    private static final Integer NUM_GENERATIONS = 1;
    private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';
    private static final String DEFAULT_RETRIEVER_ID = '';
    private static final String INVALID_SEARCH_QUERY_VALUE = 'none';
    private static final String MESSAGING_SESSION_ID_KEY = 'id';
    private static final String RECORD_ID_KEY = 'id';
    
    // ===========================================
    // JSON RESPONSE FIELD CONSTANTS
    // ===========================================
    private static final String JSON_SEARCH_QUERY = 'search_query';
    
    // ===========================================
    // ERROR MESSAGE CONSTANTS
    // ===========================================
    private static final String ERROR_TEMPLATE_IDS_NOT_CONFIGURED = 'Template IDs not configured properly for this test type.';
    private static final String ERROR_BLANK_TEMPLATE_ID = 'Template ID cannot be blank';
    private static final String ERROR_NO_RESPONSE_GENERATED = 'No response generated from prompt template';
    private static final String ERROR_PROCESSING_PROMPT_TEST = 'Error processing Prompt_Test__c: ';
    private static final String ERROR_EXECUTING_PROMPT = 'Failed to execute Einstein prompt (Template ID: ';
    private static final String ERROR_GETTING_CONTEXT = 'Error getting context data: ';
    private static final String ERROR_PARSING_JSON = 'Error parsing result JSON: ';
    private static final String ERROR_UPDATING_RECORDS = 'Error updating test records: ';
    private static final String ERROR_UPDATING_BATCH_STATUS = 'Error updating batch status: ';
    private static final String ERROR_PREFIX = 'Error: ';
    
    private final Set<Id> batchIds;
    
    // Dependency processing state
    private Boolean processingChildTests = false; // Track if we're in child processing phase
    private Integer executionCount = 0; // Prevent infinite loops
    private static final Integer MAX_EXECUTIONS = 10; // Safety limit
    
    /**
     * @description Constructor for the batch class
     * @param batchIds Set of Prompt Test Batch IDs to process
     */
    public ziip_PromptTestBatch(Set<Id> batchIds) {
        this.batchIds = batchIds;
    }
    
    /**
     * @description Start method for the batch job - implements dependency-aware processing
     * @param bc Database.BatchableContext
     * @return Database.QueryLocator for pending prompt tests
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        executionCount++; // Track execution count for safety
        
        System.debug('=== DEPENDENCY-AWARE BATCH START ===');
        System.debug('Execution count: ' + executionCount);
        System.debug('Processing child tests: ' + processingChildTests);
        System.debug('Batch IDs: ' + batchIds);
        
        String queryCondition;
        
        if (!processingChildTests) {
            // Phase 1: Process parent tests first (tests with no dependencies)
            queryCondition = 'AND Related_Test__c = null';
            System.debug('Phase 1: Querying for parent tests (Related_Test__c = null)');
        } else {
            // Phase 2: Process child tests (tests with dependencies)
            queryCondition = 'AND Related_Test__c != null';
            System.debug('Phase 2: Querying for child tests (Related_Test__c != null)');
        }
        
        String queryString = 
            'SELECT Id, Prompt_Test_Batch__c, Messaging_Session__c, Case__c, Voice_Call__c, Status__c, ' +
            'Transcript__c, Result__c, Template_Id__c, Template_Type__c, ' +
            'Resolved_Prompt__c, Related_Test__c, Raw_Result__c, Request_ID__c, ' +
            'Customer_Utterance__c, Utterance_Sequence__c, ' +
            'Prompt_Test_Batch__r.Test_Type__c, ' +
            'Prompt_Test_Batch__r.Retriever_Id__c ' +
            'FROM Prompt_Test__c ' +
            'WHERE Prompt_Test_Batch__c IN :batchIds ' +
            'AND Status__c = :STATUS_PENDING ' +
            queryCondition;
        
        System.debug('Query: ' + queryString);
        System.debug('=== DEPENDENCY-AWARE BATCH START COMPLETE ===');
        
        return Database.getQueryLocator(queryString);
    }
    
    /**
     * @description Execute method for processing each batch of Prompt Tests with dependency validation
     * @param bc Database.BatchableContext
     * @param scope List of Prompt_Test__c records to process
     */
    public void execute(Database.BatchableContext bc, List<Prompt_Test__c> scope) {
        List<Prompt_Test__c> testsToUpdate = new List<Prompt_Test__c>();
        Integer testsProcessed = 0;
        Integer testsSkipped = 0;
        
        System.debug('=== EXECUTING BATCH WITH ' + scope.size() + ' TESTS ===');
        System.debug('Processing child tests: ' + processingChildTests);
        
        for (Prompt_Test__c test : scope) {
            try {
                if (!validateTemplateConfiguration(test)) {
                    setTestFailed(test, ERROR_TEMPLATE_IDS_NOT_CONFIGURED);
                    testsToUpdate.add(test);
                    continue;
                }
                
                // Dependency validation for child tests
                if (processingChildTests && test.Related_Test__c != null) {
                    if (!isParentReady(test)) {
                        System.debug('Skipping child test ' + test.Id + ' - parent test not ready');
                        testsSkipped++;
                        continue; // Skip processing, keep as Pending
                    }
                }
                
                processPromptTest(test);
                test.Status__c = STATUS_COMPLETED;
                testsProcessed++;
                
            } catch (Exception e) {
                System.debug(ERROR_PROCESSING_PROMPT_TEST + test.Id + ' - ' + e.getMessage());
                setTestFailed(test, e.getMessage());
            }
            
            testsToUpdate.add(test);
        }
        
        System.debug('Tests processed: ' + testsProcessed + ', Tests skipped: ' + testsSkipped);
        System.debug('=== BATCH EXECUTION COMPLETE ===');
        
        updateTestRecords(testsToUpdate);
    }
    
    /**
     * @description Finish method called after all batches are processed - handles batch re-launching for dependencies
     * @param bc Database.BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('=== DEPENDENCY-AWARE BATCH FINISH ===');
        System.debug('Execution count: ' + executionCount);
        System.debug('Processing child tests: ' + processingChildTests);
        
        // Safety check to prevent infinite loops
        if (executionCount >= MAX_EXECUTIONS) {
            System.debug('Max execution limit reached (' + MAX_EXECUTIONS + '), stopping batch re-launches');
            updateBatchStatus();
            checkAndTriggerQualityAssessment();
            return;
        }
        
        if (!processingChildTests) {
            // Just finished processing parent tests, check if child tests exist
            List<Prompt_Test__c> pendingChildTests = [
                SELECT Id FROM Prompt_Test__c 
                WHERE Prompt_Test_Batch__c IN :batchIds
                AND Status__c = :STATUS_PENDING
                AND Related_Test__c != null
                LIMIT 1
            ];
            
            if (!pendingChildTests.isEmpty()) {
                System.debug('Parent tests completed, launching child test processing phase');
                
                // Create new batch instance for child processing
                ziip_PromptTestBatch childBatch = new ziip_PromptTestBatch(batchIds);
                childBatch.processingChildTests = true;
                childBatch.executionCount = this.executionCount;
                
                Database.executeBatch(childBatch);
                return; // Don't update batch status yet, child batch will handle it
            } else {
                System.debug('No pending child tests found, processing complete');
            }
        } else {
            // Just finished processing child tests, check if any are still pending
            List<Prompt_Test__c> stillPendingChildTests = [
                SELECT Id FROM Prompt_Test__c 
                WHERE Prompt_Test_Batch__c IN :batchIds
                AND Status__c = :STATUS_PENDING
                AND Related_Test__c != null
                LIMIT 1
            ];
            
            if (!stillPendingChildTests.isEmpty()) {
                System.debug('Some child tests still pending, re-launching child processing');
                
                // Re-launch child processing
                ziip_PromptTestBatch retryBatch = new ziip_PromptTestBatch(batchIds);
                retryBatch.processingChildTests = true;
                retryBatch.executionCount = this.executionCount;
                
                Database.executeBatch(retryBatch);
                return; // Don't update batch status yet
            } else {
                System.debug('All child tests completed, processing complete');
            }
        }
        
        System.debug('=== DEPENDENCY-AWARE BATCH FINISH COMPLETE ===');
        
        updateBatchStatus();
        checkAndTriggerQualityAssessment();
    }
    
    /**
     * @description Checks if parent test is ready (completed) for child test processing
     * @param childTest Prompt_Test__c child test record
     * @return Boolean indicating if parent is ready
     */
    private Boolean isParentReady(Prompt_Test__c childTest) {
        if (childTest.Related_Test__c == null) {
            return true; // This is a parent test, no dependency
        }
        
        List<Prompt_Test__c> parents = [
            SELECT Id, Status__c 
            FROM Prompt_Test__c 
            WHERE Id = :childTest.Related_Test__c 
            LIMIT 1
        ];
        
        Boolean parentReady = !parents.isEmpty() && parents[0].Status__c == STATUS_COMPLETED;
        
        if (!parentReady) {
            System.debug('Parent test ' + childTest.Related_Test__c + ' not ready for child test ' + childTest.Id);
        }
        
        return parentReady;
    }
    
    // ===========================================
    // CORE PROCESSING METHODS
    // ===========================================
    
    /**
     * @description Main processing method - executes the single template specified in the test record
     * @param test Prompt_Test__c record to process
     */
    private void processPromptTest(Prompt_Test__c test) {
        test.Status__c = STATUS_IN_PROGRESS;
        
        // Get template information from test record
        String templateId = test.Template_Id__c;
        String templateType = test.Template_Type__c;
        
        System.debug('Processing template: ' + templateId + ' (type: ' + templateType + ') for test ID: ' + test.Id);
        
        if (String.isBlank(templateId)) {
            throw new IllegalArgumentException('Template_Id__c is required for test execution');
        }
        
        if (String.isBlank(templateType)) {
            throw new IllegalArgumentException('Template_Type__c is required for test execution');
        }
        
        // Execute the single template
        PromptExecutionResult result = executeSingleTemplate(test, templateId, templateType);
        
        // Store raw result for contextual tests (needed by grounded tests to extract search query)
        if (templateType == TEMPLATE_TYPE_SERVICE_CONTEXTUAL) {
            test.Raw_Result__c = result.resultText; // Store raw JSON result
        }
        
        // Store formatted result, resolved prompt, and request ID
        test.Result__c = formatResult(result.resultText, templateType);
        test.Resolved_Prompt__c = result.resolvedPrompt;
        test.Request_ID__c = result.requestId;
    }
    
    /**
     * @description Executes a single template based on template type and context
     * @param test Prompt_Test__c record to process
     * @param templateId Template ID to execute
     * @param templateType Template type for context routing
     * @return PromptExecutionResult containing result and resolved prompt
     */
    private PromptExecutionResult executeSingleTemplate(Prompt_Test__c test, String templateId, String templateType) {
        String contextData = getContextDataForTemplate(test, templateType);
        String searchQuery = getSearchQueryForTemplate(test, templateType);
        String retrieverId = getRetrieverId(test);
        
        // For grounded templates, validate search query before execution
        if (templateType == TEMPLATE_TYPE_SERVICE_GROUNDED && !isValidSearchQuery(searchQuery)) {
            String skipMessage = buildGroundedSkipMessage(searchQuery);
            return new PromptExecutionResult(skipMessage, null, null);
        }
        
        return executePromptTemplate(templateId, test, contextData, searchQuery, retrieverId, templateType);
    }
    
    /**
     * @description Gets appropriate context data based on template type
     * @param test Prompt_Test__c record
     * @param templateType Template type
     * @return String context data for template execution
     */
    private String getContextDataForTemplate(Prompt_Test__c test, String templateType) {
        switch on templateType {
            when 'Service Reply - Contextual', 'Service Reply - Grounded' {
                return getMessagingSessionTranscript(test);
            }
            when 'Case Summary' {
                return getCaseContext(test);
            }
            when 'Work Summary' {
                return getWorkContext(test);
            }
            when else {
                return '';
            }
        }
    }
    
    /**
     * @description Gets search query for grounded templates by looking up related contextual test
     * @param test Prompt_Test__c record
     * @param templateType Template type
     * @return String search query for grounded templates
     */
    private String getSearchQueryForTemplate(Prompt_Test__c test, String templateType) {
        if (templateType == TEMPLATE_TYPE_SERVICE_GROUNDED && test.Related_Test__c != null) {
            // Get the search query from the related contextual test's raw result
            List<Prompt_Test__c> relatedTests = [
                SELECT Id, Raw_Result__c 
                FROM Prompt_Test__c 
                WHERE Id = :test.Related_Test__c 
                LIMIT 1
            ];
            
            if (!relatedTests.isEmpty() && String.isNotBlank(relatedTests[0].Raw_Result__c)) {
                return extractSearchQueryFromResult(relatedTests[0].Raw_Result__c);
            }
        }
        
        return null;
    }
    
    /**
     * @description Formats result based on template type using utility formatter
     * @param resultText Raw result text from template execution
     * @param templateType Template type for formatting logic
     * @return String formatted result
     */
    private String formatResult(String resultText, String templateType) {
        return ziip_PromptResultFormatter.formatResult(resultText, templateType);
    }
    
    // ===========================================
    // CONTEXT EXTRACTION METHODS
    // ===========================================
    
    /**
     * @description Gets messaging session transcript for Service Replies and Work Summary
     * @param test Prompt_Test__c record
     * @return String transcript content
     */
    private String getMessagingSessionTranscript(Prompt_Test__c test) {
        String transcript = test.Transcript__c;
        if (String.isBlank(transcript) && test.Messaging_Session__c != null) {
            transcript = getTranscriptFromSession(test.Messaging_Session__c);
            test.Transcript__c = transcript;
        }
        return transcript;
    }
    
    /**
     * @description Gets case context for Case Summary tests
     * @param test Prompt_Test__c record
     * @return String formatted case context
     */
    private String getCaseContext(Prompt_Test__c test) {
        try {
            if (test.Case__c == null) {
                return '';
            }
            
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Description, Status, Priority, Reason, Type,
                       Account.Name, Contact.Name, Owner.Name, CreatedDate, ClosedDate,
                       Origin, IsClosed, IsEscalated
                FROM Case 
                WHERE Id = :test.Case__c
                LIMIT 1
            ];
            
            if (cases.isEmpty()) {
                return '';
            }
            
            Case caseRecord = cases[0];
            String context = 'Case Number: ' + caseRecord.CaseNumber + '\n';
            context += 'Subject: ' + (caseRecord.Subject ?? '') + '\n';
            context += 'Description: ' + (caseRecord.Description ?? '') + '\n';
            context += 'Status: ' + (caseRecord.Status ?? '') + '\n';
            context += 'Priority: ' + (caseRecord.Priority ?? '') + '\n';
            context += 'Type: ' + (caseRecord.Type ?? '') + '\n';
            context += 'Reason: ' + (caseRecord.Reason ?? '') + '\n';
            context += 'Account: ' + (caseRecord.Account?.Name ?? '') + '\n';
            context += 'Contact: ' + (caseRecord.Contact?.Name ?? '') + '\n';
            context += 'Owner: ' + (caseRecord.Owner?.Name ?? '') + '\n';
            context += 'Created: ' + (caseRecord.CreatedDate?.format() ?? '') + '\n';
            context += 'Origin: ' + (caseRecord.Origin ?? '') + '\n';
            context += 'Is Closed: ' + caseRecord.IsClosed + '\n';
            context += 'Is Escalated: ' + caseRecord.IsEscalated + '\n';
            
            return context;
            
        } catch (Exception e) {
            System.debug(ERROR_GETTING_CONTEXT + e.getMessage());
            return ERROR_GETTING_CONTEXT + e.getMessage();
        }
    }
    
    /**
     * @description Gets work context for Work Summary tests (messaging session or voice call)
     * @param test Prompt_Test__c record
     * @return String formatted work context
     */
    private String getWorkContext(Prompt_Test__c test) {
        // For messaging sessions, use transcript
        if (test.Messaging_Session__c != null) {
            return getMessagingSessionTranscript(test);
        }
        
        // For voice calls, get call details
        if (test.Voice_Call__c != null) {
            return getVoiceCallContext(test.Voice_Call__c);
        }
        
        return '';
    }
    
    /**
     * @description Gets voice call context
     * @param voiceCallId Voice Call ID
     * @return String formatted voice call context
     */
    private String getVoiceCallContext(Id voiceCallId) {
        try {
            List<VoiceCall> voiceCalls = [
                SELECT Id, Name, CallType, CallStartDateTime, CallEndDateTime, 
                       CallDurationInSeconds, FromPhoneNumber, ToPhoneNumber,
                       CallDisposition, Description, Owner.Name
                FROM VoiceCall 
                WHERE Id = :voiceCallId
                LIMIT 1
            ];
            
            if (voiceCalls.isEmpty()) {
                return '';
            }
            
            VoiceCall call = voiceCalls[0];
            String context = 'Call Name: ' + (call.Name ?? '') + '\n';
            context += 'Call Type: ' + (call.CallType ?? '') + '\n';
            context += 'Start Time: ' + (call.CallStartDateTime?.format() ?? '') + '\n';
            context += 'End Time: ' + (call.CallEndDateTime?.format() ?? '') + '\n';
            context += 'Duration (seconds): ' + (call.CallDurationInSeconds ?? 0) + '\n';
            context += 'From: ' + (call.FromPhoneNumber ?? '') + '\n';
            context += 'To: ' + (call.ToPhoneNumber ?? '') + '\n';
            context += 'Disposition: ' + (call.CallDisposition ?? '') + '\n';
            context += 'Description: ' + (call.Description ?? '') + '\n';
            context += 'Owner: ' + (call.Owner?.Name ?? '') + '\n';
            
            return context;
            
        } catch (Exception e) {
            System.debug(ERROR_GETTING_CONTEXT + e.getMessage());
            return ERROR_GETTING_CONTEXT + e.getMessage();
        }
    }
    
    // ===========================================
    // TEMPLATE EXECUTION METHODS
    // ===========================================
    
    /**
     * @description Executes Einstein prompt template with flexible input parameters
     * @param templateId Einstein prompt template ID
     * @param test Prompt test record for context
     * @param contextData Main context data (transcript, case context, etc.)
     * @param searchQuery Search query for grounded templates
     * @param retrieverId Retriever ID for grounded templates
     * @param templateType Type of template being executed
     * @return PromptExecutionResult containing result text and resolved prompt
     */
    private PromptExecutionResult executePromptTemplate(String templateId, Prompt_Test__c test, String contextData, String searchQuery, String retrieverId, String templateType) {
        try {
            System.debug('Executing template: ' + templateId + ' (type: ' + templateType + ')');
            
            if (String.isBlank(templateId)) {
                throw new IllegalArgumentException(ERROR_BLANK_TEMPLATE_ID);
            }
            
            // Build input parameters based on template type and context
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptGenerationsInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptGenerationsInput.inputParams = buildInputParameters(test, contextData, searchQuery, retrieverId, templateType);
            
            // Configure prompt generation parameters
            promptGenerationsInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptGenerationsInput.additionalConfig.numGenerations = NUM_GENERATIONS;
            promptGenerationsInput.additionalConfig.enablePiiMasking = true;
            promptGenerationsInput.additionalConfig.applicationName = APPLICATION_NAME;
            promptGenerationsInput.isPreview = false;
            
            // Debug input parameters before API call
            System.debug('=== EXECUTING TEMPLATE ===');
            System.debug('Template ID: ' + templateId);
            System.debug('Template Type: ' + templateType);
            System.debug('Context Data Length: ' + (contextData != null ? contextData.length() : 0));
            System.debug('Search Query: ' + searchQuery);
            System.debug('Retriever ID: ' + retrieverId);
            
            // Call the service to generate messages
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateId, promptGenerationsInput);
            
            // Debug response
            System.debug('=== API RESPONSE ===');
            System.debug('Request ID: ' + (generationsOutput?.requestId));
            System.debug('Generations Count: ' + (generationsOutput?.generations?.size()));
            
            // Extract the generated text, resolved prompt, and request ID
            if (generationsOutput != null && generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                String resultText = generationsOutput.generations[0].text;
                String resolvedPrompt = generationsOutput.prompt; // This contains the resolved prompt with substituted values
                String requestId = generationsOutput.requestId; // Capture the request ID from Einstein API response
                return new PromptExecutionResult(resultText, resolvedPrompt, requestId);
            }
            
            return new PromptExecutionResult(ERROR_NO_RESPONSE_GENERATED, null, null);
            
        } catch (Exception e) {
            String errorMsg = ERROR_EXECUTING_PROMPT + templateId + ', type: ' + templateType + '): ' + e.getMessage();
            System.debug(errorMsg);
            throw new CalloutException(errorMsg);
        }
    }
    
    /**
     * @description Builds input parameters for Einstein prompt template
     * @param test Prompt test record
     * @param contextData Main context data
     * @param searchQuery Search query for grounded templates
     * @param retrieverId Retriever ID for grounded templates
     * @param templateType Type of template being executed
     * @return Map of input parameters
     */
    private Map<String, ConnectApi.WrappedValue> buildInputParameters(Prompt_Test__c test, String contextData, String searchQuery, String retrieverId, String templateType) {
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        
        // Add the main context data with appropriate parameter name
        ConnectApi.WrappedValue contextValue = new ConnectApi.WrappedValue();
        contextValue.value = contextData;
        
        switch on templateType {
            when 'Service Reply - Contextual', 'Service Reply - Grounded' {
                inputParams.put(INPUT_CONVERSATION_TRANSCRIPT, contextValue);
                // Add messaging session reference
                if (test.Messaging_Session__c != null) {
                    Map<String, String> sessionInput = new Map<String, String>();
                    sessionInput.put(MESSAGING_SESSION_ID_KEY, String.valueOf(test.Messaging_Session__c));
                    ConnectApi.WrappedValue sessionValue = new ConnectApi.WrappedValue();
                    sessionValue.value = sessionInput;
                    inputParams.put(INPUT_MESSAGING_SESSION, sessionValue);
                }
            }
            when 'Case Summary' {
                // Case Summary templates expect caseToSummarize parameter with case reference
                if (test.Case__c != null) {
                    Map<String, String> caseInput = new Map<String, String>();
                    caseInput.put(RECORD_ID_KEY, String.valueOf(test.Case__c));
                    ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
                    caseValue.value = caseInput;
                    inputParams.put(INPUT_CASE_TO_SUMMARIZE, caseValue);
                }
            }
            when 'Work Summary' {
                // Work Summary templates work directly with object references
                if (test.Messaging_Session__c != null) {
                    // For messaging sessions, only provide the session reference
                    Map<String, String> sessionInput = new Map<String, String>();
                    sessionInput.put(MESSAGING_SESSION_ID_KEY, String.valueOf(test.Messaging_Session__c));
                    ConnectApi.WrappedValue sessionValue = new ConnectApi.WrappedValue();
                    sessionValue.value = sessionInput;
                    inputParams.put(INPUT_MESSAGING_SESSION, sessionValue);
                } else if (test.Voice_Call__c != null) {
                    // For voice calls, only provide the voice call reference
                    Map<String, String> voiceCallInput = new Map<String, String>();
                    voiceCallInput.put(RECORD_ID_KEY, String.valueOf(test.Voice_Call__c));
                    ConnectApi.WrappedValue voiceCallValue = new ConnectApi.WrappedValue();
                    voiceCallValue.value = voiceCallInput;
                    inputParams.put(INPUT_VOICE_CALL, voiceCallValue);
                }
            }
        }
        
        // Add retriever and search query for grounded templates
        if (templateType == TEMPLATE_TYPE_SERVICE_GROUNDED && String.isNotBlank(retrieverId)) {
            ConnectApi.WrappedValue retrieverValue = new ConnectApi.WrappedValue();
            retrieverValue.value = retrieverId;
            inputParams.put(INPUT_RETRIEVER_ID_OR_NAME, retrieverValue);
            
            ConnectApi.WrappedValue searchQueryValue = new ConnectApi.WrappedValue();
            searchQueryValue.value = String.isNotBlank(searchQuery) ? searchQuery : '';
            inputParams.put(INPUT_SEARCH_QUERY, searchQueryValue);
        }
        
        return inputParams;
    }
    
    // ===========================================
    // HELPER METHODS
    // ===========================================
    
    
    /**
     * @description Gets retriever ID with default fallback
     * @param test Prompt_Test__c record
     * @return String retriever ID
     */
    private String getRetrieverId(Prompt_Test__c test) {
        return String.isNotBlank(test.Prompt_Test_Batch__r.Retriever_Id__c) 
            ? test.Prompt_Test_Batch__r.Retriever_Id__c 
            : DEFAULT_RETRIEVER_ID;
    }
    
    /**
     * @description Validates template configuration for individual test records
     * @param test Prompt_Test__c record to validate
     * @return Boolean indicating if template is properly configured
     */
    private Boolean validateTemplateConfiguration(Prompt_Test__c test) {
        // In the new model, each test record must have Template_Id__c and Template_Type__c
        return String.isNotBlank(test.Template_Id__c) && String.isNotBlank(test.Template_Type__c);
    }
    
    /**
     * @description Sets a test record to failed status with error message
     * @param test Prompt_Test__c record to mark as failed
     * @param errorMessage Error message to set
     */
    private void setTestFailed(Prompt_Test__c test, String errorMessage) {
        test.Status__c = STATUS_FAILED;
        test.Result__c = ERROR_PREFIX + errorMessage;
    }
    
    /**
     * @description Validates if a search query is valid for grounded template processing
     * @param searchQuery Search query to validate
     * @return Boolean indicating if search query is valid
     */
    private Boolean isValidSearchQuery(String searchQuery) {
        return String.isNotBlank(searchQuery) && 
               !searchQuery.equalsIgnoreCase(INVALID_SEARCH_QUERY_VALUE);
    }
    
    /**
     * @description Builds a skip message for grounded template processing
     * @param searchQuery Search query that caused the skip
     * @return String formatted skip message
     */
    private String buildGroundedSkipMessage(String searchQuery) {
        String skipReason = String.isBlank(searchQuery) ? 'empty/blank' : '"' + searchQuery + '"';
        return 'Grounded template skipped: Context template returned no valid search query (result was ' + skipReason + ')';
    }
    
    /**
     * @description Extracts search query from contextual template result
     * @param contextResult Raw JSON result from context template
     * @return String search query for use in grounded template
     */
    private String extractSearchQueryFromResult(String contextResult) {
        try {
            if (String.isBlank(contextResult)) {
                return '';
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(contextResult);
            
            if (resultMap.containsKey(JSON_SEARCH_QUERY)) {
                String searchQuery = String.valueOf(resultMap.get(JSON_SEARCH_QUERY));
                return searchQuery;
            }
            
        } catch (Exception e) {
            System.debug(ERROR_PARSING_JSON + e.getMessage());
            System.debug('Context result was: ' + contextResult);
        }
        
        return '';
    }
    
    /**
     * @description Retrieves transcript from messaging session
     * @param sessionId Messaging Session ID
     * @return String transcript content or empty string if not found
     */
    private String getTranscriptFromSession(Id sessionId) {
        try {
            List<MessagingSession> sessions = [
                SELECT Id, Name, ConversationId, Conversation.ConversationIdentifier
                FROM MessagingSession 
                WHERE Id = :sessionId
                LIMIT 1
            ];
            
            if (!sessions.isEmpty() && sessions[0].Conversation != null) {
                return ziip_PromptTestUtil_Controller.getConversationEntries(
                    sessions[0].Conversation.ConversationIdentifier
                );
            }
        } catch (Exception e) {
            System.debug(ERROR_GETTING_CONTEXT + e.getMessage());
        }
        return '';
    }
    
    /**
     * @description Updates test records with proper error handling
     * @param testsToUpdate List of Prompt_Test__c records to update
     */
    private void updateTestRecords(List<Prompt_Test__c> testsToUpdate) {
        if (!testsToUpdate.isEmpty()) {
            try {
                update testsToUpdate;
            } catch (DmlException e) {
                System.debug(ERROR_UPDATING_RECORDS + e.getMessage());
                throw e;
            }
        }
    }
    
    /**
     * @description Updates batch status to completed
     */
    private void updateBatchStatus() {
        List<Prompt_Test_Batch__c> batchesToUpdate = new List<Prompt_Test_Batch__c>();
        
        for (Id batchId : batchIds) {
            batchesToUpdate.add(new Prompt_Test_Batch__c(
                Id = batchId,
                Status__c = STATUS_COMPLETED,
                End_Datetime__c = System.now()
            ));
        }
        
        if (!batchesToUpdate.isEmpty()) {
            try {
                update batchesToUpdate;
            } catch (DmlException e) {
                System.debug(ERROR_UPDATING_BATCH_STATUS + e.getMessage());
                throw e;
            }
        }
    }
    
    /**
     * @description Checks if quality assessment should be triggered and launches ziip_PromptMetricsBatch
     */
    private void checkAndTriggerQualityAssessment() {
        try {
            // Query batches that have quality assessment enabled
            List<Prompt_Test_Batch__c> batchesToAssess = [
                SELECT Id, Enable_Quality_Assessment__c,
                       Faithfulness_Template_Id__c, Relevancy_Template_Id__c, 
                       Context_Quality_Template_Id__c
                FROM Prompt_Test_Batch__c 
                WHERE Id IN :batchIds 
                AND Enable_Quality_Assessment__c = true
            ];
            
            for (Prompt_Test_Batch__c batch : batchesToAssess) {
                // Check if at least one quality assessment template is configured
                Boolean hasQualityTemplates = String.isNotBlank(batch.Faithfulness_Template_Id__c) ||
                                            String.isNotBlank(batch.Relevancy_Template_Id__c) ||
                                            String.isNotBlank(batch.Context_Quality_Template_Id__c);
                
                if (hasQualityTemplates) {
                    System.debug('Triggering quality assessment for batch: ' + batch.Id);
                    
                    // Create metrics batch with optimal batch size calculation
                    ziip_PromptMetricsBatch metricsBatch = new ziip_PromptMetricsBatch(
                        new Set<Id>{batch.Id}
                    );
                    
                    // Launch the quality metrics batch with calculated batch size
                    Database.executeBatch(metricsBatch, metricsBatch.batchSize);
                } else {
                    System.debug('Quality assessment enabled for batch ' + batch.Id + 
                               ' but no assessment templates configured');
                }
            }
            
        } catch (Exception e) {
            System.debug('Error triggering quality assessment: ' + e.getMessage());
            // Don't throw exception to avoid failing the main batch
        }
    }
    
}
