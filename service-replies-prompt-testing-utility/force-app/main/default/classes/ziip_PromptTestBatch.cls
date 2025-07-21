/**
 * @description Batch class for processing Prompt Tests with Einstein AI templates
 * @author Ziipline
 */
public class ziip_PromptTestBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    // ===========================================
    // STATUS CONSTANTS
    // ===========================================
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_IN_PROGRESS = 'In Progress';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_FAILED = 'Failed';
    
    // ===========================================
    // EINSTEIN AI INPUT PARAMETER CONSTANTS
    // ===========================================
    private static final String INPUT_CONVERSATION_TRANSCRIPT = 'Input:conversation_transcript';
    private static final String INPUT_RETRIEVER_ID_OR_NAME = 'Input:RetrieverIdOrName';
    private static final String INPUT_SEARCH_QUERY = 'Input:search_query';
    private static final String INPUT_MESSAGING_SESSION = 'Input:MessagingSession';
    
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
    private static final String DEFAULT_RETRIEVER_ID = '1CxHn0000008OeMKAU';
    private static final String INVALID_SEARCH_QUERY_VALUE = 'none';
    private static final String MESSAGING_SESSION_ID_KEY = 'id';
    
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
    private static final String ERROR_TEMPLATE_IDS_NOT_CONFIGURED = 'Template IDs not configured. Please set Context Template ID and Grounded Template ID on the batch.';
    private static final String ERROR_BLANK_TEMPLATE_ID = 'Template ID cannot be blank';
    private static final String ERROR_NO_RESPONSE_GENERATED = 'No response generated from prompt template';
    private static final String ERROR_NO_CONTEXT_RESULT = 'No context result returned';
    private static final String ERROR_NO_GROUNDED_RESULT = 'No grounded result returned';
    private static final String ERROR_FORMATTING_RESULT = 'Error formatting result: ';
    private static final String ERROR_PROCESSING_PROMPT_TEST = 'Error processing Prompt_Test__c: ';
    private static final String ERROR_EXECUTING_PROMPT = 'Failed to execute Einstein prompt (Template ID: ';
    private static final String ERROR_GETTING_TRANSCRIPT = 'Error getting transcript: ';
    private static final String ERROR_PARSING_JSON = 'Error parsing context result JSON: ';
    private static final String ERROR_UPDATING_RECORDS = 'Error updating test records: ';
    private static final String ERROR_UPDATING_BATCH_STATUS = 'Error updating batch status: ';
    
    // ===========================================
    // DISPLAY FORMATTING CONSTANTS
    // ===========================================
    private static final String CONTEXT_HEADER = 'CONTEXTUAL SERVICE REPLIES' + DOUBLE_NEWLINE;
    private static final String GROUNDED_HEADER = 'GROUNDED SERVICE REPLIES' + DOUBLE_NEWLINE;
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
            SELECT Id, Prompt_Test_Batch__c, Messaging_Session__c, Status__c, 
                   Transcript__c, Contextual_Service_Replies_Result__c, Grounded_Service_Replies_Result__c,
                   Customer_Utterance__c, Utterance_Sequence__c,
                   Prompt_Test_Batch__r.Context_Template_Id__c, 
                   Prompt_Test_Batch__r.Grounded_Template_Id__c,
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
    
    // PRIVATE HELPER METHODS
    
    /**
     * @description Validates that both template IDs are configured on the batch
     * @param test Prompt_Test__c record to validate
     * @return Boolean indicating if templates are properly configured
     */
    private Boolean validateTemplateConfiguration(Prompt_Test__c test) {
        return String.isNotBlank(test.Prompt_Test_Batch__r.Context_Template_Id__c) && 
               String.isNotBlank(test.Prompt_Test_Batch__r.Grounded_Template_Id__c);
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
     * @description Processes a single prompt test through both context and grounded templates
     * @param test Prompt_Test__c record to process
     */
    private void processPromptTest(Prompt_Test__c test) {
        test.Status__c = STATUS_IN_PROGRESS;
        
        String transcript = getOrRetrieveTranscript(test);
        String searchQuery = processContextTemplate(test, transcript);
        processGroundedTemplate(test, transcript, searchQuery);
    }
    
    /**
     * @description Gets existing transcript or retrieves it from messaging session
     * @param test Prompt_Test__c record containing transcript and session info
     * @return String transcript content
     */
    private String getOrRetrieveTranscript(Prompt_Test__c test) {
        String transcript = test.Transcript__c;
        if (String.isBlank(transcript) && test.Messaging_Session__c != null) {
            transcript = getTranscriptFromSession(test.Messaging_Session__c);
            test.Transcript__c = transcript;
        }
        return transcript;
    }
    
    /**
     * @description Processes the context template and extracts search query
     * @param test Prompt_Test__c record to process
     * @param transcript Conversation transcript
     * @return String extracted search query for grounded template
     */
    private String processContextTemplate(Prompt_Test__c test, String transcript) {
        String searchQuery = '';
        
        if (String.isNotBlank(test.Prompt_Test_Batch__r.Context_Template_Id__c)) {
            String contextResult = executeEinsteinPrompt(
                test.Prompt_Test_Batch__r.Context_Template_Id__c,
                transcript,
                null,
                test.Messaging_Session__c,
                null
            );
            
            test.Contextual_Service_Replies_Result__c = formatContextResult(contextResult);
            searchQuery = extractSearchQueryFromContextResult(contextResult);
        }
        
        return searchQuery;
    }
    
    /**
     * @description Processes the grounded template with search query
     * Only executes if context template returned a valid search query (not blank and not 'none')
     * @param test Prompt_Test__c record to process
     * @param transcript Conversation transcript
     * @param searchQuery Search query extracted from context template
     */
    private void processGroundedTemplate(Prompt_Test__c test, String transcript, String searchQuery) {
        if (String.isNotBlank(test.Prompt_Test_Batch__r.Grounded_Template_Id__c)) {
            if (isValidSearchQuery(searchQuery)) {
                // Use retriever ID from batch record or fallback to default
                String retrieverId = String.isNotBlank(test.Prompt_Test_Batch__r.Retriever_Id__c) 
                    ? test.Prompt_Test_Batch__r.Retriever_Id__c 
                    : DEFAULT_RETRIEVER_ID;
                    
                String groundedResult = executeEinsteinPrompt(
                    test.Prompt_Test_Batch__r.Grounded_Template_Id__c,
                    transcript,
                    searchQuery,
                    test.Messaging_Session__c,
                    retrieverId
                );
                
                test.Grounded_Service_Replies_Result__c = formatGroundedResult(groundedResult);
                System.debug('Grounded template processed with search query: ' + searchQuery);
            } else {
                String skipReason = String.isBlank(searchQuery) ? 'empty/blank' : '"' + searchQuery + '"';
                test.Grounded_Service_Replies_Result__c = buildGroundedSkipMessage(skipReason);
                System.debug('Grounded template skipped: Context template returned ' + skipReason + ' search query');
            }
        }
    }
    
    /**
     * @description Validates if a search query is valid for grounded template processing
     * @param searchQuery Search query to validate
     * @return Boolean indicating if search query is valid (not blank and not 'none')
     */
    private Boolean isValidSearchQuery(String searchQuery) {
        return String.isNotBlank(searchQuery) && 
               !searchQuery.equalsIgnoreCase(INVALID_SEARCH_QUERY_VALUE);
    }
    
    /**
     * @description Builds a skip message for grounded template processing
     * @param skipReason Reason why the grounded template was skipped
     * @return String formatted skip message
     */
    private String buildGroundedSkipMessage(String skipReason) {
        return 'Grounded template skipped: Context template returned no valid search query (result was ' + skipReason + ')';
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
     * @description Formats the context template result for display
     * @param contextResult Raw JSON result from context template
     * @return String formatted result
     */
    private String formatContextResult(String contextResult) {
        try {
            if (String.isBlank(contextResult)) {
                return ERROR_NO_CONTEXT_RESULT;
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(contextResult);
            String formatted = CONTEXT_HEADER;
            
            // Extract key fields using constants
            if (resultMap.containsKey(JSON_SEARCH_QUERY)) {
                formatted += 'Search Query: ' + String.valueOf(resultMap.get(JSON_SEARCH_QUERY)) + '\n';
            }
            
            if (resultMap.containsKey(JSON_RECENT_SPEAKER)) {
                formatted += 'Recent Speaker: ' + String.valueOf(resultMap.get(JSON_RECENT_SPEAKER)) + '\n';
            }
            
            if (resultMap.containsKey(JSON_ISSUE_ADDRESSED)) {
                formatted += 'Issue Addressed by Agent: ' + String.valueOf(resultMap.get(JSON_ISSUE_ADDRESSED)) + '\n\n';
            }
            
            // Extract responses
            if (resultMap.containsKey(JSON_RESPONSES) && resultMap.get(JSON_RESPONSES) instanceof List<Object>) {
                List<Object> responses = (List<Object>) resultMap.get(JSON_RESPONSES);
                formatted += RESPONSES_SECTION;
                
                Integer responseCount = 1;
                for (Object responseObj : responses) {
                    if (responseObj instanceof Map<String, Object>) {
                        Map<String, Object> response = (Map<String, Object>) responseObj;
                        formatted += responseCount + '. ';
                        if (response.containsKey(JSON_RESPONSE)) {
                            formatted += String.valueOf(response.get(JSON_RESPONSE));
                        }
                        formatted += '\n\n';
                        responseCount++;
                    }
                }
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug(ERROR_FORMATTING_RESULT + e.getMessage());
            return ERROR_FORMATTING_RESULT + e.getMessage() + '\n\nRaw Result:\n' + contextResult;
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
                return ERROR_NO_GROUNDED_RESULT;
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(groundedResult);
            String formatted = GROUNDED_HEADER;
            
            // Extract responses using constants
            if (resultMap.containsKey(JSON_RESPONSES) && resultMap.get(JSON_RESPONSES) instanceof List<Object>) {
                List<Object> responses = (List<Object>) resultMap.get(JSON_RESPONSES);
                
                Integer responseCount = 1;
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
            return ERROR_FORMATTING_RESULT + e.getMessage() + '\n\nRaw Result:\n' + groundedResult;
        }
    }
    
    /**
     * @description Extracts search query from context template result
     * @param contextResult Raw JSON result from context template
     * @return String search query for use in grounded template (preserves 'none' value)
     */
    private String extractSearchQueryFromContextResult(String contextResult) {
        try {
            if (String.isBlank(contextResult)) {
                return '';
            }
            
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(contextResult);
            
            // Extract the search_query field using constant
            if (resultMap.containsKey(JSON_SEARCH_QUERY)) {
                String searchQuery = String.valueOf(resultMap.get(JSON_SEARCH_QUERY));
                
                // Return the actual search query value including 'none'
                // The calling method will decide how to handle it
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
            System.debug(ERROR_GETTING_TRANSCRIPT + e.getMessage());
        }
        return '';
    }
    
    /**
     * @description Executes Einstein prompt template with provided parameters
     * @param templateId Einstein prompt template ID
     * @param transcript Conversation transcript
     * @param searchQuery Search query for grounded templates
     * @param sessionId Messaging session ID
     * @param retrieverId Retriever ID for grounded templates
     * @return String response from Einstein prompt template
     */
    private String executeEinsteinPrompt(String templateId, String transcript, String searchQuery, Id sessionId, String retrieverId) {
        try {
            // Debug inputs
            System.debug('Template ID: ' + templateId);
            System.debug('Transcript: ' + transcript);
            System.debug('Search Query: ' + searchQuery);
            System.debug('Session ID: ' + sessionId);
            System.debug('Retriever ID: ' + retrieverId);

            // Validate template ID is not empty
            if (String.isBlank(templateId)) {
                throw new IllegalArgumentException(ERROR_BLANK_TEMPLATE_ID);
            }
            
            // Prepare input for generating prompt template
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptGenerationsInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            
            // Set conversation transcript input using constant
            ConnectApi.WrappedValue transcriptInputValue = new ConnectApi.WrappedValue();
            transcriptInputValue.value = transcript;
            inputParams.put(INPUT_CONVERSATION_TRANSCRIPT, transcriptInputValue);

            // Set retriever and search query for grounded templates
            if (String.isNotBlank(retrieverId)) {
                ConnectApi.WrappedValue retrieverIdOrNameValue = new ConnectApi.WrappedValue();
                retrieverIdOrNameValue.value = retrieverId;
                inputParams.put(INPUT_RETRIEVER_ID_OR_NAME, retrieverIdOrNameValue);
                System.debug(INPUT_RETRIEVER_ID_OR_NAME + ': ' + retrieverId);
                
                // Add search query (required for grounded template, even if empty)
                ConnectApi.WrappedValue searchQueryInputValue = new ConnectApi.WrappedValue();
                searchQueryInputValue.value = String.isNotBlank(searchQuery) ? searchQuery : '';
                inputParams.put(INPUT_SEARCH_QUERY, searchQueryInputValue);
                System.debug('Search query set: ' + searchQueryInputValue.value);
            }
            
            // Set messaging session input using constant
            Map<String, String> messagingSessionInput = new Map<String, String>();
            messagingSessionInput.put('id', String.valueOf(sessionId));
            ConnectApi.WrappedValue messagingSessionInputValue = new ConnectApi.WrappedValue();
            messagingSessionInputValue.value = messagingSessionInput;
            inputParams.put(INPUT_MESSAGING_SESSION, messagingSessionInputValue);
            
            // Configure prompt generation parameters using constants
            promptGenerationsInput.inputParams = inputParams;
            promptGenerationsInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptGenerationsInput.additionalConfig.numGenerations = NUM_GENERATIONS;
            promptGenerationsInput.additionalConfig.enablePiiMasking = true;
            promptGenerationsInput.additionalConfig.applicationName = APPLICATION_NAME;
            promptGenerationsInput.isPreview = false;
            
            // Call the service to generate messages for the prompt template
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateId, promptGenerationsInput);
            
            // Extract the generated text
            if (generationsOutput != null && generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                return generationsOutput.generations[0].text;
            }
            
            return ERROR_NO_RESPONSE_GENERATED;
            
        } catch (Exception e) {
            String errorMsg = ERROR_EXECUTING_PROMPT + templateId + '): ' + e.getMessage();
            System.debug(errorMsg);
            throw new CalloutException(errorMsg);
        }
    }
}
