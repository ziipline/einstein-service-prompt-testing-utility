/**
 * @description Batch class for processing Prompt Tests with Einstein AI templates
 * Supports multiple test types: Service Replies, Case Summary, Work Summary
 * @author Ziipline
 */
public class ziip_PromptTestBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    /**
     * @description Wrapper class to hold prompt execution results
     */
    public class PromptExecutionResult {
        public String resultText;
        public String resolvedPrompt;
        
        public PromptExecutionResult(String resultText, String resolvedPrompt) {
            this.resultText = resultText;
            this.resolvedPrompt = resolvedPrompt;
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
    // TEST TYPE CONSTANTS
    // ===========================================
    private static final String TEST_TYPE_SERVICE_REPLIES = 'Service Replies';
    private static final String TEST_TYPE_CASE_SUMMARY = 'Case Summary';
    private static final String TEST_TYPE_WORK_SUMMARY = 'Work Summary';
    
    // ===========================================
    // EINSTEIN AI INPUT PARAMETER CONSTANTS
    // ===========================================
    private static final String INPUT_CONVERSATION_TRANSCRIPT = 'Input:conversation_transcript';
    private static final String INPUT_CASE_TO_SUMMARIZE = 'Input:caseToSummarize';
    private static final String INPUT_RETRIEVER_ID_OR_NAME = 'Input:RetrieverIdOrName';
    private static final String INPUT_SEARCH_QUERY = 'Input:search_query';
    private static final String INPUT_MESSAGING_SESSION = 'Input:MessagingSession';
    private static final String INPUT_CASE = 'Input:Case';
    private static final String INPUT_VOICE_CALL = 'Input:VoiceCall';
    
    // ===========================================
    // JSON RESPONSE FIELD CONSTANTS
    // ===========================================
    private static final String JSON_SEARCH_QUERY = 'search_query';
    private static final String JSON_RECENT_SPEAKER = 'recent_speaker';
    private static final String JSON_ISSUE_ADDRESSED = 'issue_addressed_by_agent';
    private static final String JSON_RESPONSES = 'responses';
    private static final String JSON_RESPONSE = 'response';
    private static final String JSON_INTENT = 'intent';
    private static final String JSON_ARTICLE_RELEVANT = 'article_relevant';
    private static final String JSON_SNIPPET_IDENTIFIED = 'snippet_identified';
    private static final String JSON_SOURCE = 'source';
    private static final String JSON_SOURCE_RECORD_ID = 'sourceRecordId';
    private static final String JSON_DATA_SOURCE_OBJECT = 'dataSourceObject';
    private static final String JSON_SNIPPET_START = 'snippet_starting_word_num';
    private static final String JSON_SNIPPET_END = 'snippet_ending_word_num';
    
    // ===========================================
    // PROCESSING CONFIGURATION CONSTANTS
    // ===========================================
    private static final Integer NUM_GENERATIONS = 1;
    private static final Integer BATCH_SIZE_LIMIT = 200;
    private static final Integer MAX_RETRY_ATTEMPTS = 3;
    private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';
    private static final String DEFAULT_RETRIEVER_ID = '';
    private static final String INVALID_SEARCH_QUERY_VALUE = 'none';
    private static final String MESSAGING_SESSION_ID_KEY = 'id';
    private static final String RECORD_ID_KEY = 'id';
    
    // ===========================================
    // TEMPLATE TYPE CONSTANTS
    // ===========================================
    private static final String TEMPLATE_TYPE_CONTEXTUAL = 'contextual';
    private static final String TEMPLATE_TYPE_GROUNDED = 'grounded';
    private static final String TEMPLATE_TYPE_CASE_SUMMARY = 'case_summary';
    private static final String TEMPLATE_TYPE_WORK_SUMMARY = 'work_summary';
    
    // ===========================================
    // FORMATTING CONSTANTS
    // ===========================================
    private static final String NEWLINE = '\n';
    private static final String DOUBLE_NEWLINE = '\n\n';
    private static final String ERROR_PREFIX = 'Error: ';
    private static final String RAW_RESULT_PREFIX = '\n\nRaw Result:\n';
    private static final Integer RESPONSE_COUNTER_START = 1;
    
    // ===========================================
    // ERROR MESSAGE CONSTANTS
    // ===========================================
    private static final String ERROR_TEMPLATE_IDS_NOT_CONFIGURED = 'Template IDs not configured properly for this test type.';
    private static final String ERROR_BLANK_TEMPLATE_ID = 'Template ID cannot be blank';
    private static final String ERROR_NO_RESPONSE_GENERATED = 'No response generated from prompt template';
    private static final String ERROR_NO_RESULT = 'No result returned from template';
    private static final String ERROR_FORMATTING_RESULT = 'Error formatting result: ';
    private static final String ERROR_PROCESSING_PROMPT_TEST = 'Error processing Prompt_Test__c: ';
    private static final String ERROR_EXECUTING_PROMPT = 'Failed to execute Einstein prompt (Template ID: ';
    private static final String ERROR_GETTING_CONTEXT = 'Error getting context data: ';
    private static final String ERROR_PARSING_JSON = 'Error parsing result JSON: ';
    private static final String ERROR_UPDATING_RECORDS = 'Error updating test records: ';
    private static final String ERROR_UPDATING_BATCH_STATUS = 'Error updating batch status: ';
    private static final String ERROR_UNSUPPORTED_TEST_TYPE = 'Unsupported test type: ';
    
    // ===========================================
    // DEBUG CONSTANTS
    // ===========================================
    private static final String DEBUG_SEPARATOR = '='.repeat(50);
    private static final String DEBUG_SECTION_SEPARATOR = '-'.repeat(30);
    private static final String DEBUG_CONNECTAPI_START = 'CONNECTAPI DEBUG START';
    private static final String DEBUG_CONNECTAPI_END = 'CONNECTAPI DEBUG END';
    private static final String DEBUG_INPUT_PARAMS = 'INPUT PARAMETERS DEBUG';
    private static final String DEBUG_NULL_VALUE = '[NULL]';
    private static final String DEBUG_EMPTY_LIST = '[EMPTY LIST]';
    private static final String DEBUG_LIST_SIZE_PREFIX = '[LIST SIZE: ';
    private static final String DEBUG_LIST_SIZE_SUFFIX = ']';
    
    // ===========================================
    // DISPLAY FORMATTING CONSTANTS
    // ===========================================
    private static final String CONTEXT_HEADER = 'CONTEXTUAL SERVICE REPLIES' + DOUBLE_NEWLINE;
    private static final String GROUNDED_HEADER = 'GROUNDED SERVICE REPLIES' + DOUBLE_NEWLINE;
    private static final String CASE_SUMMARY_HEADER = 'CASE SUMMARY' + DOUBLE_NEWLINE;
    private static final String WORK_SUMMARY_HEADER = 'WORK SUMMARY' + DOUBLE_NEWLINE;
    private static final String RESPONSES_SECTION = 'RESPONSES:' + NEWLINE + '----------' + NEWLINE;
    private static final String SOURCE_INFO_SECTION = NEWLINE + 'Source Information:' + NEWLINE;
    private static final String RESPONSE_DELIMITER = '-----------' + NEWLINE;
    private static final String SEARCH_QUERY_LABEL = 'Search Query: ';
    private static final String RECENT_SPEAKER_LABEL = 'Recent Speaker: ';
    private static final String ISSUE_ADDRESSED_LABEL = 'Issue Addressed by Agent: ';
    private static final String RESPONSE_PREFIX = 'RESPONSE ';
    private static final String TEXT_LABEL = 'Text: ';
    private static final String INTENT_LABEL = 'Intent: ';
    private static final String ARTICLE_RELEVANT_LABEL = 'Article Relevant: ';
    private static final String SNIPPET_IDENTIFIED_LABEL = 'Snippet Identified: ';
    private static final String RECORD_ID_LABEL = '  - Record ID: ';
    private static final String DATA_SOURCE_LABEL = '  - Data Source: ';
    private static final String SNIPPET_RANGE_LABEL = '  - Snippet Range: Words ';
    private static final String TO_SEPARATOR = ' to ';
    
    private final Set<Id> batchIds;
    
    /**
     * @description Constructor for the batch class
     * @param batchIds Set of Prompt Test Batch IDs to process
     */
    public ziip_PromptTestBatch(Set<Id> batchIds) {
        this.batchIds = batchIds;
    }
    
    /**
     * @description Start method for the batch job
     * @param bc Database.BatchableContext
     * @return Database.QueryLocator for pending prompt tests
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Prompt_Test_Batch__c, Messaging_Session__c, Case__c, Voice_Call__c, Status__c, 
                   Transcript__c, Primary_Result__c, Secondary_Result__c,
                   Primary_Resolved_Prompt__c, Secondary_Resolved_Prompt__c,
                   Customer_Utterance__c, Utterance_Sequence__c,
                   Prompt_Test_Batch__r.Test_Type__c,
                   Prompt_Test_Batch__r.Primary_Template_Id__c,
                   Prompt_Test_Batch__r.Secondary_Template_Id__c,
                   Prompt_Test_Batch__r.Retriever_Id__c
            FROM Prompt_Test__c 
            WHERE Prompt_Test_Batch__c IN :batchIds
            AND Status__c = :STATUS_PENDING
        ]);
    }
    
    /**
     * @description Execute method for processing each batch of Prompt Tests
     * @param bc Database.BatchableContext
     * @param scope List of Prompt_Test__c records to process
     */
    public void execute(Database.BatchableContext bc, List<Prompt_Test__c> scope) {
        List<Prompt_Test__c> testsToUpdate = new List<Prompt_Test__c>();
        
        for (Prompt_Test__c test : scope) {
            try {
                if (!validateTemplateConfiguration(test)) {
                    setTestFailed(test, ERROR_TEMPLATE_IDS_NOT_CONFIGURED);
                    testsToUpdate.add(test);
                    continue;
                }
                
                processPromptTest(test);
                test.Status__c = STATUS_COMPLETED;
                
            } catch (Exception e) {
                System.debug(ERROR_PROCESSING_PROMPT_TEST + test.Id + ' - ' + e.getMessage());
                setTestFailed(test, e.getMessage());
            }
            
            testsToUpdate.add(test);
        }
        
        updateTestRecords(testsToUpdate);
    }
    
    /**
     * @description Finish method called after all batches are processed
     * @param bc Database.BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        updateBatchStatus();
    }
    
    // ===========================================
    // CORE PROCESSING METHODS
    // ===========================================
    
    /**
     * @description Main dispatcher method that routes processing based on test type
     * @param test Prompt_Test__c record to process
     */
    private void processPromptTest(Prompt_Test__c test) {
        test.Status__c = STATUS_IN_PROGRESS;
        String testType = getTestType(test);
        
        System.debug('Processing test type: ' + testType + ' for test ID: ' + test.Id);
        
        switch on testType {
            when 'Service Replies' {
                processServiceRepliesTest(test);
            }
            when 'Case Summary' {
                processCaseSummaryTest(test);
            }
            when 'Work Summary' {
                processWorkSummaryTest(test);
            }
            when else {
                // Backwards compatibility for null test types (assume Service Replies)
                processServiceRepliesTest(test);
            }
        }
    }
    
    /**
     * @description Gets the test type, providing backwards compatibility
     * @param test Prompt_Test__c record
     * @return String test type
     */
    private String getTestType(Prompt_Test__c test) {
        String testType = test.Prompt_Test_Batch__r.Test_Type__c;
        return String.isNotBlank(testType) ? testType : TEST_TYPE_SERVICE_REPLIES;
    }
    
    /**
     * @description Processes Service Replies tests (contextual + grounded templates)
     * @param test Prompt_Test__c record to process
     */
    private void processServiceRepliesTest(Prompt_Test__c test) {
        System.debug('Processing Service Replies test');
        
        String transcript = getMessagingSessionTranscript(test);
        
        // Execute primary (contextual) template
        String primaryTemplateId = getPrimaryTemplateId(test);
        if (String.isNotBlank(primaryTemplateId)) {
            PromptExecutionResult contextResult = executePromptTemplate(
                primaryTemplateId,
                test,
                transcript,
                null,
                null,
                TEMPLATE_TYPE_CONTEXTUAL
            );
            
            test.Primary_Result__c = formatServiceRepliesResult(contextResult.resultText, TEMPLATE_TYPE_CONTEXTUAL);
            test.Primary_Resolved_Prompt__c = contextResult.resolvedPrompt;
            
            // Extract search query for grounded template
            String searchQuery = extractSearchQueryFromResult(contextResult.resultText);
            
            // Execute secondary (grounded) template if configured and search query is valid
            String secondaryTemplateId = getSecondaryTemplateId(test);
            if (String.isNotBlank(secondaryTemplateId) && isValidSearchQuery(searchQuery)) {
                PromptExecutionResult groundedResult = executePromptTemplate(
                    secondaryTemplateId,
                    test,
                    transcript,
                    searchQuery,
                    getRetrieverId(test),
                    TEMPLATE_TYPE_GROUNDED
                );
                
                test.Secondary_Result__c = formatServiceRepliesResult(groundedResult.resultText, TEMPLATE_TYPE_GROUNDED);
                test.Secondary_Resolved_Prompt__c = groundedResult.resolvedPrompt;
            } else {
                String skipReason = buildGroundedSkipMessage(searchQuery);
                test.Secondary_Result__c = skipReason;
            }
        }
    }
    
    /**
     * @description Processes Case Summary tests (single template)
     * @param test Prompt_Test__c record to process
     */
    private void processCaseSummaryTest(Prompt_Test__c test) {
        System.debug('Processing Case Summary test');
        
        String caseContext = getCaseContext(test);
        String primaryTemplateId = getPrimaryTemplateId(test);
        
        if (String.isNotBlank(primaryTemplateId)) {
            PromptExecutionResult result = executePromptTemplate(
                primaryTemplateId,
                test,
                caseContext,
                null,
                null,
                TEMPLATE_TYPE_CASE_SUMMARY
            );
            
            test.Primary_Result__c = formatGenericResult(result.resultText, CASE_SUMMARY_HEADER);
            test.Primary_Resolved_Prompt__c = result.resolvedPrompt;
        }
    }
    
    /**
     * @description Processes Work Summary tests (single template, messaging or voice call)
     * @param test Prompt_Test__c record to process
     */
    private void processWorkSummaryTest(Prompt_Test__c test) {
        System.debug('Processing Work Summary test');
        
        String workContext = getWorkContext(test);
        String primaryTemplateId = getPrimaryTemplateId(test);
        
        if (String.isNotBlank(primaryTemplateId)) {
            PromptExecutionResult result = executePromptTemplate(
                primaryTemplateId,
                test,
                workContext,
                null,
                null,
                TEMPLATE_TYPE_WORK_SUMMARY
            );
            
            test.Primary_Result__c = formatGenericResult(result.resultText, WORK_SUMMARY_HEADER);
            test.Primary_Resolved_Prompt__c = result.resolvedPrompt;
        }
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
            debugInputParameters(templateId, templateType, promptGenerationsInput, contextData, searchQuery, retrieverId);
            
            // Call the service to generate messages
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateId, promptGenerationsInput);
            
            // Debug complete response after API call
            debugConnectApiResponse(generationsOutput, templateId, templateType);
            
            // Extract the generated text and resolved prompt
            if (generationsOutput != null && generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                String resultText = generationsOutput.generations[0].text;
                String resolvedPrompt = generationsOutput.prompt; // This contains the resolved prompt with substituted values
                return new PromptExecutionResult(resultText, resolvedPrompt);
            }
            
            return new PromptExecutionResult(ERROR_NO_RESPONSE_GENERATED, null);
            
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
            when 'contextual', 'grounded' {
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
            when 'case_summary' {
                // Case Summary templates expect caseToSummarize parameter with case reference
                if (test.Case__c != null) {
                    Map<String, String> caseInput = new Map<String, String>();
                    caseInput.put(RECORD_ID_KEY, String.valueOf(test.Case__c));
                    ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
                    caseValue.value = caseInput;
                    inputParams.put(INPUT_CASE_TO_SUMMARIZE, caseValue);
                }
            }
            when 'work_summary' {
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
        if (templateType == 'grounded' && String.isNotBlank(retrieverId)) {
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
     * @description Gets primary template ID
     * @param test Prompt_Test__c record
     * @return String primary template ID
     */
    private String getPrimaryTemplateId(Prompt_Test__c test) {
        return test.Prompt_Test_Batch__r.Primary_Template_Id__c;
    }
    
    /**
     * @description Gets secondary template ID
     * @param test Prompt_Test__c record
     * @return String secondary template ID
     */
    private String getSecondaryTemplateId(Prompt_Test__c test) {
        return test.Prompt_Test_Batch__r.Secondary_Template_Id__c;
    }
    
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
     * @description Validates template configuration based on test type
     * @param test Prompt_Test__c record to validate
     * @return Boolean indicating if templates are properly configured
     */
    private Boolean validateTemplateConfiguration(Prompt_Test__c test) {
        String testType = getTestType(test);
        String primaryTemplateId = getPrimaryTemplateId(test);
        
        // Primary template is always required
        if (String.isBlank(primaryTemplateId)) {
            return false;
        }
        
        // For Service Replies, both primary and secondary templates are required
        if (testType == TEST_TYPE_SERVICE_REPLIES) {
            String secondaryTemplateId = getSecondaryTemplateId(test);
            return String.isNotBlank(secondaryTemplateId);
        }
        
        // For other test types, only primary template is required
        return true;
    }
    
    /**
     * @description Sets a test record to failed status with error message
     * @param test Prompt_Test__c record to mark as failed
     * @param errorMessage Error message to set
     */
    private void setTestFailed(Prompt_Test__c test, String errorMessage) {
        test.Status__c = STATUS_FAILED;
        test.Result__c = ERROR_PREFIX + errorMessage;
        test.Primary_Result__c = ERROR_PREFIX + errorMessage;
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
    
    // ===========================================
    // RESULT FORMATTING METHODS
    // ===========================================
    
    /**
     * @description Formats Service Replies results (contextual or grounded)
     * @param rawResult Raw JSON result from template
     * @param templateType Type of template ('contextual' or 'grounded')
     * @return String formatted result
     */
    private String formatServiceRepliesResult(String rawResult, String templateType) {
        if (templateType == 'contextual') {
            return formatContextResult(rawResult);
        } else if (templateType == 'grounded') {
            return formatGroundedResult(rawResult);
        }
        return rawResult;
    }
    
    /**
     * @description Formats generic results for Case Summary and Work Summary
     * @param rawResult Raw result from template
     * @param header Header to prepend to result
     * @return String formatted result
     */
    private String formatGenericResult(String rawResult, String header) {
        if (String.isBlank(rawResult)) {
            return ERROR_NO_RESULT;
        }
        return header + rawResult;
    }
    
    /**
     * @description Formats the context template result for display
     * @param contextResult Raw JSON result from context template
     * @return String formatted result
     */
    private String formatContextResult(String contextResult) {
        try {
            if (String.isBlank(contextResult)) {
                return ERROR_NO_RESULT;
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(contextResult);
            String formatted = CONTEXT_HEADER;
            
            // Extract key fields using constants
            if (resultMap.containsKey(JSON_SEARCH_QUERY)) {
                formatted += SEARCH_QUERY_LABEL + String.valueOf(resultMap.get(JSON_SEARCH_QUERY)) + NEWLINE;
            }
            
            if (resultMap.containsKey(JSON_RECENT_SPEAKER)) {
                formatted += RECENT_SPEAKER_LABEL + String.valueOf(resultMap.get(JSON_RECENT_SPEAKER)) + NEWLINE;
            }
            
            if (resultMap.containsKey(JSON_ISSUE_ADDRESSED)) {
                formatted += ISSUE_ADDRESSED_LABEL + String.valueOf(resultMap.get(JSON_ISSUE_ADDRESSED)) + DOUBLE_NEWLINE;
            }
            
            // Extract responses
            if (resultMap.containsKey(JSON_RESPONSES) && resultMap.get(JSON_RESPONSES) instanceof List<Object>) {
                List<Object> responses = (List<Object>) resultMap.get(JSON_RESPONSES);
                formatted += RESPONSES_SECTION;
                
                Integer responseCount = RESPONSE_COUNTER_START;
                for (Object responseObj : responses) {
                    if (responseObj instanceof Map<String, Object>) {
                        Map<String, Object> response = (Map<String, Object>) responseObj;
                        formatted += responseCount + '. ';
                        if (response.containsKey(JSON_RESPONSE)) {
                            formatted += String.valueOf(response.get(JSON_RESPONSE));
                        }
                        formatted += DOUBLE_NEWLINE;
                        responseCount++;
                    }
                }
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug(ERROR_FORMATTING_RESULT + e.getMessage());
            return ERROR_FORMATTING_RESULT + e.getMessage() + RAW_RESULT_PREFIX + contextResult;
        }
    }
    
    /**
     * @description Formats the grounded template result for display
     * @param groundedResult Raw JSON result from grounded template
     * @return String formatted result
     */
    private String formatGroundedResult(String groundedResult) {
        try {
            if (String.isBlank(groundedResult)) {
                return ERROR_NO_RESULT;
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(groundedResult);
            String formatted = GROUNDED_HEADER;
            
            // Extract responses using constants
            if (resultMap.containsKey(JSON_RESPONSES) && resultMap.get(JSON_RESPONSES) instanceof List<Object>) {
                List<Object> responses = (List<Object>) resultMap.get(JSON_RESPONSES);
                
                Integer responseCount = RESPONSE_COUNTER_START;
                for (Object responseObj : responses) {
                    if (responseObj instanceof Map<String, Object>) {
                        Map<String, Object> response = (Map<String, Object>) responseObj;
                        
                        formatted += RESPONSE_PREFIX + responseCount + ':' + NEWLINE;
                        formatted += RESPONSE_DELIMITER;
                        
                        if (response.containsKey(JSON_RESPONSE)) {
                            formatted += TEXT_LABEL + String.valueOf(response.get(JSON_RESPONSE)) + NEWLINE;
                        }
                        
                        if (response.containsKey(JSON_INTENT)) {
                            formatted += INTENT_LABEL + String.valueOf(response.get(JSON_INTENT)) + NEWLINE;
                        }
                        
                        if (response.containsKey(JSON_ARTICLE_RELEVANT)) {
                            formatted += ARTICLE_RELEVANT_LABEL + String.valueOf(response.get(JSON_ARTICLE_RELEVANT)) + NEWLINE;
                        }
                        
                        if (response.containsKey(JSON_SNIPPET_IDENTIFIED)) {
                            formatted += SNIPPET_IDENTIFIED_LABEL + String.valueOf(response.get(JSON_SNIPPET_IDENTIFIED)) + NEWLINE;
                        }
                        
                        // Extract source information using constants
                        if (response.containsKey(JSON_SOURCE) && response.get(JSON_SOURCE) instanceof Map<String, Object>) {
                            Map<String, Object> source = (Map<String, Object>) response.get(JSON_SOURCE);
                            formatted += SOURCE_INFO_SECTION;
                            
                            if (source.containsKey(JSON_SOURCE_RECORD_ID)) {
                                formatted += RECORD_ID_LABEL + String.valueOf(source.get(JSON_SOURCE_RECORD_ID)) + NEWLINE;
                            }
                            
                            if (source.containsKey(JSON_DATA_SOURCE_OBJECT)) {
                                formatted += DATA_SOURCE_LABEL + String.valueOf(source.get(JSON_DATA_SOURCE_OBJECT)) + NEWLINE;
                            }
                            
                            if (source.containsKey(JSON_SNIPPET_START) && source.containsKey(JSON_SNIPPET_END)) {
                                formatted += SNIPPET_RANGE_LABEL;
                                formatted += String.valueOf(source.get(JSON_SNIPPET_START));
                                formatted += TO_SEPARATOR;
                                formatted += String.valueOf(source.get(JSON_SNIPPET_END));
                                formatted += NEWLINE;
                            }
                        }
                        
                        formatted += NEWLINE;
                        responseCount++;
                    }
                }
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug(ERROR_FORMATTING_RESULT + e.getMessage());
            return ERROR_FORMATTING_RESULT + e.getMessage() + RAW_RESULT_PREFIX + groundedResult;
        }
    }
    
    // ===========================================
    // DEBUG METHODS
    // ===========================================
    
    /**
     * @description Logs input parameters before calling ConnectApi
     * @param templateId Template ID being called
     * @param templateType Type of template
     * @param promptInput Input parameters object
     * @param contextData Context data being sent
     * @param searchQuery Search query (if applicable)
     * @param retrieverId Retriever ID (if applicable)
     */
    private void debugInputParameters(String templateId, String templateType, ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput, String contextData, String searchQuery, String retrieverId) {
        System.debug(DEBUG_SEPARATOR);
        System.debug(DEBUG_INPUT_PARAMS);
        System.debug(DEBUG_SEPARATOR);
        System.debug('Template ID: ' + (templateId ?? DEBUG_NULL_VALUE));
        System.debug('Template Type: ' + (templateType ?? DEBUG_NULL_VALUE));
        System.debug('Timestamp: ' + System.now());
        System.debug(DEBUG_SECTION_SEPARATOR);
        
        // Log additional configuration
        if (promptInput.additionalConfig != null) {
            System.debug('Additional Config:');
            System.debug('  - Number of Generations: ' + promptInput.additionalConfig.numGenerations);
            System.debug('  - Enable PII Masking: ' + promptInput.additionalConfig.enablePiiMasking);
            System.debug('  - Application Name: ' + (promptInput.additionalConfig.applicationName ?? DEBUG_NULL_VALUE));
        }
        System.debug('Is Preview: ' + promptInput.isPreview);
        System.debug(DEBUG_SECTION_SEPARATOR);
        
        // Log input parameters
        System.debug('Input Parameters:');
        if (promptInput.inputParams != null && !promptInput.inputParams.isEmpty()) {
            for (String key : promptInput.inputParams.keySet()) {
                ConnectApi.WrappedValue wrappedValue = promptInput.inputParams.get(key);
                if (wrappedValue != null && wrappedValue.value != null) {
                    System.debug('  - ' + key + ': ' + JSON.serializePretty(wrappedValue.value));
                } else {
                    System.debug('  - ' + key + ': ' + DEBUG_NULL_VALUE);
                }
            }
        } else {
            System.debug('  ' + DEBUG_EMPTY_LIST);
        }
        
        System.debug(DEBUG_SECTION_SEPARATOR);
        System.debug('Context Data Length: ' + (contextData != null ? String.valueOf(contextData.length()) : '0'));
        System.debug('Search Query: ' + (searchQuery ?? DEBUG_NULL_VALUE));
        System.debug('Retriever ID: ' + (retrieverId ?? DEBUG_NULL_VALUE));
        System.debug(DEBUG_SEPARATOR);
    }
    
    /**
     * @description Logs complete ConnectApi response with all available attributes
     * @param generationsOutput Response from ConnectApi call
     * @param templateId Template ID that was called
     * @param templateType Type of template that was called
     */
    private void debugConnectApiResponse(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput, String templateId, String templateType) {
        System.debug(DEBUG_SEPARATOR);
        System.debug(DEBUG_CONNECTAPI_START);
        System.debug(DEBUG_SEPARATOR);
        System.debug('Template ID: ' + (templateId ?? DEBUG_NULL_VALUE));
        System.debug('Template Type: ' + (templateType ?? DEBUG_NULL_VALUE));
        System.debug('Response Timestamp: ' + System.now());
        System.debug(DEBUG_SECTION_SEPARATOR);
        
        if (generationsOutput == null) {
            System.debug('ERROR: generationsOutput is null');
            System.debug(DEBUG_SEPARATOR);
            return;
        }
        
        // Core response properties
        debugCoreProperties(generationsOutput);
        
        // Parameters
        debugParameters(generationsOutput.parameters);
        
        // Messages
        debugRequestMessages(generationsOutput.requestMessages);
        debugResponseMessages(generationsOutput.responseMessages);
        debugSlotsMaskingInformation(generationsOutput.slotsMaskingInformation);
        
        // Generations and errors
        debugGenerations(generationsOutput.generations);
        debugGenerationErrors(generationsOutput.generationErrors);
        
        // Citations
        debugCitations(generationsOutput.citations);
        
        // Note: fileData property not available until API version 63.0
        
        System.debug(DEBUG_SEPARATOR);
        System.debug(DEBUG_CONNECTAPI_END);
        System.debug(DEBUG_SEPARATOR);
    }
    
    /**
     * @description Debugs core properties of the response
     * @param generationsOutput Response object
     */
    private void debugCoreProperties(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput) {
        System.debug('CORE PROPERTIES:');
        System.debug('Request ID: ' + (generationsOutput.requestId ?? DEBUG_NULL_VALUE));
        System.debug('Prompt Template Dev Name: ' + (generationsOutput.promptTemplateDevName ?? DEBUG_NULL_VALUE));
        System.debug('Is Summarized: ' + (generationsOutput.isSummarized != null ? String.valueOf(generationsOutput.isSummarized) : DEBUG_NULL_VALUE));
        
        if (String.isNotBlank(generationsOutput.prompt)) {
            System.debug('Resolved Prompt Length: ' + generationsOutput.prompt.length());
            System.debug('Resolved Prompt: ' + generationsOutput.prompt);
        } else {
            System.debug('Resolved Prompt: ' + DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs parameters object
     * @param parameters Parameters object
     */
    private void debugParameters(ConnectApi.WrappedMapObject parameters) {
        System.debug('PARAMETERS:');
        if (parameters != null) {
            try {
                String parametersJson = JSON.serializePretty(parameters);
                System.debug(parametersJson);
            } catch (Exception e) {
                System.debug('Error serializing parameters: ' + e.getMessage());
            }
        } else {
            System.debug(DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs request messages
     * @param requestMessages List of request messages
     */
    private void debugRequestMessages(Object requestMessages) {
        System.debug('REQUEST MESSAGES:');
        if (requestMessages != null) {
            try {
                String messageJson = JSON.serializePretty(requestMessages);
                System.debug(messageJson);
            } catch (Exception e) {
                System.debug('Error serializing request messages: ' + e.getMessage());
                System.debug('Request Messages (toString): ' + String.valueOf(requestMessages));
            }
        } else {
            System.debug(DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs response messages
     * @param responseMessages List of response messages
     */
    private void debugResponseMessages(Object responseMessages) {
        System.debug('RESPONSE MESSAGES:');
        if (responseMessages != null) {
            try {
                String messageJson = JSON.serializePretty(responseMessages);
                System.debug(messageJson);
            } catch (Exception e) {
                System.debug('Error serializing response messages: ' + e.getMessage());
                System.debug('Response Messages (toString): ' + String.valueOf(responseMessages));
            }
        } else {
            System.debug(DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs slots masking information
     * @param slotsMaskingInfo List of masking information
     */
    private void debugSlotsMaskingInformation(Object slotsMaskingInfo) {
        System.debug('SLOTS MASKING INFORMATION:');
        if (slotsMaskingInfo != null) {
            try {
                String maskDataJson = JSON.serializePretty(slotsMaskingInfo);
                System.debug(maskDataJson);
            } catch (Exception e) {
                System.debug('Error serializing slots masking information: ' + e.getMessage());
                System.debug('Slots Masking Info (toString): ' + String.valueOf(slotsMaskingInfo));
            }
        } else {
            System.debug(DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs generations list
     * @param generations List of generation items
     */
    private void debugGenerations(List<ConnectApi.EinsteinLlmGenerationItemOutput> generations) {
        System.debug('GENERATIONS:');
        if (generations != null && !generations.isEmpty()) {
            System.debug(DEBUG_LIST_SIZE_PREFIX + generations.size() + DEBUG_LIST_SIZE_SUFFIX);
            for (Integer i = 0; i < generations.size(); i++) {
                ConnectApi.EinsteinLlmGenerationItemOutput generation = generations[i];
                System.debug('Generation ' + (i + 1) + ':');
                if (generation != null) {
                    System.debug('  Text Length: ' + (generation.text != null ? String.valueOf(generation.text.length()) : '0'));
                    System.debug('  Text: ' + (generation.text ?? DEBUG_NULL_VALUE));
                    
                    // Parameters (if available)
                    if (generation.parameters != null) {
                        try {
                            String parametersJson = JSON.serializePretty(generation.parameters);
                            System.debug('  Parameters: ' + parametersJson);
                        } catch (Exception e) {
                            System.debug('  Parameters: Error serializing - ' + e.getMessage());
                        }
                    } else {
                        System.debug('  Parameters: ' + DEBUG_NULL_VALUE);
                    }
                    
                    // Try to serialize the entire generation object to see all available properties
                    try {
                        String fullGenerationJson = JSON.serializePretty(generation);
                        System.debug('  Full Generation Object: ' + fullGenerationJson);
                    } catch (Exception e) {
                        System.debug('  Full Generation Object: Error serializing - ' + e.getMessage());
                        System.debug('  Generation toString: ' + String.valueOf(generation));
                    }
                } else {
                    System.debug('  ' + DEBUG_NULL_VALUE);
                }
            }
        } else {
            System.debug(generations == null ? DEBUG_NULL_VALUE : DEBUG_EMPTY_LIST);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs generation errors
     * @param generationErrors List of generation errors
     */
    private void debugGenerationErrors(List<ConnectApi.EinsteinPromptTemplateGenerationsError> generationErrors) {
        System.debug('GENERATION ERRORS:');
        if (generationErrors != null && !generationErrors.isEmpty()) {
            System.debug(DEBUG_LIST_SIZE_PREFIX + generationErrors.size() + DEBUG_LIST_SIZE_SUFFIX);
            for (Integer i = 0; i < generationErrors.size(); i++) {
                ConnectApi.EinsteinPromptTemplateGenerationsError error = generationErrors[i];
                System.debug('Error ' + (i + 1) + ':');
                if (error != null) {
                    try {
                        String errorJson = JSON.serializePretty(error);
                        System.debug(errorJson);
                    } catch (Exception e) {
                        System.debug('  Error serializing generation error: ' + e.getMessage());
                    }
                } else {
                    System.debug('  ' + DEBUG_NULL_VALUE);
                }
            }
        } else {
            System.debug(generationErrors == null ? DEBUG_NULL_VALUE : DEBUG_EMPTY_LIST);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs citations
     * @param citations Citations object
     */
    private void debugCitations(ConnectApi.EinsteinLlmGenerationCitationOutput citations) {
        System.debug('CITATIONS:');
        if (citations != null) {
            try {
                String citationsJson = JSON.serializePretty(citations);
                System.debug(citationsJson);
            } catch (Exception e) {
                System.debug('Error serializing citations: ' + e.getMessage());
            }
        } else {
            System.debug(DEBUG_NULL_VALUE);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
    
    /**
     * @description Debugs file data
     * @param fileData List of file data
     */
    private void debugFileData(List<ConnectApi.EinsteinPromptTemplateAttachment> fileData) {
        System.debug('FILE DATA:');
        if (fileData != null && !fileData.isEmpty()) {
            System.debug(DEBUG_LIST_SIZE_PREFIX + fileData.size() + DEBUG_LIST_SIZE_SUFFIX);
            for (Integer i = 0; i < fileData.size(); i++) {
                ConnectApi.EinsteinPromptTemplateAttachment attachment = fileData[i];
                System.debug('File ' + (i + 1) + ':');
                if (attachment != null) {
                    try {
                        String attachmentJson = JSON.serializePretty(attachment);
                        System.debug(attachmentJson);
                    } catch (Exception e) {
                        System.debug('  Error serializing file attachment: ' + e.getMessage());
                    }
                } else {
                    System.debug('  ' + DEBUG_NULL_VALUE);
                }
            }
        } else {
            System.debug(fileData == null ? DEBUG_NULL_VALUE : DEBUG_EMPTY_LIST);
        }
        System.debug(DEBUG_SECTION_SEPARATOR);
    }
}
