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
     * @description Extracts JSON content from markdown code blocks
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
    
    /**
     * @description Extracts scores from plain text using keyword matching
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
        
        // Look for score keywords followed by numbers
        List<String> scoreKeywords = new List<String>{
            'score:', 'score', 'rating:', 'rating', 'faithfulness:', 'faithfulness', 
            'relevancy:', 'relevancy', 'relevance:', 'relevance'
        };
        
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
     * @description Determines the appropriate score field name based on template ID
     * @param templateId Template ID to analyze
     * @return String score field name
     */
    public static String determineScoreField(String templateId) {
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
     * @description Parses faithfulness score from response
     * @param response Response map to parse
     * @return Decimal faithfulness score
     */
    public static Decimal parseFaithfulnessScore(Map<String, Object> response) {
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
    
    /**
     * @description Parses relevancy score from response
     * @param response Response map to parse
     * @return Decimal relevancy score
     */
    public static Decimal parseRelevancyScore(Map<String, Object> response) {
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
    
    /**
     * @description Parses context quality score from response
     * @param response Response map to parse
     * @return Decimal context quality score
     */
    public static Decimal parseContextQualityScore(Map<String, Object> response) {
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
