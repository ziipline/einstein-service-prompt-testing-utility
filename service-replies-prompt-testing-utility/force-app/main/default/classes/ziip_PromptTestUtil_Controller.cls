public with sharing class ziip_PromptTestUtil_Controller {
    
    @AuraEnabled
    public static Map<String, Object> getMessagingSessions(
        Integer pageSize, 
        Integer pageNumber, 
        Date startDate, 
        Date endDate, 
        String sessionName,
        String status
    ) {
        // Calculate offset for pagination
        Integer offset = (pageNumber - 1) * pageSize;
        
        // Build dynamic WHERE clause
        String whereClause = 'ConversationId != null';
        
        if (startDate != null) {
            whereClause += ' AND CreatedDate >= :startDate';
        }
        
        if (endDate != null) {
            whereClause += ' AND CreatedDate <= :endDate';
        }
        
        if (String.isNotBlank(sessionName)) {
            String searchPattern = '%' + sessionName + '%';
            whereClause += ' AND Name LIKE :searchPattern';
        }
        
        if (String.isNotBlank(status)) {
            whereClause += ' AND Status = :status';
        }
        
        // Get total count first
        String countQuery = 'SELECT COUNT() FROM MessagingSession WHERE ' + whereClause;
        Integer totalCount = Database.countQuery(countQuery);
        
        // Get paginated MessagingSessions with their associated Conversations
        String mainQuery = 'SELECT Id, Name, ConversationId, Conversation.ConversationIdentifier, CreatedDate, Status, EndUserLanguage ' +
                          'FROM MessagingSession ' +
                          'WHERE ' + whereClause + ' ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT :pageSize OFFSET :offset';
        
        List<MessagingSession> sessions = Database.query(mainQuery);
        
        List<Map<String, Object>> sessionData = new List<Map<String, Object>>();
        for (MessagingSession session : sessions) {
            String transcript = '';
            
            // Fetch conversation entries via Connect API
            if (session.Conversation != null && session.Conversation.ConversationIdentifier != null) {
                transcript = getConversationEntries(session.Conversation.ConversationIdentifier);
            }
            
            sessionData.add(new Map<String, Object>{
                'Id' => session.Id,
                'Name' => session.Name,
                'transcript' => transcript
            });
        }
        
        // Calculate pagination info
        Integer totalPages = (Integer) Math.ceil((Decimal) totalCount / pageSize);
        Boolean hasNext = pageNumber < totalPages;
        Boolean hasPrevious = pageNumber > 1;
        
        return new Map<String, Object>{
            'sessions' => sessionData,
            'pagination' => new Map<String, Object>{
                'totalCount' => totalCount,
                'totalPages' => totalPages,
                'currentPage' => pageNumber,
                'pageSize' => pageSize,
                'hasNext' => hasNext,
                'hasPrevious' => hasPrevious
            }
        };
    }
    
    public static String getConversationEntries(String conversationIdentifier) {
        try {
            // Use Named Credential for Connect API authentication
            String endpoint = 'callout:Salesforce_Connect_API/services/data/v62.0/connect/conversation/' + conversationIdentifier + '/entries';
            
            // Make HTTP callout to Connect API using Named Credential
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('Raw response body: ' + responseBody);
                
                try {
                    // Try to parse as JSON first
                    Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    System.debug('Parsed JSON response: ' + jsonResponse);
                    
                    // Handle the actual Connect API response structure
                    if (jsonResponse.containsKey('conversationEntries')) {
                        List<Object> entries = (List<Object>) jsonResponse.get('conversationEntries');
                        if (entries != null && !entries.isEmpty()) {
                            List<String> formattedEntries = new List<String>();
                            
                            // Reverse the entries to show oldest first (they come in newest first)
                            for (Integer i = entries.size() - 1; i >= 0; i--) {
                                Map<String, Object> entry = (Map<String, Object>) entries[i];
                                
                                // Extract message text
                                String message = (String) entry.get('messageText');
                                if (String.isNotBlank(message)) {
                                    // Decode HTML entities
                                    message = message.replace('&#39;', '\'').replace('&quot;', '"').replace('&amp;', '&');
                                }
                                
                                // Extract timestamp (clientTimestamp is in milliseconds)
                                Long clientTimestamp = (Long) entry.get('clientTimestamp');
                                String formattedTimestamp = '';
                                if (clientTimestamp != null) {
                                    DateTime dt = DateTime.newInstance(clientTimestamp);
                                    formattedTimestamp = dt.format('MM/dd/yyyy HH:mm:ss');
                                }
                                
                                // Extract sender information
                                String senderRole = '';
                                String senderType = '';
                                Map<String, Object> sender = (Map<String, Object>) entry.get('sender');
                                if (sender != null) {
                                    senderRole = (String) sender.get('role');
                                    senderType = (String) sender.get('appType');
                                }
                                
                                // Build formatted entry
                                if (String.isNotBlank(message)) {
                                    String formattedEntry = '';
                                    
                                    // Add timestamp
                                    if (String.isNotBlank(formattedTimestamp)) {
                                        formattedEntry += '[' + formattedTimestamp + '] ';
                                    }
                                    
                                    // Add sender information
                                    if (String.isNotBlank(senderRole)) {
                                        if (senderRole == 'EndUser') {
                                            formattedEntry += 'Customer';
                                        } else if (senderRole == 'Chatbot') {
                                            formattedEntry += 'AI Assistant';
                                        } else {
                                            formattedEntry += senderRole;
                                        }
                                        
                                        if (String.isNotBlank(senderType)) {
                                            formattedEntry += ' (' + senderType + ')';
                                        }
                                        formattedEntry += ': ';
                                    }
                                    
                                    // Add the message
                                    formattedEntry += message;
                                    
                                    formattedEntries.add(formattedEntry);
                                }
                            }
                            System.debug('Formatted entries: ' + formattedEntries);
                            return String.join(formattedEntries, '\n');
                        }
                    } else {
                        // If no entries field, maybe the response is the message directly
                        return responseBody;
                    }
                } catch (Exception jsonEx) {
                    System.debug('JSON parsing failed: ' + jsonEx.getMessage());
                    // If JSON parsing fails, return the raw response
                    return responseBody;
                }
            } else {
                System.debug('Connect API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception in getConversationEntries: ' + e.getMessage());
        }
        
        return '';
    }
    
    private static String formatTimestamp(String timestamp) {
        try {
            // Try to parse and format the timestamp
            if (String.isNotBlank(timestamp)) {
                // Handle ISO datetime format
                if (timestamp.contains('T')) {
                    DateTime dt = DateTime.valueOfGmt(timestamp.replace('T', ' ').replace('Z', ''));
                    return dt.format('MM/dd/yyyy HH:mm:ss');
                }
                // If it's already a readable format, return as-is
                return timestamp;
            }
        } catch (Exception e) {
            System.debug('Timestamp parsing failed: ' + e.getMessage());
        }
        return timestamp;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getStatusOptions() {
        List<Map<String, String>> statusOptions = new List<Map<String, String>>();
        
        // Add "All" option
        statusOptions.add(new Map<String, String>{
            'label' => 'All',
            'value' => ''
        });
        
        // Get distinct status values from MessagingSession
        List<AggregateResult> statusResults = [
            SELECT Status, COUNT(Id) cnt
            FROM MessagingSession 
            WHERE Status != null AND ConversationId != null
            GROUP BY Status
            ORDER BY Status
        ];
        
        for (AggregateResult result : statusResults) {
            String status = (String) result.get('Status');
            if (String.isNotBlank(status)) {
                statusOptions.add(new Map<String, String>{
                    'label' => status,
                    'value' => status
                });
            }
        }
        
        return statusOptions;
    }


    @AuraEnabled
    public static Map<String, Object> getPromptTemplates(
        Integer pageSize, 
        Integer pageNumber,
        String templateName,
        String templateType,
        String templateStatus
    ) {
        try {
            System.debug('Starting getPromptTemplates - Page: ' + pageNumber + ', PageSize: ' + pageSize);
            
            // Fetch all templates at once with pageLimit=200
            String endpoint = 'callout:Salesforce_Connect_API/services/data/v62.0/einstein/prompt-templates';
            endpoint += '?pageLimit=200';
            
            System.debug('HTTP API endpoint: ' + endpoint);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            List<Map<String, Object>> allTemplates = new List<Map<String, Object>>();
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('API Response received: ' + (jsonResponse.containsKey('promptRecords') ? ((List<Object>) jsonResponse.get('promptRecords')).size() + ' templates' : 'No promptRecords'));
                
                // Process promptRecords from response
                if (jsonResponse.containsKey('promptRecords')) {
                    List<Object> templates = (List<Object>) jsonResponse.get('promptRecords');
                    
                    if (templates != null) {
                        System.debug('Processing ' + templates.size() + ' templates from API');
                        
                        for (Object templateObj : templates) {
                            Map<String, Object> template = (Map<String, Object>) templateObj;
                            Map<String, Object> fields = (Map<String, Object>) template.get('fields');
                            
                            if (fields != null) {
                                // Extract template data from nested fields structure
                                String templateId = extractFieldValue(fields, 'Id');
                                if (String.isBlank(templateId)) {
                                    templateId = extractFieldValue(fields, 'DeveloperName');
                                }
                                
                                String name = extractFieldValue(fields, 'MasterLabel');
                                String currentTemplateType = extractFieldValue(fields, 'Type');
                                String isActiveStr = extractFieldValue(fields, 'IsActive');
                                Boolean isActive = isActiveStr == 'true' ? true : false;
                                String status = isActive ? 'Active' : 'Inactive';
                                String description = extractFieldValue(fields, 'Description');
                                
                                allTemplates.add(new Map<String, Object>{
                                    'Id' => templateId,
                                    'Name' => name,
                                    'TemplateType' => currentTemplateType,
                                    'Status' => status
                                });
                            }
                        }
                    }
                }
                
            } else {
                System.debug('API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
            // Extract unique template types for filter options
            Set<String> uniqueTypes = new Set<String>();
            for (Map<String, Object> template : allTemplates) {
                String templateTypeValue = (String) template.get('TemplateType');
                if (String.isNotBlank(templateTypeValue)) {
                    uniqueTypes.add(templateTypeValue);
                }
            }
            
            // Convert to sorted list of filter options
            List<String> sortedTypes = new List<String>(uniqueTypes);
            sortedTypes.sort();
            
            List<Map<String, String>> templateTypeOptions = new List<Map<String, String>>();
            templateTypeOptions.add(new Map<String, String>{
                'label' => 'All Types',
                'value' => ''
            });
            
            for (String templateTypeValue : sortedTypes) {
                templateTypeOptions.add(new Map<String, String>{
                    'label' => templateTypeValue,
                    'value' => templateTypeValue
                });
            }
            
            // Apply client-side filtering to all templates
            List<Map<String, Object>> filteredTemplates = applyTemplateFilters(allTemplates, templateName, templateType, templateStatus);
            
            // Apply client-side pagination to filtered results
            Integer filteredTotalCount = filteredTemplates.size();
            Integer startIndex = (pageNumber - 1) * pageSize;
            Integer endIndex = Math.min(startIndex + pageSize, filteredTotalCount);
            
            List<Map<String, Object>> paginatedTemplates = new List<Map<String, Object>>();
            if (startIndex < filteredTotalCount) {
                for (Integer i = startIndex; i < endIndex; i++) {
                    paginatedTemplates.add(filteredTemplates[i]);
                }
            }
            
            // Calculate pagination info based on filtered results
            Integer totalPages = pageSize > 0 ? (Integer) Math.ceil((Decimal) filteredTotalCount / pageSize) : 1;
            Boolean hasNext = (startIndex + pageSize) < filteredTotalCount;
            Boolean hasPrevious = pageNumber > 1;
            
            System.debug('Client-side pagination - Total: ' + allTemplates.size() + ', Filtered: ' + filteredTotalCount + ', Page: ' + pageNumber + '/' + totalPages + ', Returned: ' + paginatedTemplates.size());
            
            return new Map<String, Object>{
                'templates' => paginatedTemplates,
                'templateTypeOptions' => templateTypeOptions,
                'pagination' => new Map<String, Object>{
                    'totalCount' => filteredTotalCount,
                    'totalPages' => totalPages,
                    'currentPage' => pageNumber,
                    'pageSize' => pageSize,
                    'hasNext' => hasNext,
                    'hasPrevious' => hasPrevious
                }
            };
            
        } catch (Exception e) {
            System.debug('Exception in getPromptTemplates: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new Map<String, Object>{
                'templates' => new List<Map<String, Object>>(),
                'pagination' => new Map<String, Object>{
                    'totalCount' => 0,
                    'totalPages' => 1,
                    'currentPage' => 1,
                    'pageSize' => pageSize,
                    'hasNext' => false,
                    'hasPrevious' => false
                }
            };
        }
    }
    
    
    private static String extractFieldValue(Map<String, Object> fields, String fieldName) {
        if (fields != null && fields.containsKey(fieldName)) {
            Map<String, Object> fieldData = (Map<String, Object>) fields.get(fieldName);
            if (fieldData != null && fieldData.containsKey('value')) {
                Object value = fieldData.get('value');
                return value != null ? String.valueOf(value) : null;
            }
        }
        return null;
    }
    
    private static List<Map<String, Object>> applyTemplateFilters(
        List<Map<String, Object>> templates,
        String templateName,
        String templateType,
        String templateStatus
    ) {
        List<Map<String, Object>> filteredTemplates = new List<Map<String, Object>>();
        
        for (Map<String, Object> template : templates) {
            Boolean matches = true;
            
            // Filter by template name (case-insensitive contains)
            if (String.isNotBlank(templateName)) {
                String name = (String) template.get('Name');
                if (String.isBlank(name) || !name.toLowerCase().contains(templateName.toLowerCase())) {
                    matches = false;
                }
            }
            
            // Filter by template type (exact match)
            if (String.isNotBlank(templateType) && matches) {
                String type = (String) template.get('TemplateType');
                if (String.isBlank(type) || !type.equals(templateType)) {
                    matches = false;
                }
            }
            
            // Filter by template status (exact match)
            if (String.isNotBlank(templateStatus) && matches) {
                String status = (String) template.get('Status');
                if (String.isBlank(status) || !status.equals(templateStatus)) {
                    matches = false;
                }
            }
            
            if (matches) {
                filteredTemplates.add(template);
            }
        }
        
        return filteredTemplates;
    }

    
    @AuraEnabled
    public static Map<String, Object> getCases(
        Integer pageSize, 
        Integer pageNumber, 
        Date startDate, 
        Date endDate, 
        String subject,
        String status
    ) {
        try {
            // Calculate offset for pagination
            Integer offset = (pageNumber - 1) * pageSize;
            
            // Build dynamic WHERE clause conditions
            List<String> conditions = new List<String>();
            
            if (startDate != null) {
                conditions.add('CreatedDate >= :startDate');
            }
            
            if (endDate != null) {
                conditions.add('CreatedDate <= :endDate');
            }
            
            if (String.isNotBlank(subject)) {
                String searchPattern = '%' + subject + '%';
                conditions.add('Subject LIKE :searchPattern');
            }
            
            if (String.isNotBlank(status)) {
                conditions.add('Status = :status');
            }
            
            // Build WHERE clause
            String whereClause = conditions.isEmpty() ? '' : 'WHERE ' + String.join(conditions, ' AND ');
            
            // Get total count first
            String countQuery = 'SELECT COUNT() FROM Case ' + whereClause;
            Integer totalCount = Database.countQuery(countQuery);
            
            // Get paginated Cases
            String mainQuery = 'SELECT Id, CaseNumber, Subject, Status, CreatedDate, Priority, Origin ' +
                              'FROM Case ' +
                              whereClause + ' ' +
                              'ORDER BY CreatedDate DESC ' +
                              'LIMIT :pageSize OFFSET :offset';
            
            List<Case> cases = Database.query(mainQuery);
            
            List<Map<String, Object>> caseData = new List<Map<String, Object>>();
            for (Case caseRecord : cases) {
                caseData.add(new Map<String, Object>{
                    'Id' => caseRecord.Id,
                    'CaseNumber' => caseRecord.CaseNumber,
                    'Subject' => caseRecord.Subject,
                    'Status' => caseRecord.Status,
                    'CreatedDate' => caseRecord.CreatedDate,
                    'Priority' => caseRecord.Priority,
                    'Origin' => caseRecord.Origin
                });
            }
            
            // Calculate pagination info
            Integer totalPages = (Integer) Math.ceil((Decimal) totalCount / pageSize);
            Boolean hasNext = pageNumber < totalPages;
            Boolean hasPrevious = pageNumber > 1;
            
            return new Map<String, Object>{
                'cases' => caseData,
                'pagination' => new Map<String, Object>{
                    'totalCount' => totalCount,
                    'totalPages' => totalPages,
                    'currentPage' => pageNumber,
                    'pageSize' => pageSize,
                    'hasNext' => hasNext,
                    'hasPrevious' => hasPrevious
                }
            };
            
        } catch (Exception e) {
            System.debug('Exception in getCases: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new Map<String, Object>{
                'cases' => new List<Map<String, Object>>(),
                'pagination' => new Map<String, Object>{
                    'totalCount' => 0,
                    'totalPages' => 1,
                    'currentPage' => 1,
                    'pageSize' => pageSize,
                    'hasNext' => false,
                    'hasPrevious' => false
                },
                'error' => e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Map<String, Object> getVoiceCalls(
        Integer pageSize, 
        Integer pageNumber, 
        Date startDate, 
        Date endDate, 
        String callType,
        String status
    ) {
        // Calculate offset for pagination
        Integer offset = (pageNumber - 1) * pageSize;
        
        // Build dynamic WHERE clause
        String whereClause = '1=1';
        
        if (startDate != null) {
            whereClause += ' AND CreatedDate >= :startDate';
        }
        
        if (endDate != null) {
            whereClause += ' AND CreatedDate <= :endDate';
        }
        
        if (String.isNotBlank(callType)) {
            whereClause += ' AND CallType = :callType';
        }
        
        if (String.isNotBlank(status)) {
            whereClause += ' AND VendorCallKey != null'; // Basic filtering for valid calls
        }
        
        // Get total count first
        String countQuery = 'SELECT COUNT() FROM VoiceCall WHERE ' + whereClause;
        Integer totalCount = Database.countQuery(countQuery);
        
        // Get paginated Voice Calls
        String mainQuery = 'SELECT Id, Name, CallStartDateTime, CallEndDateTime, CallType, CallDurationInSeconds, FromPhoneNumber, ToPhoneNumber ' +
                          'FROM VoiceCall ' +
                          'WHERE ' + whereClause + ' ' +
                          'ORDER BY CallStartDateTime DESC ' +
                          'LIMIT :pageSize OFFSET :offset';
        
        List<VoiceCall> voiceCalls = Database.query(mainQuery);
        
        List<Map<String, Object>> voiceCallData = new List<Map<String, Object>>();
        for (VoiceCall voiceCall : voiceCalls) {
            voiceCallData.add(new Map<String, Object>{
                'Id' => voiceCall.Id,
                'Name' => voiceCall.Name,
                'CallStartDateTime' => voiceCall.CallStartDateTime,
                'CallEndDateTime' => voiceCall.CallEndDateTime,
                'CallType' => voiceCall.CallType,
                'CallDurationInSeconds' => voiceCall.CallDurationInSeconds,
                'FromPhoneNumber' => voiceCall.FromPhoneNumber,
                'ToPhoneNumber' => voiceCall.ToPhoneNumber
            });
        }
        
        // Calculate pagination info
        Integer totalPages = (Integer) Math.ceil((Decimal) totalCount / pageSize);
        Boolean hasNext = pageNumber < totalPages;
        Boolean hasPrevious = pageNumber > 1;
        
        return new Map<String, Object>{
            'voiceCalls' => voiceCallData,
            'pagination' => new Map<String, Object>{
                'totalCount' => totalCount,
                'totalPages' => totalPages,
                'currentPage' => pageNumber,
                'pageSize' => pageSize,
                'hasNext' => hasNext,
                'hasPrevious' => hasPrevious
            }
        };
    }

    @AuraEnabled
    public static Map<String, Object> createAdvancedTestBatch(
        String testType,
        List<String> recordIds,
        String primaryTemplateId,
        String secondaryTemplateId,
        String retrieverId
    ) {
        // Validate test type
        if (String.isBlank(testType)) {
            throw new IllegalArgumentException('Test type is required');
        }
        
        if (recordIds == null || recordIds.isEmpty()) {
            throw new IllegalArgumentException('At least one record ID is required');
        }
        
        if (String.isBlank(primaryTemplateId)) {
            throw new IllegalArgumentException('Primary template ID is required');
        }
        
        // Validate templates based on test type
        if (testType == 'Service Replies' && String.isBlank(secondaryTemplateId)) {
            throw new IllegalArgumentException('Secondary template ID is required for Service Replies');
        }
        
        return createTestBatchForType(testType, recordIds, primaryTemplateId, secondaryTemplateId, retrieverId);
    }

    private static Map<String, Object> createTestBatchForType(
        String testType,
        List<String> recordIds,
        String primaryTemplateId,
        String secondaryTemplateId,
        String retrieverId
    ) {
        if (testType == 'Service Replies') {
            return createServiceRepliesTests(recordIds, primaryTemplateId, secondaryTemplateId, retrieverId);
        } else if (testType == 'Case Summary') {
            return createCaseSummaryTests(recordIds, primaryTemplateId, testType);
        } else if (testType == 'Work Summary') {
            return createWorkSummaryTests(recordIds, primaryTemplateId, testType);
        } else {
            throw new IllegalArgumentException('Unsupported test type: ' + testType);
        }
    }

    private static Map<String, Object> createServiceRepliesTests(
        List<String> sessionIds,
        String primaryTemplateId,
        String secondaryTemplateId,
        String retrieverId
    ) {
        // STEP 1: Perform all callouts first (before any DML operations)
        Map<Id, List<Map<String, Object>>> sessionUtterancesMap = new Map<Id, List<Map<String, Object>>>();
        Integer totalCustomerUtterances = 0;
        Integer sessionsProcessed = 0;
        Integer sessionsSkipped = 0;
        
        // Get session data for all sessions
        Map<Id, MessagingSession> sessionsById = new Map<Id, MessagingSession>([
            SELECT Id, Name, ConversationId, Conversation.ConversationIdentifier
            FROM MessagingSession 
            WHERE Id IN :sessionIds
        ]);
        
        // Process each messaging session to get customer utterances via callouts
        for (Id sessionId : sessionIds) {
            try {
                MessagingSession session = sessionsById.get(sessionId);
                
                if (session == null || session.Conversation == null) {
                    sessionsSkipped++;
                    continue;
                }
                
                String conversationIdentifier = session.Conversation.ConversationIdentifier;
                
                // Get the full conversation transcript
                String fullTranscript = getConversationEntries(conversationIdentifier);
                
                if (String.isBlank(fullTranscript)) {
                    sessionsSkipped++;
                    continue;
                }
                
                // Parse the transcript to find customer utterances
                List<Map<String, Object>> customerUtterances = parseCustomerUtterances(conversationIdentifier);
                
                if (customerUtterances.isEmpty()) {
                    sessionsSkipped++;
                    continue;
                }
                
                // Store utterances for this session
                sessionUtterancesMap.put(sessionId, customerUtterances);
                totalCustomerUtterances += customerUtterances.size();
                sessionsProcessed++;
                
            } catch (Exception e) {
                System.debug('Error processing session ' + sessionId + ': ' + e.getMessage());
                sessionsSkipped++;
            }
        }
        
        // STEP 2: Perform all DML operations after callouts are complete
        
        // Create the test batch - populate template fields for visibility
        Prompt_Test_Batch__c testBatch = new Prompt_Test_Batch__c(
            Test_Type__c = 'Service Replies',
            Status__c = 'Pending',
            Retriever_Id__c = retrieverId,
            Contextual_Template_Id__c = primaryTemplateId,
            Grounded_Template_Id__c = secondaryTemplateId
        );
        insert testBatch;
        
        // Create test records - each customer utterance gets TWO test records (contextual + grounded)
        List<Prompt_Test__c> tests = new List<Prompt_Test__c>();
        for (Id sessionId : sessionUtterancesMap.keySet()) {
            List<Map<String, Object>> customerUtterances = sessionUtterancesMap.get(sessionId);
            Integer utteranceSequence = 1;
            
            for (Map<String, Object> utterance : customerUtterances) {
                String customerMessage = (String) utterance.get('message');
                String cumulativeTranscript = (String) utterance.get('cumulativeTranscript');
                
                // Create contextual test record
                Prompt_Test__c contextualTest = new Prompt_Test__c(
                    Prompt_Test_Batch__c = testBatch.Id,
                    Messaging_Session__c = sessionId,
                    Status__c = 'Pending',
                    Customer_Utterance__c = customerMessage,
                    Utterance_Sequence__c = utteranceSequence,
                    Transcript__c = cumulativeTranscript,
                    Template_Id__c = primaryTemplateId,
                    Template_Type__c = 'Service Reply - Contextual',
                    Related_Test__c = null
                );
                tests.add(contextualTest);
                
                // Create grounded test record (will be linked after contextual test is inserted)
                Prompt_Test__c groundedTest = new Prompt_Test__c(
                    Prompt_Test_Batch__c = testBatch.Id,
                    Messaging_Session__c = sessionId,
                    Status__c = 'Pending',
                    Customer_Utterance__c = customerMessage,
                    Utterance_Sequence__c = utteranceSequence,
                    Transcript__c = cumulativeTranscript,
                    Template_Id__c = secondaryTemplateId,
                    Template_Type__c = 'Service Reply - Grounded',
                    Related_Test__c = null // Will be set after contextual test is inserted
                );
                tests.add(groundedTest);
                
                utteranceSequence++;
            }
        }
        
        // Insert all test records
        if (!tests.isEmpty()) {
            insert tests;
            
            // Now link grounded tests to their contextual tests
            List<Prompt_Test__c> testsToUpdate = new List<Prompt_Test__c>();
            for (Integer i = 0; i < tests.size(); i += 2) {
                Prompt_Test__c contextualTest = tests[i];
                Prompt_Test__c groundedTest = tests[i + 1];
                
                // Link grounded test to contextual test
                groundedTest.Related_Test__c = contextualTest.Id;
                testsToUpdate.add(groundedTest);
            }
            
            if (!testsToUpdate.isEmpty()) {
                update testsToUpdate;
            }
        }
        
        return new Map<String, Object>{
            'batchId' => testBatch.Id,
            'testRecordsCreated' => tests.size(),
            'sessionsProcessed' => sessionsProcessed,
            'sessionsSkipped' => sessionsSkipped,
            'totalCustomerUtterances' => totalCustomerUtterances,
            'testType' => 'Service Replies'
        };
    }
    
    private static List<Map<String, Object>> parseCustomerUtterances(String conversationIdentifier) {
        List<Map<String, Object>> customerUtterances = new List<Map<String, Object>>();
        
        try {
            System.debug('=== parseCustomerUtterances DEBUG START ===');
            System.debug('Conversation Identifier: ' + conversationIdentifier);
            
            String endpoint = 'callout:Salesforce_Connect_API/services/data/v62.0/connect/conversation/' + conversationIdentifier + '/entries';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('Raw response body: ' + responseBody);
                
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                if (jsonResponse.containsKey('conversationEntries')) {
                    List<Object> entries = (List<Object>) jsonResponse.get('conversationEntries');
                    System.debug('Total conversation entries found: ' + (entries != null ? entries.size() : 0));
                    
                    if (entries != null && !entries.isEmpty()) {
                        // Reverse entries to get chronological order (oldest first)
                        List<Object> chronologicalEntries = new List<Object>();
                        for (Integer i = entries.size() - 1; i >= 0; i--) {
                            chronologicalEntries.add(entries[i]);
                        }
                        
                        List<String> cumulativeEntries = new List<String>();
                        Integer entryIndex = 0;
                        
                        // Process each entry to build cumulative transcript
                        for (Object entryObj : chronologicalEntries) {
                            Map<String, Object> entry = (Map<String, Object>) entryObj;
                            System.debug('Processing entry #' + entryIndex + ': ' + entry);
                            
                            String message = (String) entry.get('messageText');
                            if (String.isBlank(message)) {
                                System.debug('Skipping entry #' + entryIndex + ' - no message text');
                                entryIndex++;
                                continue;
                            }
                            
                            // Decode HTML entities
                            message = message.replace('&#39;', '\'').replace('&quot;', '"').replace('&amp;', '&');
                            
                            // Extract timestamp
                            Long clientTimestamp = (Long) entry.get('clientTimestamp');
                            String formattedTimestamp = '';
                            if (clientTimestamp != null) {
                                DateTime dt = DateTime.newInstance(clientTimestamp);
                                formattedTimestamp = dt.format('MM/dd/yyyy HH:mm:ss');
                            }
                            
                            // Extract sender information with detailed logging
                            String senderRole = '';
                            Map<String, Object> sender = (Map<String, Object>) entry.get('sender');
                            System.debug('Entry #' + entryIndex + ' sender object: ' + sender);
                            
                            if (sender != null) {
                                senderRole = (String) sender.get('role');
                                System.debug('Entry #' + entryIndex + ' sender role: "' + senderRole + '"');
                                
                                // Log all sender properties for debugging
                                System.debug('Entry #' + entryIndex + ' sender keys: ' + sender.keySet());
                                for (String key : sender.keySet()) {
                                    System.debug('Entry #' + entryIndex + ' sender.' + key + ' = ' + sender.get(key));
                                }
                            }
                            
                            // Build formatted entry
                            String formattedEntry = '';
                            if (String.isNotBlank(formattedTimestamp)) {
                                formattedEntry += '[' + formattedTimestamp + '] ';
                            }
                            
                            // Check for customer roles with multiple variations
                            Boolean isCustomerMessage = false;
                            if (String.isNotBlank(senderRole)) {
                                String normalizedRole = senderRole.toLowerCase().trim();
                                if (normalizedRole == 'enduser' || 
                                    normalizedRole == 'end user' || 
                                    normalizedRole == 'customer' ||
                                    normalizedRole == 'user' ||
                                    normalizedRole.contains('customer') ||
                                    normalizedRole.contains('end') && normalizedRole.contains('user')) {
                                    isCustomerMessage = true;
                                    formattedEntry += 'Customer: ';
                                } else if (normalizedRole == 'chatbot' || 
                                           normalizedRole == 'bot' || 
                                           normalizedRole == 'ai' ||
                                           normalizedRole.contains('bot')) {
                                    formattedEntry += 'AI Assistant: ';
                                } else {
                                    formattedEntry += senderRole + ': ';
                                }
                            } else {
                                formattedEntry += 'Unknown: ';
                            }
                            
                            formattedEntry += message;
                            cumulativeEntries.add(formattedEntry);
                            
                            System.debug('Entry #' + entryIndex + ' isCustomerMessage: ' + isCustomerMessage);
                            
                            // If this is a customer message, create a customer utterance record
                            if (isCustomerMessage) {
                                System.debug('Adding customer utterance: "' + message + '"');
                                customerUtterances.add(new Map<String, Object>{
                                    'message' => message,
                                    'cumulativeTranscript' => String.join(cumulativeEntries, '\n')
                                });
                            }
                            
                            entryIndex++;
                        }
                        
                        System.debug('Final customer utterances count: ' + customerUtterances.size());
                    }
                } else {
                    System.debug('No conversationEntries found in response. Available keys: ' + jsonResponse.keySet());
                }
            } else {
                System.debug('API call failed with status: ' + res.getStatusCode() + ', body: ' + res.getBody());
            }
            
            System.debug('=== parseCustomerUtterances DEBUG END ===');
        } catch (Exception e) {
            System.debug('Exception in parseCustomerUtterances: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return customerUtterances;
    }

    private static Map<String, Object> createCaseSummaryTests(
        List<String> caseIds,
        String templateId,
        String testType
    ) {
        // Create the test batch first
        Prompt_Test_Batch__c testBatch = new Prompt_Test_Batch__c(
            Test_Type__c = testType,
            Status__c = 'Pending'
        );
        insert testBatch;
        
        List<Prompt_Test__c> tests = new List<Prompt_Test__c>();
        Integer casesProcessed = 0;
        Integer casesSkipped = 0;
        
        // Get case data for all cases
        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT Id, CaseNumber, Subject, Status, CreatedDate, Priority, Origin
            FROM Case 
            WHERE Id IN :caseIds
        ]);
        
        // Create test records for each case
        for (String caseId : caseIds) {
            try {
                Case caseRecord = casesById.get(caseId);
                
                if (caseRecord == null) {
                    casesSkipped++;
                    continue;
                }
                
                tests.add(new Prompt_Test__c(
                    Prompt_Test_Batch__c = testBatch.Id,
                    Case__c = caseId,
                    Status__c = 'Pending',
                    Template_Id__c = templateId,
                    Template_Type__c = 'Case Summary'
                ));
                
                casesProcessed++;
                
            } catch (Exception e) {
                System.debug('Error processing case ' + caseId + ': ' + e.getMessage());
                casesSkipped++;
            }
        }
        
        // Insert all test records
        if (!tests.isEmpty()) {
            insert tests;
        }
        
        return new Map<String, Object>{
            'batchId' => testBatch.Id,
            'testRecordsCreated' => tests.size(),
            'recordsProcessed' => casesProcessed,
            'recordsSkipped' => casesSkipped,
            'testType' => testType
        };
    }

    private static Map<String, Object> createWorkSummaryTests(
        List<String> recordIds,
        String templateId,
        String testType
    ) {
        // Create the test batch first
        Prompt_Test_Batch__c testBatch = new Prompt_Test_Batch__c(
            Test_Type__c = testType,
            Status__c = 'Pending'
        );
        insert testBatch;
        
        List<Prompt_Test__c> tests = new List<Prompt_Test__c>();
        Integer recordsProcessed = 0;
        Integer recordsSkipped = 0;
        
        // Determine if these are MessagingSession or VoiceCall IDs by checking first record
        String objectType = 'MessagingSession'; // Default assumption
        if (!recordIds.isEmpty()) {
            String firstId = recordIds[0];
            if (firstId.startsWith('0LG') || firstId.startsWith('0lg')) { // VoiceCall prefix pattern
                objectType = 'VoiceCall';
            }
        }
        
        if (objectType == 'MessagingSession') {
            // Handle messaging sessions
            Map<Id, MessagingSession> sessionsById = new Map<Id, MessagingSession>([
                SELECT Id, Name, ConversationId, Conversation.ConversationIdentifier
                FROM MessagingSession 
                WHERE Id IN :recordIds
            ]);
            
            for (String sessionId : recordIds) {
                try {
                    MessagingSession session = sessionsById.get(sessionId);
                    
                    if (session == null) {
                        recordsSkipped++;
                        continue;
                    }
                    
                    tests.add(new Prompt_Test__c(
                        Prompt_Test_Batch__c = testBatch.Id,
                        Messaging_Session__c = sessionId,
                        Status__c = 'Pending',
                        Template_Id__c = templateId,
                        Template_Type__c = 'Work Summary'
                    ));
                    
                    recordsProcessed++;
                    
                } catch (Exception e) {
                    System.debug('Error processing messaging session ' + sessionId + ': ' + e.getMessage());
                    recordsSkipped++;
                }
            }
        } else {
            // Handle voice calls
            Map<Id, VoiceCall> voiceCallsById = new Map<Id, VoiceCall>([
                SELECT Id, Name, CallStartDateTime, CallEndDateTime, CallType
                FROM VoiceCall 
                WHERE Id IN :recordIds
            ]);
            
            for (String voiceCallId : recordIds) {
                try {
                    VoiceCall voiceCall = voiceCallsById.get(voiceCallId);
                    
                    if (voiceCall == null) {
                        recordsSkipped++;
                        continue;
                    }
                    
                    tests.add(new Prompt_Test__c(
                        Prompt_Test_Batch__c = testBatch.Id,
                        Voice_Call__c = voiceCallId,
                        Status__c = 'Pending',
                        Template_Id__c = templateId,
                        Template_Type__c = 'Work Summary'
                    ));
                    
                    recordsProcessed++;
                    
                } catch (Exception e) {
                    System.debug('Error processing voice call ' + voiceCallId + ': ' + e.getMessage());
                    recordsSkipped++;
                }
            }
        }
        
        // Insert all test records
        if (!tests.isEmpty()) {
            insert tests;
        }
        
        return new Map<String, Object>{
            'batchId' => testBatch.Id,
            'testRecordsCreated' => tests.size(),
            'recordsProcessed' => recordsProcessed,
            'recordsSkipped' => recordsSkipped,
            'testType' => testType,
            'dataSourceType' => objectType
        };
    }
    
}
