/**
 * @description Centralised debug logging utility for batch operations
 * Handles extensive debugging for Einstein AI API calls and batch processing
 */
public class ziip_BatchProcessingLogger {
    
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
    
    /**
     * @description Logs input parameters before calling ConnectApi
     * @param templateId Template ID being called
     * @param templateType Type of template
     * @param promptInput Input parameters object
     * @param contextData Context data being sent
     * @param searchQuery Search query (if applicable)
     * @param retrieverId Retriever ID (if applicable)
     */
    public static void debugInputParameters(String templateId, String templateType, ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput, String contextData, String searchQuery, String retrieverId) {
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
    public static void debugConnectApiResponse(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput, String templateId, String templateType) {
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
        
        System.debug(DEBUG_SEPARATOR);
        System.debug(DEBUG_CONNECTAPI_END);
        System.debug(DEBUG_SEPARATOR);
    }
    
    /**
     * @description Debugs core properties of the response
     * @param generationsOutput Response object
     */
    private static void debugCoreProperties(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput) {
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
    private static void debugParameters(ConnectApi.WrappedMapObject parameters) {
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
    private static void debugRequestMessages(Object requestMessages) {
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
    private static void debugResponseMessages(Object responseMessages) {
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
    private static void debugSlotsMaskingInformation(Object slotsMaskingInfo) {
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
    private static void debugGenerations(List<ConnectApi.EinsteinLlmGenerationItemOutput> generations) {
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
    private static void debugGenerationErrors(List<ConnectApi.EinsteinPromptTemplateGenerationsError> generationErrors) {
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
    private static void debugCitations(ConnectApi.EinsteinLlmGenerationCitationOutput citations) {
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
    public static void debugFileData(List<ConnectApi.EinsteinPromptTemplateAttachment> fileData) {
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
    
    /**
     * @description Logs batch processing state information
     * @param batchIds Set of batch IDs being processed
     * @param processingChildTests Whether processing child tests
     * @param executionCount Current execution count
     */
    public static void debugBatchState(Set<Id> batchIds, Boolean processingChildTests, Integer executionCount) {
        System.debug('=== DEPENDENCY-AWARE BATCH STATE ===');
        System.debug('Execution count: ' + executionCount);
        System.debug('Processing child tests: ' + processingChildTests);
        System.debug('Batch IDs: ' + batchIds);
    }
    
    /**
     * @description Logs batch scope information
     * @param scope List of records being processed
     * @param testsProcessed Number of tests processed
     * @param testsSkipped Number of tests skipped
     */
    public static void debugBatchScope(List<SObject> scope, Integer testsProcessed, Integer testsSkipped) {
        System.debug('=== EXECUTING BATCH WITH ' + scope.size() + ' RECORDS ===');
        System.debug('Tests processed: ' + testsProcessed + ', Tests skipped: ' + testsSkipped);
    }
}
