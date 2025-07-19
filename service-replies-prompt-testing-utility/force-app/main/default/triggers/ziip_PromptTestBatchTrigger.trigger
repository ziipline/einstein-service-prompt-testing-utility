trigger ziip_PromptTestBatchTrigger on Prompt_Test_Batch__c (after update) {
    
    Set<Id> submittedBatchIds = new Set<Id>();
    
    for (Prompt_Test_Batch__c batch : Trigger.new) {
        Prompt_Test_Batch__c oldBatch = Trigger.oldMap.get(batch.Id);
        
        // Check if status changed to 'Submitted'
        if (batch.Status__c == 'Submitted' && oldBatch.Status__c != 'Submitted') {
            submittedBatchIds.add(batch.Id);
        }
    }
    
    if (!submittedBatchIds.isEmpty()) {
        // Update batches to 'In Progress' and set start time
        List<Prompt_Test_Batch__c> batchesToUpdate = new List<Prompt_Test_Batch__c>();
        
        for (Id batchId : submittedBatchIds) {
            batchesToUpdate.add(new Prompt_Test_Batch__c(
                Id = batchId,
                Status__c = 'In Progress',
                Start_Datetime__c = System.now()
            ));
        }
        
        update batchesToUpdate;
        
        // Launch the batch job
        ziip_PromptTestBatch batchJob = new ziip_PromptTestBatch(submittedBatchIds);
        Database.executeBatch(batchJob, 1); // Process one record at a time to avoid limits
    }
}
