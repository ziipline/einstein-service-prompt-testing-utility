/**
 * @description Utility class for parsing Einstein AI API responses into usable data
 * Handles complex logic of extracting scores from various response formats (JSON, markdown, plain text)
 */
public class ziip_EinsteinResponseParser {
    
    /**
     * @description Parses template response with flexible handling of different formats
     * @param generatedText Raw text from Einstein API
     * @param templateId Template ID for context
     * @return Map parsed response with score and metadata
     */
    public static Map<String, Object> parseTemplateResponse(String generatedText, String templateId) {
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
    
    /**
     * @description Extracts JSON content from markdown code blocks with enhanced parsing
     * @param text Text potentially containing markdown
     * @return String extracted JSON or null if not found
     */
    public static String extractJsonFromMarkdown(String text) {
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
                    // Clean up any common formatting issues
                    jsonContent = cleanJsonContent(jsonContent);
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
                        // Clean up any common formatting issues
                        codeContent = cleanJsonContent(codeContent);
                        System.debug('Extracted JSON from generic code block: ' + codeContent);
                        return codeContent;
                    }
                }
            }
        }
        
        // Look for JSON-like content without code blocks (direct JSON in response)
        Integer jsonStartDirect = text.indexOf('{');
        if (jsonStartDirect >= 0) {
            Integer jsonEndDirect = text.lastIndexOf('}');
            if (jsonEndDirect > jsonStartDirect) {
                String directJson = text.substring(jsonStartDirect, jsonEndDirect + 1);
                // Clean up any common formatting issues
                directJson = cleanJsonContent(directJson);
                System.debug('Extracted direct JSON: ' + directJson);
                return directJson;
            }
        }
        
        return null;
    }
    
    /**
     * @description Cleans common JSON formatting issues
     * @param jsonContent Raw JSON content
     * @return String cleaned JSON content
     */
    private static String cleanJsonContent(String jsonContent) {
        if (String.isBlank(jsonContent)) {
            return jsonContent;
        }
        
        // Fix common HTML entity encoding issues from templates
        jsonContent = jsonContent.replace('&quot;', '"');
        jsonContent = jsonContent.replace('&amp;', '&');
        jsonContent = jsonContent.replace('&lt;', '<');
        jsonContent = jsonContent.replace('&gt;', '>');
        
        // Fix escaped newlines that might cause issues
        jsonContent = jsonContent.replace('\\n', '\n');
        jsonContent = jsonContent.replace('\\"', '"');
        
        return jsonContent.trim();
    }
    
    /**
     * @description Extracts scores from plain text using comprehensive keyword matching
     * @param text Text to search for scores
     * @param templateId Template ID for determining score field name
     * @return Map with extracted score and metadata
     */
    public static Map<String, Object> extractScoreFromText(String text, String templateId) {
        Map<String, Object> result = new Map<String, Object>{
            'raw_response' => text,
            'parsing_method' => 'text_extraction'
        };
        
        // Use simpler string matching approach instead of regex
        String lowerText = text.toLowerCase();
        Decimal extractedScore = null;
        String extractionMethod = null;
        
        // Enhanced keyword matching - try specific score types first, then general keywords
        List<List<String>> keywordGroups = new List<List<String>>{
            // Context Quality specific keywords
            new List<String>{'context_quality_score:', 'context_quality_score', 'context quality score:', 'context quality score', 'context_score:', 'context_score', 'context quality:', 'context quality'},
            // Faithfulness specific keywords  
            new List<String>{'faithfulness_score:', 'faithfulness_score', 'faithfulness score:', 'faithfulness score', 'faithful_score:', 'faithful_score', 'faithfulness:', 'faithfulness'},
            // Relevancy specific keywords
            new List<String>{'relevancy_score:', 'relevancy_score', 'relevance_score:', 'relevance_score', 'relevancy score:', 'relevancy score', 'relevance score:', 'relevance score', 'relevancy:', 'relevancy', 'relevance:', 'relevance'},
            // General score keywords (fallback)
            new List<String>{'score:', 'score', 'rating:', 'rating', 'value:', 'value'}
        };
        
        // Try each keyword group
        for (List<String> keywordGroup : keywordGroups) {
            for (String keyword : keywordGroup) {
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
            if (extractedScore != null) {
                break; // Stop searching once we find a score
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
        
        // Determine the correct score field name and assign the score
        String scoreField = determineScoreField(templateId);
        if (extractedScore != null) {
            result.put(scoreField, extractedScore);
            result.put('extraction_method', extractionMethod);
            System.debug('Assigned score ' + extractedScore + ' to field: ' + scoreField);
        } else {
            result.put(scoreField, 0);
            result.put('error', 'No score found in response');
            System.debug('No score found in text: ' + text);
        }
        
        return result;
    }
    
    /**
     * @description Extracts the first valid number from text
     * @param text Text to search for numbers
     * @return Decimal first valid number or null if none found
     */
    public static Decimal extractFirstNumber(String text) {
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
                    // Score should be in 0-100 range as per RAGAS template specs
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
    
    /**
     * @description Determines the appropriate score field name based on template ID with enhanced detection
     * @param templateId Template ID to analyze
     * @return String score field name
     */
    public static String determineScoreField(String templateId) {
        if (String.isBlank(templateId)) {
            return 'score'; // Default field name
        }
        
        String templateIdLower = templateId.toLowerCase();
        System.debug('Determining score field for template ID: ' + templateId);
        
        // Enhanced template type detection with multiple patterns
        // Faithfulness patterns
        if (templateIdLower.contains('faithfulness') || 
            templateIdLower.contains('faithful') ||
            templateIdLower.contains('ragas_faithfulness') ||
            templateIdLower.contains('ragas-faithfulness')) {
            System.debug('Detected faithfulness template, returning faithfulness_score');
            return 'faithfulness_score';
        }
        
        // Relevancy patterns (check before context to avoid conflicts)
        if (templateIdLower.contains('relevancy') || 
            templateIdLower.contains('relevance') ||
            templateIdLower.contains('ragas_relevancy') ||
            templateIdLower.contains('ragas-relevancy') ||
            templateIdLower.contains('ragas_relevance') ||
            templateIdLower.contains('ragas-relevance')) {
            System.debug('Detected relevancy template, returning relevancy_score');
            return 'relevancy_score';
        }
        
        // Context Quality patterns
        if (templateIdLower.contains('context') || 
            templateIdLower.contains('ragas_context') ||
            templateIdLower.contains('ragas-context') ||
            templateIdLower.contains('context_quality') ||
            templateIdLower.contains('context-quality')) {
            System.debug('Detected context quality template, returning context_quality_score');
            return 'context_quality_score';
        }
        
        System.debug('No specific template pattern matched, returning default score field');
        return 'score'; // Default field name
    }
    
    /**
     * @description Creates a standardized error response
     * @param errorMessage Error message
     * @param templateId Template ID for context
     * @param inputParams Input parameters for debugging
     * @return Map error response
     */
    public static Map<String, Object> createErrorResponse(String errorMessage, String templateId, Map<String, Object> inputParams) {
        return new Map<String, Object>{
            'error' => errorMessage,
            'template_id' => templateId,
            'input_params' => inputParams,
            'score' => 0,
            'timestamp' => DateTime.now().format()
        };
    }
    
    /**
     * @description Parses faithfulness score from response with fallback logic
     * @param response Response map to parse
     * @return Decimal faithfulness score
     */
    public static Decimal parseFaithfulnessScore(Map<String, Object> response) {
        return parseScoreWithFallback(response, new List<String>{
            'faithfulness_score', 
            'faithfulness', 
            'faithful_score',
            'score'
        }, 'faithfulness');
    }
    
    /**
     * @description Parses relevancy score from response with fallback logic
     * @param response Response map to parse
     * @return Decimal relevancy score
     */
    public static Decimal parseRelevancyScore(Map<String, Object> response) {
        return parseScoreWithFallback(response, new List<String>{
            'relevancy_score',
            'relevance_score', 
            'relevancy', 
            'relevance',
            'score'
        }, 'relevancy');
    }
    
    /**
     * @description Parses context quality score from response with fallback logic
     * @param response Response map to parse
     * @return Decimal context quality score
     */
    public static Decimal parseContextQualityScore(Map<String, Object> response) {
        return parseScoreWithFallback(response, new List<String>{
            'context_quality_score',
            'context_score',
            'context_quality',
            'context',
            'score'
        }, 'context_quality');
    }
    
    /**
     * @description Generic score parsing with fallback field names
     * @param response Response map to parse
     * @param fieldNames List of field names to try in order
     * @param scoreType Type of score for debugging
     * @return Decimal parsed score or 0 if not found
     */
    private static Decimal parseScoreWithFallback(Map<String, Object> response, List<String> fieldNames, String scoreType) {
        if (response == null || fieldNames == null || fieldNames.isEmpty()) {
            System.debug('Invalid input for score parsing: response or fieldNames is null/empty');
            return 0;
        }
        
        System.debug('Parsing ' + scoreType + ' score with field fallback. Available fields: ' + response.keySet());
        
        for (String fieldName : fieldNames) {
            try {
                Object scoreObj = response.get(fieldName);
                if (scoreObj != null) {
                    Decimal parsedScore = null;
                    
                    if (scoreObj instanceof Decimal) {
                        parsedScore = (Decimal) scoreObj;
                    } else if (scoreObj instanceof Integer) {
                        parsedScore = Decimal.valueOf((Integer) scoreObj);
                    } else if (scoreObj instanceof String) {
                        String scoreStr = (String) scoreObj;
                        if (String.isNotBlank(scoreStr)) {
                            parsedScore = Decimal.valueOf(scoreStr);
                        }
                    } else if (scoreObj instanceof Double) {
                        parsedScore = Decimal.valueOf((Double) scoreObj);
                    }
                    
                    if (parsedScore != null) {
                        System.debug('Successfully parsed ' + scoreType + ' score from field "' + fieldName + '": ' + parsedScore);
                        return parsedScore;
                    }
                }
            } catch (Exception e) {
                System.debug('Error parsing ' + scoreType + ' score from field "' + fieldName + '": ' + e.getMessage());
                continue; // Try next field name
            }
        }
        
        System.debug('No valid ' + scoreType + ' score found in response, returning 0');
        return 0; // Default score if parsing fails for all field names
    }
    
    // ===========================================
    // ASSESSMENT FORMATTING METHODS
    // ===========================================
    
    /**
     * @description Formats faithfulness assessment JSON into human-readable text
     * @param jsonResponse Raw JSON response from faithfulness assessment
     * @return String formatted faithfulness analysis
     */
    public static String formatFaithfulnessAnalysis(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            return 'No faithfulness assessment data available.';
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            String formatted = '';
            
            // Header
            formatted += 'FAITHFULNESS ASSESSMENT\n';
            formatted += '========================\n\n';
            
            // Score
            Object scoreObj = response.get('faithfulness_score');
            if (scoreObj == null) {
                scoreObj = response.get('score');
            }
            if (scoreObj != null) {
                formatted += 'Score: ' + scoreObj + '/100\n\n';
            }
            
            // Reasoning
            Object reasoningObj = response.get('reasoning');
            if (reasoningObj != null) {
                formatted += 'Assessment Reasoning:\n';
                formatted += '--------------------\n';
                formatted += String.valueOf(reasoningObj) + '\n\n';
            }
            
            // Grounded Elements
            Object groundedObj = response.get('grounded_elements');
            if (groundedObj instanceof List<Object>) {
                List<Object> groundedElements = (List<Object>) groundedObj;
                if (!groundedElements.isEmpty()) {
                    formatted += 'Grounded Elements (Supported by Context):\n';
                    formatted += '----------------------------------------\n';
                    for (Integer i = 0; i < groundedElements.size(); i++) {
                        formatted += '• ' + String.valueOf(groundedElements[i]) + '\n';
                    }
                    formatted += '\n';
                }
            }
            
            // Hallucinated Elements
            Object hallucinatedObj = response.get('hallucinated_elements');
            if (hallucinatedObj instanceof List<Object>) {
                List<Object> hallucinatedElements = (List<Object>) hallucinatedObj;
                if (!hallucinatedElements.isEmpty()) {
                    formatted += 'Hallucinated Elements (Not Supported by Context):\n';
                    formatted += '------------------------------------------------\n';
                    for (Integer i = 0; i < hallucinatedElements.size(); i++) {
                        formatted += '• ' + String.valueOf(hallucinatedElements[i]) + '\n';
                    }
                    formatted += '\n';
                } else {
                    formatted += 'Hallucinated Elements: None identified\n\n';
                }
            }
            
            // Additional metadata
            Object extractionMethodObj = response.get('extraction_method');
            if (extractionMethodObj != null) {
                formatted += 'Extraction Method: ' + String.valueOf(extractionMethodObj) + '\n';
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug('Error formatting faithfulness analysis: ' + e.getMessage());
            return 'Error formatting faithfulness assessment:\n' + e.getMessage() + '\n\nRaw Response:\n' + jsonResponse;
        }
    }
    
    /**
     * @description Formats relevancy assessment JSON into human-readable text
     * @param jsonResponse Raw JSON response from relevancy assessment
     * @return String formatted relevancy analysis
     */
    public static String formatRelevancyAnalysis(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            return 'No relevancy assessment data available.';
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            String formatted = '';
            
            // Header
            formatted += 'RELEVANCY ASSESSMENT\n';
            formatted += '====================\n\n';
            
            // Score
            Object scoreObj = response.get('relevancy_score');
            if (scoreObj == null) {
                scoreObj = response.get('relevance_score');
            }
            if (scoreObj == null) {
                scoreObj = response.get('score');
            }
            if (scoreObj != null) {
                formatted += 'Score: ' + scoreObj + '/100\n\n';
            }
            
            // Reasoning
            Object reasoningObj = response.get('reasoning');
            if (reasoningObj != null) {
                formatted += 'Assessment Reasoning:\n';
                formatted += '--------------------\n';
                formatted += String.valueOf(reasoningObj) + '\n\n';
            }
            
            // Relevant Aspects
            Object relevantObj = response.get('relevant_aspects');
            if (relevantObj instanceof List<Object>) {
                List<Object> relevantAspects = (List<Object>) relevantObj;
                if (!relevantAspects.isEmpty()) {
                    formatted += 'Relevant Aspects (Addresses User Query):\n';
                    formatted += '---------------------------------------\n';
                    for (Integer i = 0; i < relevantAspects.size(); i++) {
                        formatted += '• ' + String.valueOf(relevantAspects[i]) + '\n';
                    }
                    formatted += '\n';
                }
            }
            
            // Irrelevant Aspects
            Object irrelevantObj = response.get('irrelevant_aspects');
            if (irrelevantObj instanceof List<Object>) {
                List<Object> irrelevantAspects = (List<Object>) irrelevantObj;
                if (!irrelevantAspects.isEmpty()) {
                    formatted += 'Irrelevant Aspects (Does Not Address User Query):\n';
                    formatted += '------------------------------------------------\n';
                    for (Integer i = 0; i < irrelevantAspects.size(); i++) {
                        formatted += '• ' + String.valueOf(irrelevantAspects[i]) + '\n';
                    }
                    formatted += '\n';
                } else {
                    formatted += 'Irrelevant Aspects: None identified\n\n';
                }
            }
            
            // Missing Aspects
            Object missingObj = response.get('missing_aspects');
            if (missingObj instanceof List<Object>) {
                List<Object> missingAspects = (List<Object>) missingObj;
                if (!missingAspects.isEmpty()) {
                    formatted += 'Missing Aspects (Should Be Addressed):\n';
                    formatted += '-------------------------------------\n';
                    for (Integer i = 0; i < missingAspects.size(); i++) {
                        formatted += '• ' + String.valueOf(missingAspects[i]) + '\n';
                    }
                    formatted += '\n';
                } else {
                    formatted += 'Missing Aspects: None identified\n\n';
                }
            }
            
            // Additional metadata
            Object extractionMethodObj = response.get('extraction_method');
            if (extractionMethodObj != null) {
                formatted += 'Extraction Method: ' + String.valueOf(extractionMethodObj) + '\n';
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug('Error formatting relevancy analysis: ' + e.getMessage());
            return 'Error formatting relevancy assessment:\n' + e.getMessage() + '\n\nRaw Response:\n' + jsonResponse;
        }
    }
    
    /**
     * @description Formats context quality assessment JSON into human-readable text
     * @param jsonResponse Raw JSON response from context quality assessment
     * @return String formatted context quality analysis
     */
    public static String formatContextQualityAnalysis(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            return 'No context quality assessment data available.';
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            String formatted = '';
            
            // Header
            formatted += 'CONTEXT QUALITY ASSESSMENT\n';
            formatted += '===========================\n\n';
            
            // Score
            Object scoreObj = response.get('context_quality_score');
            if (scoreObj == null) {
                scoreObj = response.get('context_score');
            }
            if (scoreObj == null) {
                scoreObj = response.get('score');
            }
            if (scoreObj != null) {
                formatted += 'Score: ' + scoreObj + '/100\n\n';
            }
            
            // Reasoning
            Object reasoningObj = response.get('reasoning');
            if (reasoningObj != null) {
                formatted += 'Assessment Reasoning:\n';
                formatted += '--------------------\n';
                formatted += String.valueOf(reasoningObj) + '\n\n';
            }
            
            // Precision Score
            Object precisionObj = response.get('precision');
            if (precisionObj != null) {
                formatted += 'Precision: ' + precisionObj;
                formatted += ' (Proportion of retrieved context that is relevant)\n';
            }
            
            // Recall Score
            Object recallObj = response.get('recall');
            if (recallObj != null) {
                formatted += 'Recall: ' + recallObj;
                formatted += ' (Proportion of relevant context that was retrieved)\n\n';
            }
            
            // Relevant Context
            Object relevantContextObj = response.get('relevant_context');
            if (relevantContextObj instanceof List<Object>) {
                List<Object> relevantContext = (List<Object>) relevantContextObj;
                if (!relevantContext.isEmpty()) {
                    formatted += 'Relevant Context Elements:\n';
                    formatted += '--------------------------\n';
                    for (Integer i = 0; i < relevantContext.size(); i++) {
                        formatted += '• ' + String.valueOf(relevantContext[i]) + '\n';
                    }
                    formatted += '\n';
                }
            }
            
            // Irrelevant Context
            Object irrelevantContextObj = response.get('irrelevant_context');
            if (irrelevantContextObj instanceof List<Object>) {
                List<Object> irrelevantContext = (List<Object>) irrelevantContextObj;
                if (!irrelevantContext.isEmpty()) {
                    formatted += 'Irrelevant Context Elements:\n';
                    formatted += '----------------------------\n';
                    for (Integer i = 0; i < irrelevantContext.size(); i++) {
                        formatted += '• ' + String.valueOf(irrelevantContext[i]) + '\n';
                    }
                    formatted += '\n';
                } else {
                    formatted += 'Irrelevant Context Elements: None identified\n\n';
                }
            }
            
            // Missing Context
            Object missingContextObj = response.get('missing_context');
            if (missingContextObj instanceof List<Object>) {
                List<Object> missingContext = (List<Object>) missingContextObj;
                if (!missingContext.isEmpty()) {
                    formatted += 'Missing Context Elements:\n';
                    formatted += '-------------------------\n';
                    for (Integer i = 0; i < missingContext.size(); i++) {
                        formatted += '• ' + String.valueOf(missingContext[i]) + '\n';
                    }
                    formatted += '\n';
                } else {
                    formatted += 'Missing Context Elements: None identified\n\n';
                }
            }
            
            // Additional metadata
            Object extractionMethodObj = response.get('extraction_method');
            if (extractionMethodObj != null) {
                formatted += 'Extraction Method: ' + String.valueOf(extractionMethodObj) + '\n';
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug('Error formatting context quality analysis: ' + e.getMessage());
            return 'Error formatting context quality assessment:\n' + e.getMessage() + '\n\nRaw Response:\n' + jsonResponse;
        }
    }
    
    /**
     * @description Formats overall quality assessment details JSON into human-readable text
     * @param jsonResponse Raw JSON response from overall quality assessment
     * @return String formatted quality assessment details
     */
    public static String formatQualityAssessmentDetails(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            return 'No quality assessment details available.';
        }
        
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            String formatted = '';
            
            // Header
            formatted += 'QUALITY ASSESSMENT SUMMARY\n';
            formatted += '==========================\n\n';
            
            // Overall Scores Summary
            formatted += 'SCORES SUMMARY:\n';
            formatted += '---------------\n';
            
            Object faithfulnessScore = response.get('faithfulness_score');
            if (faithfulnessScore != null) {
                formatted += 'Faithfulness: ' + faithfulnessScore + '/100\n';
            }
            
            Object relevancyScore = response.get('relevancy_score');
            if (relevancyScore == null) {
                relevancyScore = response.get('relevance_score');
            }
            if (relevancyScore != null) {
                formatted += 'Relevancy: ' + relevancyScore + '/100\n';
            }
            
            Object contextScore = response.get('context_quality_score');
            if (contextScore == null) {
                contextScore = response.get('context_score');
            }
            if (contextScore != null) {
                formatted += 'Context Quality: ' + contextScore + '/100\n';
            }
            
            formatted += '\n';
            
            // Assessment Status
            Object statusObj = response.get('status');
            if (statusObj != null) {
                formatted += 'Assessment Status: ' + String.valueOf(statusObj) + '\n\n';
            }
            
            // Processing Information
            Object processingTimeObj = response.get('processing_time_ms');
            if (processingTimeObj != null) {
                formatted += 'Processing Time: ' + processingTimeObj + ' ms\n';
            }
            
            Object timestampObj = response.get('timestamp');
            if (timestampObj != null) {
                formatted += 'Assessment Timestamp: ' + String.valueOf(timestampObj) + '\n';
            }
            
            // Template Information
            Object templatesUsedObj = response.get('templates_used');
            if (templatesUsedObj instanceof Map<String, Object>) {
                Map<String, Object> templatesUsed = (Map<String, Object>) templatesUsedObj;
                formatted += '\nTemplates Used:\n';
                formatted += '---------------\n';
                
                Object faithfulnessTemplate = templatesUsed.get('faithfulness');
                if (faithfulnessTemplate != null) {
                    formatted += 'Faithfulness: ' + String.valueOf(faithfulnessTemplate) + '\n';
                }
                
                Object relevancyTemplate = templatesUsed.get('relevancy');
                if (relevancyTemplate != null) {
                    formatted += 'Relevancy: ' + String.valueOf(relevancyTemplate) + '\n';
                }
                
                Object contextTemplate = templatesUsed.get('context_quality');
                if (contextTemplate != null) {
                    formatted += 'Context Quality: ' + String.valueOf(contextTemplate) + '\n';
                }
            }
            
            // Error Information
            Object errorsObj = response.get('errors');
            if (errorsObj instanceof List<Object>) {
                List<Object> errors = (List<Object>) errorsObj;
                if (!errors.isEmpty()) {
                    formatted += '\nErrors Encountered:\n';
                    formatted += '-------------------\n';
                    for (Integer i = 0; i < errors.size(); i++) {
                        formatted += '• ' + String.valueOf(errors[i]) + '\n';
                    }
                }
            }
            
            return formatted;
            
        } catch (Exception e) {
            System.debug('Error formatting quality assessment details: ' + e.getMessage());
            return 'Error formatting quality assessment details:\n' + e.getMessage() + '\n\nRaw Response:\n' + jsonResponse;
        }
    }
}
