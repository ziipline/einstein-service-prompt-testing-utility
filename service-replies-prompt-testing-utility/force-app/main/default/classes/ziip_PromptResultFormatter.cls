/**
 * @description Utility class for formatting AI prompt execution results for display
 * Handles complex JSON parsing and formatting logic for different template types
 */
public class ziip_PromptResultFormatter {
    
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
    private static final String ERROR_NO_RESULT = 'No result returned from template';
    private static final String ERROR_FORMATTING_RESULT = 'Error formatting result: ';
    
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
    
    /**
     * @description Formats result based on template type
     * @param resultText Raw result text from template execution
     * @param templateType Template type for formatting logic
     * @return String formatted result
     */
    public static String formatResult(String resultText, String templateType) {
        switch on templateType {
            when 'Service Reply - Contextual' {
                return formatContextResult(resultText);
            }
            when 'Service Reply - Grounded' {
                return formatGroundedResult(resultText);
            }
            when 'Case Summary' {
                return formatGenericResult(resultText, CASE_SUMMARY_HEADER);
            }
            when 'Work Summary' {
                return formatGenericResult(resultText, WORK_SUMMARY_HEADER);
            }
            when else {
                return resultText;
            }
        }
    }
    
    /**
     * @description Formats generic results for Case Summary and Work Summary
     * @param rawResult Raw result from template
     * @param header Header to prepend to result
     * @return String formatted result
     */
    public static String formatGenericResult(String rawResult, String header) {
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
    public static String formatContextResult(String contextResult) {
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
    public static String formatGroundedResult(String groundedResult) {
        try {
            if (String.isBlank(groundedResult)) {
                return ERROR_NO_RESULT;
            }
            
            // Check if this is a skip message (not JSON)
            if (groundedResult.startsWith('Grounded template skipped:')) {
                return GROUNDED_HEADER + groundedResult + DOUBLE_NEWLINE + 
                       'Note: Grounded service replies require a valid search query from the contextual template. ' +
                       'When the contextual template returns "none" or an empty search query, ' +
                       'the grounded template cannot be executed as it would not have any content to search against.';
            }
            
            String formatted = GROUNDED_HEADER;
            
            // Try to parse as List first (new grounded template structure)
            try {
                List<Object> responses = (List<Object>) JSON.deserializeUntyped(groundedResult);
                return formatGroundedResponseList(responses, formatted);
            } catch (Exception listEx) {
                // If that fails, try the old Map structure
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(groundedResult);
                return formatGroundedResponseMap(resultMap, formatted);
            }
            
        } catch (Exception e) {
            System.debug(ERROR_FORMATTING_RESULT + e.getMessage());
            return ERROR_FORMATTING_RESULT + e.getMessage() + RAW_RESULT_PREFIX + groundedResult;
        }
    }
    
    /**
     * @description Formats grounded results when response is a direct List
     * @param responses List of response objects
     * @param formatted Existing formatted string
     * @return String formatted result
     */
    private static String formatGroundedResponseList(List<Object> responses, String formatted) {
        if (responses != null && !responses.isEmpty()) {
            Integer responseCount = RESPONSE_COUNTER_START;
            for (Object responseObj : responses) {
                if (responseObj instanceof Map<String, Object>) {
                    Map<String, Object> response = (Map<String, Object>) responseObj;
                    
                    formatted += RESPONSE_PREFIX + responseCount + ':' + NEWLINE;
                    formatted += RESPONSE_DELIMITER;
                    
                    // Extract the main result text
                    if (response.containsKey('result')) {
                        formatted += TEXT_LABEL + String.valueOf(response.get('result')) + NEWLINE;
                    }
                    
                    // Extract source information
                    formatted += SOURCE_INFO_SECTION;
                    
                    if (response.containsKey('sourceObjectName')) {
                        formatted += DATA_SOURCE_LABEL + String.valueOf(response.get('sourceObjectName')) + NEWLINE;
                    }
                    
                    if (response.containsKey('fieldApiKey')) {
                        formatted += '  - Field: ' + String.valueOf(response.get('fieldApiKey')) + NEWLINE;
                    }
                    
                    // Extract scores
                    if (response.containsKey('score')) {
                        formatted += '  - Relevance Score: ' + String.valueOf(response.get('score')) + NEWLINE;
                    }
                    
                    if (response.containsKey('vectorSearchScore')) {
                        formatted += '  - Vector Search Score: ' + String.valueOf(response.get('vectorSearchScore')) + NEWLINE;
                    }
                    
                    if (response.containsKey('keywordSearchScore')) {
                        formatted += '  - Keyword Search Score: ' + String.valueOf(response.get('keywordSearchScore')) + NEWLINE;
                    }
                    
                    // Check if there's a nested result array (second structure type)
                    if (response.containsKey('result') && response.get('result') instanceof List<Object>) {
                        List<Object> nestedResults = (List<Object>) response.get('result');
                        for (Object nestedObj : nestedResults) {
                            if (nestedObj instanceof Map<String, Object>) {
                                Map<String, Object> nestedResult = (Map<String, Object>) nestedObj;
                                if (nestedResult.containsKey('value')) {
                                    formatted += '  - Source Content: ' + String.valueOf(nestedResult.get('value')) + NEWLINE;
                                }
                                if (nestedResult.containsKey('fieldName')) {
                                    formatted += '  - Field Name: ' + String.valueOf(nestedResult.get('fieldName')) + NEWLINE;
                                }
                            }
                        }
                    }
                    
                    formatted += NEWLINE;
                    responseCount++;
                }
            }
        }
        return formatted;
    }
    
    /**
     * @description Formats grounded results when response is a Map (old structure)
     * @param resultMap Map containing responses
     * @param formatted Existing formatted string
     * @return String formatted result
     */
    private static String formatGroundedResponseMap(Map<String, Object> resultMap, String formatted) {
        // Extract responses using constants (old structure)
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
    }
}
