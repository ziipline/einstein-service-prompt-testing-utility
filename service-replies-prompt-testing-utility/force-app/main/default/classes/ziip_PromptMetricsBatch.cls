public class ziip_PromptMetricsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private Set<Id> batchIds;
    
    // Template types for RAGAS evaluation
    private static final String TEMPLATE_TYPE_FAITHFULNESS = 'RAGAS Faithfulness';
    private static final String TEMPLATE_TYPE_RELEVANCY = 'RAGAS Relevancy';
    private static final String TEMPLATE_TYPE_CONTEXT_QUALITY = 'RAGAS Context Quality';
    
    // Einstein AI configuration constants
    private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';
    private static final Integer NUM_GENERATIONS = 1;
    
    public ziip_PromptMetricsBatch(Set<Id> batchIds) {
        this.batchIds = batchIds;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
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
    
    private Map<String, Object> parseTemplateResponse(String generatedText, String templateId) {
        System.debug('=== PARSING TEMPLATE RESPONSE ===');
        System.debug('Template ID: ' + templateId);
        System.debug('Generated Text: ' + generatedText);
        
        if (String.isBlank(generatedText)) {
            System.debug('ERROR: Generated text is null or empty');
            return new Map<String, Object>{
                'error' => 'Generated text is null or empty',
                'score' => 0,
                'raw_response' => generatedText
            };
        }
        
        // Try JSON parsing first (direct JSON)
        try {
            Map<String, Object> jsonResult = (Map<String, Object>) JSON.deserializeUntyped(generatedText);
            System.debug('Successfully parsed as direct JSON: ' + JSON.serialize(jsonResult));
            return jsonResult;
        } catch (Exception jsonE) {
            System.debug('Direct JSON parsing failed: ' + jsonE.getMessage());
        }
        
        // Try to extract JSON from markdown code blocks
        String extractedJson = extractJsonFromMarkdown(generatedText);
        if (String.isNotBlank(extractedJson)) {
            try {
                Map<String, Object> jsonResult = (Map<String, Object>) JSON.deserializeUntyped(extractedJson);
                System.debug('Successfully parsed JSON from markdown: ' + JSON.serialize(jsonResult));
                return jsonResult;
            } catch (Exception jsonE) {
                System.debug('Markdown JSON parsing failed: ' + jsonE.getMessage());
            }
        }
        
        // Try to extract score from plain text responses
        Map<String, Object> textResult = extractScoreFromText(generatedText, templateId);
        System.debug('Text extraction result: ' + JSON.serialize(textResult));
        
        return textResult;
    }
    
    private String extractJsonFromMarkdown(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        
        // Look for JSON code blocks (```json ... ```)
        String lowerText = text.toLowerCase();
        Integer jsonStart = lowerText.indexOf('```json');
        if (jsonStart >= 0) {
            // Find the start of the actual JSON content
            Integer contentStart = text.indexOf('\n', jsonStart);
            if (contentStart >= 0) {
                contentStart++; // Move past the newline
                
                // Find the end of the code block
                Integer contentEnd = text.indexOf('```', contentStart);
                if (contentEnd >= 0) {
                    String jsonContent = text.substring(contentStart, contentEnd).trim();
                    System.debug('Extracted JSON from markdown: ' + jsonContent);
                    return jsonContent;
                }
            }
        }
        
        // Look for generic code blocks (``` ... ```) that might contain JSON
        Integer codeStart = text.indexOf('```');
        if (codeStart >= 0) {
            Integer contentStart = text.indexOf('\n', codeStart);
            if (contentStart >= 0) {
                contentStart++; // Move past the newline
                
                Integer contentEnd = text.indexOf('```', contentStart);
                if (contentEnd >= 0) {
                    String codeContent = text.substring(contentStart, contentEnd).trim();
                    // Check if this looks like JSON (starts with { and ends with })
                    if (codeContent.startsWith('{') && codeContent.endsWith('}')) {
                        System.debug('Extracted JSON from generic code block: ' + codeContent);
                        return codeContent;
                    }
                }
            }
        }
        
        return null;
    }
    
    private Map<String, Object> extractScoreFromText(String text, String templateId) {
        Map<String, Object> result = new Map<String, Object>{
            'raw_response' => text,
            'parsing_method' => 'text_extraction'
        };
        
        // Use simpler string matching approach instead of regex
        String lowerText = text.toLowerCase();
        Decimal extractedScore = null;
        String extractionMethod = null;
        
        // Look for score keywords followed by numbers
        List<String> scoreKeywords = new List<String>{'score:', 'score', 'rating:', 'rating', 'faithfulness:', 'faithfulness', 'relevancy:', 'relevancy', 'relevance:', 'relevance'};
        
        for (String keyword : scoreKeywords) {
            Integer keywordIndex = lowerText.indexOf(keyword);
            if (keywordIndex >= 0) {
                // Look for numbers after the keyword
                String afterKeyword = text.substring(keywordIndex + keyword.length());
                Decimal score = extractFirstNumber(afterKeyword);
                if (score != null) {
                    extractedScore = score;
                    extractionMethod = 'keyword: ' + keyword;
                    System.debug('Extracted score using keyword "' + keyword + '": ' + score);
                    break;
                }
            }
        }
        
        // If no keyword match, look for any decimal number in the text
        if (extractedScore == null) {
            extractedScore = extractFirstNumber(text);
            if (extractedScore != null) {
                extractionMethod = 'first_number';
                System.debug('Extracted first number from text: ' + extractedScore);
            }
        }
        
        // Set the score and field name
        String scoreField = determineScoreField(templateId);
        if (extractedScore != null) {
            result.put(scoreField, extractedScore);
            result.put('extraction_method', extractionMethod);
        } else {
            result.put(scoreField, 0);
            result.put('error', 'No score found in response');
            System.debug('No score found in text: ' + text);
        }
        
        return result;
    }
    
    private Decimal extractFirstNumber(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        
        // Clean the text and look for decimal numbers
        String cleanText = text.replaceAll('[^0-9.]', ' ');
        List<String> parts = cleanText.split('\\s+');
        
        for (String part : parts) {
            if (String.isNotBlank(part) && (part.contains('.') || part.isNumeric())) {
                try {
                    Decimal num = Decimal.valueOf(part);
                    // Updated validation - score should be in 0-100 range as per RAGAS template specs
                    if (num >= 0 && num <= 100) {
                        return num;
                    }
                } catch (Exception e) {
                    continue;
                }
            }
        }
        
        return null;
    }
    
    private String determineScoreField(String templateId) {
        // This is a simple heuristic - in practice, you might want to store this mapping
        if (templateId != null) {
            String templateIdLower = templateId.toLowerCase();
            if (templateIdLower.contains('faithfulness')) {
                return 'faithfulness_score';
            } else if (templateIdLower.contains('relevancy') || templateIdLower.contains('relevance')) {
                return 'relevancy_score';
            } else if (templateIdLower.contains('context')) {
                return 'context_quality_score';
            }
        }
        return 'score'; // Default field name
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
