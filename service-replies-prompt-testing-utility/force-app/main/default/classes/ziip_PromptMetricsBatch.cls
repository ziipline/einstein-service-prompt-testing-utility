/**
 * @description Simplified batch class for processing RAGAS quality metrics
 * Now uses utility classes for response parsing and logging
 * @author Ziipline
 */
public class ziip_PromptMetricsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    private Set<Id> batchIds;
    public Integer batchSize;
    
    // ===========================================
    // TEMPLATE TYPE CONSTANTS
    // ===========================================
    private static final String TEMPLATE_TYPE_FAITHFULNESS = 'RAGAS Faithfulness';
    private static final String TEMPLATE_TYPE_RELEVANCY = 'RAGAS Relevancy';
    private static final String TEMPLATE_TYPE_CONTEXT_QUALITY = 'RAGAS Context Quality';
    
    // ===========================================
    // EINSTEIN AI CONFIGURATION CONSTANTS
    // ===========================================
    private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';
    private static final Integer NUM_GENERATIONS = 1;
    
    // ===========================================
    // GOVERNOR LIMIT CONSTANTS
    // ===========================================
    private static final Integer MAX_CALLOUTS_PER_TRANSACTION = 100;
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final Integer CALLOUT_SAFETY_BUFFER = 10;
    private static final Integer MAX_CALLOUTS_PER_RECORD = 3;
    
    // ===========================================
    // INPUT PARAMETER CONSTANTS
    // ===========================================
    private static final String INPUT_ORIGINAL_CONTEXT = 'Input:original_context';
    private static final String INPUT_AI_RESPONSE = 'Input:ai_response';
    private static final String INPUT_ORIGINAL_QUESTION = 'Input:original_question';
    private static final String INPUT_USER_QUESTION = 'Input:user_question';
    private static final String INPUT_AVAILABLE_CONTEXT = 'Input:available_context';
    private static final String INPUT_SEARCH_QUERY = 'Input:search_query';
    private static final String INPUT_RETRIEVED_CONTEXT = 'Input:retrieved_context';
    private static final String INPUT_KNOWLEDGE_BASE_INFO = 'Input:knowledge_base_info';
    
    // Constructor with default batch size
    public ziip_PromptMetricsBatch(Set<Id> batchIds) {
        this.batchIds = batchIds;
        this.batchSize = calculateOptimalBatchSize(batchIds);
    }
    
    // Constructor with custom batch size (for manual override)
    public ziip_PromptMetricsBatch(Set<Id> batchIds, Integer customBatchSize) {
        this.batchIds = batchIds;
        this.batchSize = customBatchSize != null && customBatchSize > 0 ? customBatchSize : calculateOptimalBatchSize(batchIds);
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('Starting RAGAS metrics batch with batch size: ' + batchSize);
        return Database.getQueryLocator([
            SELECT Id, Result__c, Raw_Result__c, Customer_Utterance__c, 
                   Transcript__c, Template_Type__c, Case__c, Voice_Call__c, Messaging_Session__c,
                   Resolved_Prompt__c, Uses_Knowledge_Grounding__c,
                   RAGAS_Faithfulness_Score__c, RAGAS_Relevancy_Score__c, RAGAS_Context_Quality_Score__c,
                   RAGAS_Faithfulness_Analysis__c, RAGAS_Relevancy_Analysis__c, RAGAS_Context_Quality_Analysis__c,
                   Quality_Assessment_Details__c, Quality_Metrics_Status__c,
                   Prompt_Test_Batch__r.Faithfulness_Template_Id__c,
                   Prompt_Test_Batch__r.Relevancy_Template_Id__c,
                   Prompt_Test_Batch__r.Context_Quality_Template_Id__c
            FROM Prompt_Test__c 
            WHERE Prompt_Test_Batch__c IN :batchIds
            AND Status__c = 'Completed'
            AND Quality_Metrics_Status__c = 'Pending'
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Prompt_Test__c> scope) {
        List<Prompt_Test__c> testsToUpdate = new List<Prompt_Test__c>();
        
        for (Prompt_Test__c test : scope) {
            try {
                // Check if this test uses knowledge grounding
                if (!test.Uses_Knowledge_Grounding__c) {
                    // Skip RAGAS evaluation for templates that don't use knowledge grounding
                    test.Quality_Metrics_Status__c = 'Skipped';
                    test.Quality_Assessment_Details__c = JSON.serialize(new Map<String, Object>{
                        'skipped_reason' => 'Template does not use knowledge grounding - RAGAS evaluation not applicable',
                        'template_type' => test.Template_Type__c,
                        'timestamp' => DateTime.now().format()
                    });
                    testsToUpdate.add(test);
                    System.debug('Skipping RAGAS evaluation for test ' + test.Id + ' - no knowledge grounding');
                    continue;
                }
                
                // Execute RAGAS quality assessment for knowledge-grounded tests only
                Map<String, Object> qualityResults = evaluateTestQuality(test);
                
                // Update test record with quality metrics - scores and detailed analysis
                test.RAGAS_Faithfulness_Score__c = (Decimal) qualityResults.get('faithfulness_score');
                test.RAGAS_Relevancy_Score__c = (Decimal) qualityResults.get('relevancy_score');
                test.RAGAS_Context_Quality_Score__c = (Decimal) qualityResults.get('context_quality_score');
                
                // Store detailed analysis JSON responses
                test.RAGAS_Faithfulness_Analysis__c = (String) qualityResults.get('faithfulness_analysis');
                test.RAGAS_Relevancy_Analysis__c = (String) qualityResults.get('relevancy_analysis');
                test.RAGAS_Context_Quality_Analysis__c = (String) qualityResults.get('context_quality_analysis');
                
                test.Quality_Assessment_Details__c = JSON.serialize(qualityResults);
                test.Quality_Metrics_Status__c = 'Completed';
                
                testsToUpdate.add(test);
                
            } catch (Exception e) {
                // Mark as failed and log error details
                test.Quality_Metrics_Status__c = 'Failed';
                test.Quality_Assessment_Details__c = JSON.serialize(new Map<String, Object>{
                    'error' => e.getMessage(),
                    'timestamp' => DateTime.now().format()
                });
                testsToUpdate.add(test);
            }
        }
        
        if (!testsToUpdate.isEmpty()) {
            update testsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Log completion and update batch status if needed
        System.debug('RAGAS quality assessment batch completed for batches: ' + batchIds);
    }
    
    /**
     * Calculates optimal batch size based on actual test distribution and callout requirements
     * @param batchIds Set of batch IDs to analyze
     * @return Integer optimal batch size for processing
     */
    private Integer calculateOptimalBatchSize(Set<Id> batchIds) {
        try {
            System.debug('=== CALCULATING OPTIMAL BATCH SIZE (ENHANCED) ===');
            System.debug('Analyzing batches: ' + batchIds);
            
            // Query batch configurations to determine how many callouts per knowledge-grounded record
            List<Prompt_Test_Batch__c> batches = [
                SELECT Id, Enable_Quality_Assessment__c,
                       Faithfulness_Template_Id__c, Relevancy_Template_Id__c, 
                       Context_Quality_Template_Id__c
                FROM Prompt_Test_Batch__c 
                WHERE Id IN :batchIds
            ];
            
            Integer maxCalloutsPerKnowledgeRecord = 0;
            Boolean hasQualityAssessment = false;
            
            for (Prompt_Test_Batch__c batch : batches) {
                Integer calloutsForThisBatch = 0;
                
                // Count configured assessment templates
                if (batch.Enable_Quality_Assessment__c == true) {
                    hasQualityAssessment = true;
                    if (String.isNotBlank(batch.Faithfulness_Template_Id__c)) {
                        calloutsForThisBatch++;
                    }
                    if (String.isNotBlank(batch.Relevancy_Template_Id__c)) {
                        calloutsForThisBatch++;
                    }
                    if (String.isNotBlank(batch.Context_Quality_Template_Id__c)) {
                        calloutsForThisBatch++;
                    }
                }
                
                // Track the maximum callouts needed per knowledge-grounded record
                maxCalloutsPerKnowledgeRecord = Math.max(maxCalloutsPerKnowledgeRecord, calloutsForThisBatch);
                
                System.debug('Batch ' + batch.Id + ' requires ' + calloutsForThisBatch + ' callouts per knowledge-grounded record');
            }
            
            // If no quality assessment enabled, use default batch size
            if (!hasQualityAssessment || maxCalloutsPerKnowledgeRecord == 0) {
                Integer defaultSize = DEFAULT_BATCH_SIZE;
                System.debug('No quality assessment enabled, using default batch size: ' + defaultSize);
                System.debug('=== BATCH SIZE CALCULATION COMPLETE ===');
                return defaultSize;
            }
            
            // Query actual test distribution to get precise callout requirements
            List<AggregateResult> testDistribution = [
                SELECT COUNT(Id) recordCount, Uses_Knowledge_Grounding__c knowsGrounding
                FROM Prompt_Test__c 
                WHERE Prompt_Test_Batch__c IN :batchIds 
                AND Status__c = 'Completed' 
                AND Quality_Metrics_Status__c = 'Pending'
                GROUP BY Uses_Knowledge_Grounding__c
            ];
            
            Integer knowledgeGroundedTests = 0;
            Integer totalTests = 0;
            
            for (AggregateResult result : testDistribution) {
                Integer count = (Integer) result.get('recordCount');
                Boolean isKnowledgeGrounded = (Boolean) result.get('knowsGrounding');
                
                totalTests += count;
                if (isKnowledgeGrounded == true) {
                    knowledgeGroundedTests += count;
                }
                
                System.debug('Tests with Uses_Knowledge_Grounding__c = ' + isKnowledgeGrounded + ': ' + count);
            }
            
            System.debug('Total tests: ' + totalTests);
            System.debug('Knowledge-grounded tests: ' + knowledgeGroundedTests);
            System.debug('Max callouts per knowledge-grounded test: ' + maxCalloutsPerKnowledgeRecord);
            
            // Calculate optimal batch size based on actual distribution
            Integer optimalBatchSize;
            
            if (knowledgeGroundedTests == 0) {
                // No knowledge-grounded tests, no callouts needed
                optimalBatchSize = DEFAULT_BATCH_SIZE;
                System.debug('No knowledge-grounded tests found, using default batch size: ' + optimalBatchSize);
            } else if (totalTests == knowledgeGroundedTests) {
                // All tests are knowledge-grounded, use simple calculation
                Integer maxSafeCallouts = MAX_CALLOUTS_PER_TRANSACTION - CALLOUT_SAFETY_BUFFER;
                optimalBatchSize = Math.max(1, maxSafeCallouts / maxCalloutsPerKnowledgeRecord);
                System.debug('All tests are knowledge-grounded, calculated batch size: ' + optimalBatchSize);
            } else {
                // Mixed distribution - calculate based on expected callouts per batch
                Decimal knowledgeRatio = Decimal.valueOf(knowledgeGroundedTests) / Decimal.valueOf(totalTests);
                Integer maxSafeCallouts = MAX_CALLOUTS_PER_TRANSACTION - CALLOUT_SAFETY_BUFFER;
                
                // Expected callouts per batch = batch_size * knowledge_ratio * callouts_per_knowledge_test
                // Solve for batch_size: batch_size = max_safe_callouts / (knowledge_ratio * callouts_per_knowledge_test)
                Decimal expectedCalloutsPerRecord = knowledgeRatio * maxCalloutsPerKnowledgeRecord;
                optimalBatchSize = Math.max(1, (maxSafeCallouts / expectedCalloutsPerRecord).intValue());
                
                System.debug('Mixed distribution - Knowledge ratio: ' + knowledgeRatio.setScale(3));
                System.debug('Expected callouts per record: ' + expectedCalloutsPerRecord.setScale(3));
                System.debug('Calculated batch size: ' + optimalBatchSize);
            }
            
            // Cap at reasonable maximum to avoid other governor limits (DML, CPU, etc.)
            optimalBatchSize = Math.min(optimalBatchSize, 50);
            
            // Additional validation: ensure batch size makes sense given total test count
            if (totalTests > 0 && optimalBatchSize > totalTests) {
                optimalBatchSize = Math.min(optimalBatchSize, totalTests);
                System.debug('Adjusted batch size to match total test count: ' + optimalBatchSize);
            }
            
            System.debug('Final optimal batch size: ' + optimalBatchSize);
            System.debug('Expected max callouts per batch: ' + 
                       (optimalBatchSize * maxCalloutsPerKnowledgeRecord * 
                        (knowledgeGroundedTests > 0 ? Decimal.valueOf(knowledgeGroundedTests) / totalTests : 0)).intValue());
            System.debug('=== BATCH SIZE CALCULATION COMPLETE ===');
            
            return optimalBatchSize;
            
        } catch (Exception e) {
            System.debug('Error calculating optimal batch size: ' + e.getMessage());
            System.debug('Exception details: ' + e.getStackTraceString());
            
            // Fallback to conservative batch size on error
            Integer fallbackSize = Math.max(1, (MAX_CALLOUTS_PER_TRANSACTION - CALLOUT_SAFETY_BUFFER) / MAX_CALLOUTS_PER_RECORD);
            System.debug('Using fallback batch size: ' + fallbackSize);
            return fallbackSize;
        }
    }
    
    private Map<String, Object> evaluateTestQuality(Prompt_Test__c test) {
        Map<String, Object> results = new Map<String, Object>();
        
        // Get template IDs from batch configuration
        String faithfulnessTemplateId = test.Prompt_Test_Batch__r.Faithfulness_Template_Id__c;
        String relevancyTemplateId = test.Prompt_Test_Batch__r.Relevancy_Template_Id__c;
        String contextQualityTemplateId = test.Prompt_Test_Batch__r.Context_Quality_Template_Id__c;
        
        // Evaluate faithfulness if template is configured
        if (String.isNotBlank(faithfulnessTemplateId)) {
            Map<String, Object> faithfulnessResult = evaluateFaithfulness(test, faithfulnessTemplateId);
            results.put('faithfulness_score', faithfulnessResult.get('score'));
            results.put('faithfulness_analysis', faithfulnessResult.get('analysis'));
        }
        
        // Evaluate relevancy if template is configured
        if (String.isNotBlank(relevancyTemplateId)) {
            Map<String, Object> relevancyResult = evaluateRelevancy(test, relevancyTemplateId);
            results.put('relevancy_score', relevancyResult.get('score'));
            results.put('relevancy_analysis', relevancyResult.get('analysis'));
        }
        
        // Evaluate context quality if template is configured
        if (String.isNotBlank(contextQualityTemplateId)) {
            Map<String, Object> contextQualityResult = evaluateContextQuality(test, contextQualityTemplateId);
            results.put('context_quality_score', contextQualityResult.get('score'));
            results.put('context_quality_analysis', contextQualityResult.get('analysis'));
        }
        
        // Add timestamp and metadata
        results.put('evaluation_timestamp', DateTime.now().format());
        results.put('evaluation_version', '2.0');
        
        return results;
    }
    
    private Map<String, Object> evaluateFaithfulness(Prompt_Test__c test, String templateId) {
        // Prepare input parameters for faithfulness assessment
        Map<String, Object> inputParams = new Map<String, Object>{
            'Input:original_context' => getOriginalContext(test),
            'Input:ai_response' => test.Result__c,
            'Input:original_question' => test.Customer_Utterance__c
        };
        
        // Call Einstein Prompt Template API
        Map<String, Object> response = callEinsteinTemplate(templateId, inputParams);
        
        // Extract score and full analysis
        Decimal score = parseFaithfulnessScore(response);
        String analysis = JSON.serializePretty(response);
        
        return new Map<String, Object>{
            'score' => score,
            'analysis' => analysis
        };
    }
    
    private Map<String, Object> evaluateRelevancy(Prompt_Test__c test, String templateId) {
        // Prepare input parameters for relevancy assessment
        Map<String, Object> inputParams = new Map<String, Object>{
            'Input:user_question' => test.Customer_Utterance__c,
            'Input:ai_response' => test.Result__c,
            'Input:available_context' => getOriginalContext(test)
        };
        
        // Call Einstein Prompt Template API
        Map<String, Object> response = callEinsteinTemplate(templateId, inputParams);
        
        // Extract score and full analysis
        Decimal score = parseRelevancyScore(response);
        String analysis = JSON.serializePretty(response);
        
        return new Map<String, Object>{
            'score' => score,
            'analysis' => analysis
        };
    }
    
    private Map<String, Object> evaluateContextQuality(Prompt_Test__c test, String templateId) {
        // Prepare input parameters for context quality assessment
        Map<String, Object> inputParams = new Map<String, Object>{
            'Input:search_query' => test.Customer_Utterance__c,
            'Input:retrieved_context' => getOriginalContext(test),
            'Input:ai_response' => test.Result__c,
            'Input:knowledge_base_info' => getKnowledgeBaseInfo(test)
        };
        
        // Call Einstein Prompt Template API
        Map<String, Object> response = callEinsteinTemplate(templateId, inputParams);
        
        // Extract score and full analysis
        Decimal score = parseContextQualityScore(response);
        String analysis = JSON.serializePretty(response);
        
        return new Map<String, Object>{
            'score' => score,
            'analysis' => analysis
        };
    }
    
    private String getOriginalContext(Prompt_Test__c test) {
        // For quality assessment, use the resolved prompt which contains the actual context
        // (including knowledge grounding) that was provided to the AI model
        if (String.isNotBlank(test.Resolved_Prompt__c)) {
            return test.Resolved_Prompt__c;
        }
        
        // Fallback to building context from available data sources if resolved prompt is not available
        List<String> contextParts = new List<String>();
        
        if (String.isNotBlank(test.Transcript__c)) {
            contextParts.add('Transcript: ' + test.Transcript__c);
        }
        
        // Add case information if available
        if (String.isNotBlank(test.Case__c)) {
            contextParts.add('Case ID: ' + test.Case__c);
        }
        
        // Add voice call information if available
        if (String.isNotBlank(test.Voice_Call__c)) {
            contextParts.add('Voice Call ID: ' + test.Voice_Call__c);
        }
        
        // Add messaging session if available
        if (String.isNotBlank(test.Messaging_Session__c)) {
            contextParts.add('Messaging Session ID: ' + test.Messaging_Session__c);
        }
        
        return String.join(contextParts, '\n\n');
    }
    
    private String getKnowledgeBaseInfo(Prompt_Test__c test) {
        // Return metadata about available knowledge sources
        Map<String, Object> kbInfo = new Map<String, Object>{
            'template_type' => test.Template_Type__c,
            'has_transcript' => String.isNotBlank(test.Transcript__c),
            'has_case_context' => String.isNotBlank(test.Case__c),
            'has_voice_context' => String.isNotBlank(test.Voice_Call__c),
            'has_messaging_context' => String.isNotBlank(test.Messaging_Session__c)
        };
        
        return JSON.serialize(kbInfo);
    }
    
    private Map<String, Object> callEinsteinTemplate(String templateId, Map<String, Object> inputParams) {
        // Enhanced logging for debugging
        Long startTime = System.currentTimeMillis();
        System.debug('=== RAGAS TEMPLATE CALL START ===');
        System.debug('Template ID: ' + templateId);
        System.debug('Input Parameters: ' + JSON.serialize(inputParams));
        
        try {
            // Validate template ID
            if (String.isBlank(templateId)) {
                throw new IllegalArgumentException('Template ID is null or empty');
            }
            
            // Convert input parameters to ConnectApi.WrappedValue format
            Map<String, ConnectApi.WrappedValue> wrappedParams = new Map<String, ConnectApi.WrappedValue>();
            for (String key : inputParams.keySet()) {
                ConnectApi.WrappedValue wrappedValue = new ConnectApi.WrappedValue();
                wrappedValue.value = inputParams.get(key);
                wrappedParams.put(key, wrappedValue);
            }
            
            System.debug('Wrapped Parameters Count: ' + wrappedParams.size());
            
            // Create the input for Einstein Prompt Template
            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.inputParams = wrappedParams;
            
            // Configure additional settings (CRITICAL: This was missing!)
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.numGenerations = NUM_GENERATIONS;
            input.additionalConfig.enablePiiMasking = true;
            input.additionalConfig.applicationName = APPLICATION_NAME;
            
            System.debug('Calling Einstein API for template: ' + templateId);
            
            // Call the Einstein Prompt Template API
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateId, input);
            
            Long apiCallTime = System.currentTimeMillis() - startTime;
            System.debug('Einstein API call completed in ' + apiCallTime + 'ms');
            
            // Enhanced response analysis
            if (result == null) {
                System.debug('ERROR: Einstein API returned null result');
                return createErrorResponse('Einstein API returned null result', templateId, inputParams);
            }
            
            if (result.generations == null || result.generations.isEmpty()) {
                System.debug('ERROR: No generations in Einstein API response');
                System.debug('Full result object: ' + JSON.serialize(result));
                return createErrorResponse('No generations in Einstein API response', templateId, inputParams);
            }
            
            String generatedText = result.generations[0].text;
            System.debug('Raw generated text: ' + generatedText);
            System.debug('Generated text length: ' + (generatedText != null ? generatedText.length() : 0));
            
            // Flexible response parsing
            Map<String, Object> parsedResponse = parseTemplateResponse(generatedText, templateId);
            
            Long totalTime = System.currentTimeMillis() - startTime;
            System.debug('Total processing time: ' + totalTime + 'ms');
            System.debug('Parsed response: ' + JSON.serialize(parsedResponse));
            System.debug('=== RAGAS TEMPLATE CALL END ===');
            
            return parsedResponse;
            
        } catch (ConnectApi.ConnectApiException e) {
            Long errorTime = System.currentTimeMillis() - startTime;
            System.debug('ConnectApi Exception after ' + errorTime + 'ms: ' + e.getMessage());
            System.debug('Exception Type: ' + e.getTypeName());
            System.debug('Exception Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('ConnectApi Exception: ' + e.getMessage(), templateId, inputParams);
            
        } catch (Exception e) {
            Long errorTime = System.currentTimeMillis() - startTime;
            System.debug('General Exception after ' + errorTime + 'ms: ' + e.getMessage());
            System.debug('Exception Type: ' + e.getTypeName());
            System.debug('Exception Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('General Exception: ' + e.getMessage(), templateId, inputParams);
        }
    }
    
    /**
     * @description Parses template response using utility parser
     * @param generatedText Raw response text from Einstein API
     * @param templateId Template ID for context
     * @return Map<String, Object> parsed response data
     */
    private Map<String, Object> parseTemplateResponse(String generatedText, String templateId) {
        return ziip_EinsteinResponseParser.parseTemplateResponse(generatedText, templateId);
    }
    
    private Map<String, Object> createErrorResponse(String errorMessage, String templateId, Map<String, Object> inputParams) {
        return new Map<String, Object>{
            'error' => errorMessage,
            'template_id' => templateId,
            'input_params' => inputParams,
            'score' => 0,
            'timestamp' => DateTime.now().format()
        };
    }
    
    private Decimal parseFaithfulnessScore(Map<String, Object> response) {
        try {
            Object scoreObj = response.get('faithfulness_score');
            if (scoreObj instanceof Decimal) {
                return (Decimal) scoreObj;
            } else if (scoreObj instanceof Integer) {
                return Decimal.valueOf((Integer) scoreObj);
            } else if (scoreObj instanceof String) {
                return Decimal.valueOf((String) scoreObj);
            }
        } catch (Exception e) {
            System.debug('Error parsing faithfulness score: ' + e.getMessage());
        }
        
        return 0; // Default score if parsing fails
    }
    
    private Decimal parseRelevancyScore(Map<String, Object> response) {
        try {
            Object scoreObj = response.get('relevancy_score');
            if (scoreObj instanceof Decimal) {
                return (Decimal) scoreObj;
            } else if (scoreObj instanceof Integer) {
                return Decimal.valueOf((Integer) scoreObj);
            } else if (scoreObj instanceof String) {
                return Decimal.valueOf((String) scoreObj);
            }
        } catch (Exception e) {
            System.debug('Error parsing relevancy score: ' + e.getMessage());
        }
        
        return 0; // Default score if parsing fails
    }
    
    private Decimal parseContextQualityScore(Map<String, Object> response) {
        try {
            Object scoreObj = response.get('context_quality_score');
            if (scoreObj instanceof Decimal) {
                return (Decimal) scoreObj;
            } else if (scoreObj instanceof Integer) {
                return Decimal.valueOf((Integer) scoreObj);
            } else if (scoreObj instanceof String) {
                return Decimal.valueOf((String) scoreObj);
            }
        } catch (Exception e) {
            System.debug('Error parsing context quality score: ' + e.getMessage());
        }
        
        return 0; // Default score if parsing fails
    }
}
