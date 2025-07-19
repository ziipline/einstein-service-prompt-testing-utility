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
    public static Id createTestBatch(List<Id> sessionIds) {
        Prompt_Test_Batch__c testBatch = new Prompt_Test_Batch__c(
            Status__c = 'Pending'
        );
        insert testBatch;

        List<Prompt_Test__c> tests = new List<Prompt_Test__c>();
        for (Id sessionId : sessionIds) {
            tests.add(new Prompt_Test__c(
                Prompt_Test_Batch__c = testBatch.Id,
                Messaging_Session__c = sessionId,
                Status__c = 'Pending'
            ));
        }
        insert tests;
        
        return testBatch.Id;
    }
    
    @AuraEnabled
    public static void updateBatchWithTemplateIds(Id batchId, String contextTemplateId, String groundedTemplateId) {
        Prompt_Test_Batch__c batch = new Prompt_Test_Batch__c(
            Id = batchId,
            Context_Template_Id__c = contextTemplateId,
            Grounded_Template_Id__c = groundedTemplateId
        );
        update batch;
    }
    
    @AuraEnabled
    public static void submitBatch(Id batchId) {
        Prompt_Test_Batch__c batch = new Prompt_Test_Batch__c(
            Id = batchId,
            Status__c = 'Submitted'
        );
        update batch;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getBatchTests(Id batchId) {
        List<Prompt_Test__c> tests = [
            SELECT Id, Messaging_Session__c, Status__c, Contextual_Service_Replies_Result__c,
                   Grounded_Service_Replies_Result__c, CreatedDate
            FROM Prompt_Test__c
            WHERE Prompt_Test_Batch__c = :batchId
            ORDER BY CreatedDate DESC
        ];
        
        List<Map<String, Object>> testData = new List<Map<String, Object>>();
        for (Prompt_Test__c test : tests) {
            testData.add(new Map<String, Object>{
                'Id' => test.Id,
                'Messaging_Session__c' => test.Messaging_Session__c,
                'Status__c' => test.Status__c,
                'Contextual_Service_Replies_Result__c' => test.Contextual_Service_Replies_Result__c,
                'Grounded_Service_Replies_Result__c' => test.Grounded_Service_Replies_Result__c,
                'CreatedDate' => test.CreatedDate
            });
        }
        
        return testData;
    }
}
