# Einstein Prompt Testing Utility

A Salesforce application for testing multiple types of Einstein prompt templates against real organizational data. This utility enables systematic / bulk evaluation of AI-generated responses by processing historical data through various template types including Service Replies, Case Summaries, and Work Summaries.

This utility allows for the systematic evaluation of prompt templates as they are iterativly developed, so that, admins can evaluate  changes against a controlled group of test contexts, in bulk (e.g. a set number of messaging sessions). 

For prompt templates that include Retriveal Augmented Generation (RAG), this utility includes funtionality to evluate the RAG performance using the RAG framework. This generates three measures of RAG performance for each prompt that used RAG,

Context Quality [0-100] : A measure of the quality of the generated response to the query it is addressing -'does the response address the query'
Faithfulness [0-100] : A measure of the faithfulness / truthfulness of the response to the retrived grounding - 'a measure of how truthful the response is and if there is hallucination'
Relevancy [0-100] : A measure of the relevance of the retrived grounding to the original query - 'how relevant in the retrived knowledge for providing an answer to the query'

![Salesforce](https://img.shields.io/badge/Salesforce-00D4FF?style=flat-square&logo=salesforce&logoColor=white)
![Einstein AI](https://img.shields.io/badge/Einstein-AI-orange?style=flat-square)
![Lightning Web Components](https://img.shields.io/badge/LWC-Lightning-blue?style=flat-square)
![Apex](https://img.shields.io/badge/Apex-Salesforce-blue?style=flat-square)

## 🎯 Overview

This overview shows how Service Replies for Chat operates in a live environment, followed by how this testing utility can then be used to preview Service Replies in
order to test the underlying prompts that are used - to aid with development of the prompts that are used 

  <div>
    <a href="https://www.loom.com/share/0c525ad41cdc42d09e9d591f1bf67034">
      <p>Prompt Testing Utility | Overview of Functionality - Watch Video</p>
    </a>
    <a href="https://www.loom.com/share/0c525ad41cdc42d09e9d591f1bf67034">
      <img style="max-width:600px;" src="https://cdn.loom.com/sessions/thumbnails/0c525ad41cdc42d09e9d591f1bf67034-dbe20b8cea669196-full-play.gif">
    </a>
  </div>

The Einstein Prompt Testing Utility streamlines the process of evaluating multiple types of Einstein templates by:

- **Multi-Template Support**: Test Service Replies, Case Summaries, and Work Summaries
- **Automated Testing**: Batch process hundreds of records through your prompt templates
- **Intelligent Processing**: Automatically skips grounded templates when contextual analysis returns 'none'
- **Flexible Data Sources**: Support for messaging sessions, cases, and voice calls
- **Interactive Interface**: Easy-to-use Lightning Web Component for template and data selection
- **Comprehensive Results**: Structured output tailored to each template type

## 🚀 Features

### Test Types Supported
- ✅ **Service Replies**: Test contextual and grounded response templates using messaging sessions
- ✅ **Case Summaries**: Generate AI-powered case summaries using Case records
- ✅ **Work Summaries**: Create work summaries from messaging sessions or voice calls

### Core Capabilities
- ✅ **Multi-Source Data**: Support for Messaging Sessions, Cases, and Voice Calls
- ✅ **Template Selection**: Browse and select Einstein Prompt Templates with pagination and filtering
- ✅ **Advanced Filtering**: Filter records by date range, name, status, and other criteria
- ✅ **Batch Processing**: Automated processing of hundreds of records simultaneously
- ✅ **Contextual Analysis**: Extract search queries and analyze conversation context (Service Replies)
- ✅ **Grounded Responses**: Generate knowledge-grounded responses when relevant (Service Replies)
- ✅ **Customer Utterance Parsing**: Automatically identify and process individual customer messages
- ✅ **Quality Metrics**: RAG-based evaluation for faithfulness, relevancy, and context quality assessment with automated batch processing
- ✅ **Progress Tracking**: Monitor batch processing status and detailed results

### Technical Features
- 🔧 **Multi-Template Architecture**: Flexible processing engine supporting different template types
- 🔧 **API Integration**: Connect API for conversation data, Einstein API for template execution
- 🔧 **Object References**: Direct Salesforce object integration for optimal data access
- 🔧 **Error Handling**: Comprehensive error handling and debug logging
- 🔧 **Scalable Architecture**: Batch processing for handling large datasets
- 🔧 **Performance Optimized**: Efficient pagination and data processing

## 📋 Prerequisites

### Salesforce Requirements
- Salesforce org with Einstein AI features enabled
- Einstein licenses (appropriate to your use case):
  - Einstein Service Reply (for Service Replies test type)
  - Einstein Case Summarization (for Case Summary test type)
  - Einstein Work Summarization (for Work Summary test type)
- Service Cloud Conversation Intelligence enabled (for messaging session data)
- Messaging for In-App and Web enabled (for Service Replies)
- Voice Call recording and transcription (for Work Summary voice call testing)

### Required Permissions
- System Administrator or the included Permission Set Group:
  - **Ziip Prompt Testing Full Access** (recommended) - Complete administrative access
  - Or individual permission sets:
    - **Ziip Prompt Testing Base** - Core functionality access
    - **Ziip Prompt Testing Admin** - Administrative capabilities
  - Additional manual setup required:
    - **Salesforce_Connect_API** Named Credential access
    - Appropriate Einstein licenses based on test types used
    - Read access to Case, MessagingSession, and VoiceCall objects

## 🛠️ Installation

### Pre-Deployment Steps

Before deploying the application, ensure your Salesforce org is properly configured:

#### 1. Enable Einstein in the Org
1. Navigate to **Setup** → **Einstein** → **Einstein Generative AI** → **Einstein Setup**
2. Enable Einstein Generative AI features for your organisation

#### 2. Enable Service AI Grounding
1. Navigate to **Setup** → **Feature Settings** → **Service** → **Service Cloud Einstein** → **Service AI Grounding**
2. Turn on Service AI Grounding functionality

### 1. Deploy the Application

Clone the repository and deploy using Salesforce DX:

```bash
# Clone the repository
git clone https://github.com/ziipline/service-reply-prompt-testing-utility.git
cd service-reply-prompt-testing-utility

# Deploy to your target org
sfdx force:source:deploy -p force-app/main/default -u your-org-alias

# Assign the Permission Set Group to users (recommended)
sfdx force:user:permset:assign -n Ziip_Prompt_Testing_Full_Access -u your-org-alias
```

### Permission Set Configuration

The application includes a comprehensive permission structure:

#### 🎯 **Option 1: Permission Set Group (Recommended)**
Assign the **"Ziip Prompt Testing Full Access"** Permission Set Group for complete functionality:

```bash
sfdx force:user:permset:assign -n Ziip_Prompt_Testing_Full_Access -u your-org-alias
```

This Permission Set Group automatically includes:
- **Ziip Prompt Testing Base**: Core functionality access
- **Ziip Prompt Testing Admin**: Full administrative capabilities

#### 🔧 **Option 2: Individual Permission Sets**
For granular control, assign permission sets individually:

```bash
# Base functionality (required for all users)
sfdx force:user:permset:assign -n Ziip_Prompt_Testing_Base -u your-org-alias

# Administrative capabilities (for admin users)
sfdx force:user:permset:assign -n Ziip_Prompt_Testing_Admin -u your-org-alias
```

**Base Permission Set includes:**
- Read access to Prompt_Test__c and Prompt_Test_Batch__c objects
- Access to Apex classes (ziip_PromptTestUtil_Controller, ziip_PromptTestBatch)
- MessagingSession and MessagingEndUser read permissions
- All custom field read permissions

**Admin Permission Set includes:**
- Full CRUD access to custom objects (Create, Read, Edit, Delete, View All, Modify All)
- Custom tab visibility (Prompt_Test_Batch__c, Prompt_Testing_Utility)
- All custom field edit permissions

#### ⚠️ **Manual Configuration Required**
The following must be configured manually by administrators:
1. **Named Credential Access**: Grant users access to "Salesforce_Connect_API" Named Credential
2. **Einstein Licenses**: Ensure users have appropriate Einstein Service Reply licenses

### 1. Configure Named Credential

Create a Named Credential for Connect API access:

1. Navigate to **Setup** → **Named Credentials**
2. Create New Named Credential:
   - **Label**: `Salesforce_Connect_API`
   - **Name**: `Salesforce_Connect_API`
   - **URL**: `https://yourinstance.salesforce.com`
   - **Identity Type**: `Named Principal`
   - **Authentication Protocol**: `OAuth 2.0`
   - **Flow**: `Authorization Code`
   - **Scope**: `full refresh_token`

### 2. Configure Remote Site Settings

Ensure the following remote site is allowed:
- **Remote Site Name**: `Salesforce_API`
- **Remote Site URL**: `https://yourinstance.salesforce.com`

## 🔧 Post-Deployment Configuration

After successfully deploying the application, complete the following configuration steps:

### 1. Activate RAG Evaluation Prompt Templates

1. Navigate to **Setup** → **Einstein** → **Prompt Templates**
2. Locate and activate the following RAG evaluation templates:
   - **RAGAS_Context_Quality_Evaluator_V1**
   - **RAGAS_Faithfulness_Evaluator_V1** 
   - **RAGAS_Relevancy_Evaluator_V1**
3. **Important**: Note the record IDs of these templates for use in the LWC configuration

### 2. Configure the LWC in Prompt Testing Utility Record Page

1. Navigate to **Setup** → **Object Manager** → **Prompt Test Batch** → **Lightning Record Pages**
2. Edit the **Prompt Test Batch Record Page**
3. Configure the **ziip_promptTestUtility** Lightning Web Component with:
   - **Prompt Template IDs**: Include the IDs of the relevant prompt templates being tested
   - **Retriever Config ID**: Include the ID of the Retriever Config being tested

### 3. Named Credential Setup

Complete the following steps to set up authentication for the utility:

#### Step 1: Create Auth Provider
1. Navigate to **Setup** → **Auth. Providers**
2. Create a new Auth Provider:
   - **Provider Type**: `Salesforce`
   - **Name**: `SalesforceSelfAuth`
   - **URL Suffix**: `SalesforceSelfAuth`
3. **Important**: Note the **Callback URL** provided after saving

#### Step 2: Create External Client App
1. Navigate to **Setup** → **Apps** → **App Manager**
2. Create a new **Connected App** named `Prompt Template Test Utility`:
   - **API Name**: `Prompt_Template_Test_Utility`
   - **Contact Email**: Your admin email
   - **Enable OAuth Settings**: ✅ Checked
   - **Callback URL**: Use the callback URL from Step 1
   - **Selected OAuth Scopes**: 
     - `Full access (full)`
     - `Perform requests on your behalf at any time (refresh_token, offline_access)`
3. **Important**: Note the **Consumer Key** and **Consumer Secret** after saving
4. Return to the Auth Provider created in Step 1 and update:
   - **Consumer Key**: Enter the Consumer Key from the Connected App
   - **Consumer Secret**: Enter the Consumer Secret from the Connected App

#### Step 3: Create External Credential
1. Navigate to **Setup** → **Named Credentials** → **External Credentials**
2. Create a new External Credential:
   - **Label**: `Prompt_Testing_External_Credential`
   - **Name**: `Prompt_Testing_External_Credential`
   - **Authentication Protocol**: `OAuth 2.0`
   - **Authentication Flow Type**: `Authorization Code`
   - **Scope**: `full refresh_token offline_access`

#### Step 4: Create Named Credential
1. Navigate to **Setup** → **Named Credentials** → **Named Credentials**
2. Create a new Named Credential:
   - **Label**: `Prompt_Testing_Named_Credential`
   - **Name**: `Prompt_Testing_Named_Credential`
   - **URL**: `https://yourinstance.salesforce.com`
   - **External Credential**: Select the External Credential created in Step 3

### 4. Assign External Credential Principal Access

1. Navigate to **Setup** → **Permission Sets**
2. Create or edit a permission set to include:
   - **External Credential Principal Access**: Grant access to the External Credential created above
3. Assign this permission set to users who will be using the Prompt Testing Utility

## ⚙️ Configuration

### Einstein Prompt Templates by Test Type

Configure the appropriate Einstein Prompt Templates based on your intended test types:

#### **Service Replies Templates**
1. **Contextual Service Reply Template**
   - Should analyze conversation and return search queries
   - Expected output format: `{"search_query": "your query", "recent_speaker": "Customer"}`

2. **Grounded Service Reply Template**
   - Should use search queries to generate grounded responses
   - Requires retriever configuration for knowledge base access

#### **Case Summary Templates**
1. **Case Summarization Template**
   - Should generate summaries from Case objects
   - Uses `Input:caseToSummarize` parameter with Case object reference
   - Template works directly with Salesforce Case data

#### **Work Summary Templates**
1. **Work Summarization Template**
   - Should generate summaries from MessagingSession or VoiceCall objects
   - Uses object references for optimal data access
   - Supports both conversation transcripts and voice call data

### Retriever Configuration

For grounded Service Reply templates, update the RetriverId attribute when adding the 
ziip__PromptTestingUtility to an App page in App Builder

## 📊 RAG Quality Metrics

The utility includes comprehensive RAG (Retrieval-Augmented Generation) quality evaluation to score prompt outputs and ensure they are not hallucinating, remain faithful to grounding information, and respond in a context-aware manner.

### Quality Assessment Features

#### **Three Core Metrics**
1. **🎯 Faithfulness**: Measures how well the generated response adheres to the provided context/grounding information
2. **🔍 Relevancy**: Evaluates how relevant the response is to the user's question or input
3. **📋 Context Quality**: Assesses the quality and appropriateness of the context provided for response generation

#### **Automated Quality Processing**
- **Batch Integration**: Quality assessment automatically runs after primary prompt testing completes
- **Template-Based Evaluation**: Uses dedicated Einstein Prompt Templates for each metric type
- **Structured Analysis**: Provides both numerical scores (0-100) and detailed textual analysis
- **Status Tracking**: Monitor quality assessment progress separately from primary testing

### Quality Assessment Configuration

#### **Enable Quality Assessment**
1. **Batch Configuration**: Enable the "Enable Quality Assessment" checkbox on Prompt Test Batch records
2. **Template Selection**: Configure quality assessment templates:
   - **Faithfulness Template**: Template ID for faithfulness evaluation
   - **Relevancy Template**: Template ID for relevancy evaluation  
   - **Context Quality Template**: Template ID for context quality assessment

#### **RAG Prompt Templates**
The utility includes pre-built RAG evaluation templates:

```
├── GenAI Prompt Templates
│   ├── RAG_Faithfulness_Evaluator    # Evaluates response faithfulness to context
│   ├── RAG_Relevancy_Evaluator       # Measures response relevancy to query
│   └── RAG_Context_Quality_Evaluator # Assesses context appropriateness
```

**Template Configuration Requirements:**
- Each template should accept standard inputs (question, answer, context)
- Expected output format: `{"score": 85, "analysis": "Detailed explanation..."}`
- Score range: 0-100 (poor to excellent)

**Customization for Organisation-Specific Criteria:**
The RAG evaluation prompt templates can be customized to include your organisation's specific evaluation criteria. While the utility provides standard RAGAS-based evaluation templates, you can modify these templates to incorporate:
- Industry-specific quality standards
- Organisation-specific evaluation rubrics
- Custom scoring criteria aligned with your business requirements
- Specialised analysis frameworks relevant to your use case

To customize the evaluation templates, edit the prompt content in **Setup** → **Einstein** → **Prompt Templates** to reflect your organisation's unique evaluation needs while maintaining the required input/output format structure.

#### **Quality Assessment Workflow**
1. **Primary Testing**: Complete normal prompt testing batch
2. **Quality Trigger**: System automatically initiates quality assessment if enabled
3. **Metric Evaluation**: Each prompt test result is evaluated against all three metrics
4. **Score Storage**: Results stored in dedicated RAG score and analysis fields
5. **Status Updates**: Quality metrics status tracked independently

### Understanding Quality Results

#### **Faithfulness Scoring**
- **Score Range**: 0-100 (higher is better)
- **Interpretation**:
  - **90-100**: Highly faithful to provided context
  - **70-89**: Generally faithful with minor deviations
  - **50-69**: Moderate faithfulness, some hallucination risk
  - **<50**: Poor faithfulness, significant hallucination concerns

#### **Relevancy Scoring**  
- **Score Range**: 0-100 (higher is better)
- **Interpretation**:
  - **90-100**: Highly relevant to user query
  - **70-89**: Generally relevant with good context understanding
  - **50-69**: Moderately relevant, some off-topic elements
  - **<50**: Poor relevancy, response doesn't address query well

#### **Context Quality Scoring**
- **Score Range**: 0-100 (higher is better)  
- **Interpretation**:
  - **90-100**: Excellent context, highly appropriate for response generation
  - **70-89**: Good context quality with minor gaps
  - **50-69**: Adequate context but could be improved
  - **<50**: Poor context quality, insufficient for reliable response generation

#### **Quality Assessment Fields**
- **RAG_Faithfulness_Score__c**: Numerical faithfulness score (0-100)
- **RAG_Faithfulness_Analysis__c**: Detailed textual analysis of faithfulness
- **RAG_Relevancy_Score__c**: Numerical relevancy score (0-100)
- **RAG_Relevancy_Analysis__c**: Detailed textual analysis of relevancy
- **RAG_Context_Quality_Score__c**: Numerical context quality score (0-100)
- **RAG_Context_Quality_Analysis__c**: Detailed textual analysis of context quality
- **Quality_Metrics_Status__c**: Processing status (Pending, In Progress, Completed, Failed)
- **Quality_Assessment_Details__c**: Overall quality assessment summary

### Quality Metrics Best Practices

#### **Template Optimization**
- Monitor faithfulness scores to identify hallucination patterns
- Use relevancy scores to optimize response targeting
- Leverage context quality scores to improve grounding sources

#### **Batch Analysis**
- Compare quality metrics across different template versions
- Identify optimal template configurations using aggregate scores
- Track quality trends over time and across different data sets

#### **Performance Monitoring**
- Set quality score thresholds for production templates
- Use automated alerts for templates with declining quality scores
- Regular quality audits to maintain response reliability

## 📖 Usage Guide

### 1. Accessing the Application

Navigate to the **Prompt Testing Utility** tab in your Salesforce org to access the testing utility.

### 2. Test Type Selection

1. **Choose Test Type**: Select from Service Replies, Case Summary, or Work Summary
2. **Configure Templates**: Based on your selection:
   - **Service Replies**: Requires both Primary (Contextual) and Secondary (Grounded) templates
   - **Case Summary**: Requires only Primary template
   - **Work Summary**: Requires only Primary template
3. **Quality Assessment** (Optional): Enable quality assessment and configure RAG evaluation templates

### 3. Template Selection

1. **Browse Templates**: View paginated list of available Einstein Prompt Templates
2. **Filter Templates**: Use search and type filters to find relevant templates
3. **Select Templates**: Choose appropriate templates for your test type
4. **Quality Templates**: If quality assessment enabled, select RAG evaluation templates
5. **Continue**: Proceed to data selection

### 4. Data Selection

Depending on your test type, select appropriate data sources:

#### **Service Replies - Messaging Sessions**
1. **Apply Filters**: Date range, session name, status
2. **Browse Sessions**: Navigate through paginated messaging sessions
3. **Select Sessions**: Choose up to 200 messaging sessions
4. **Customer Utterances**: Each session will be processed for individual customer messages

#### **Case Summary - Cases**
1. **Apply Filters**: Date range, subject, status, priority
2. **Browse Cases**: Navigate through paginated case records
3. **Select Cases**: Choose cases to summarize
4. **Case Processing**: Each selected case will be processed individually

#### **Work Summary - Sessions or Voice Calls**
1. **Apply Filters**: Date range, name, status, type
2. **Browse Records**: Navigate through messaging sessions or voice calls
3. **Select Records**: Choose records for work summary generation
4. **Work Processing**: Each record will be processed for summary generation

### 5. Batch Processing

1. **Automatic Processing**: Batch processes selected records through templates
2. **Monitor Progress**: Track processing status in the Prompt Test Batch record
3. **Review Results**: Examine detailed results for each test

### 6. Understanding Results

Results vary by test type:

#### **Service Replies Results**
- **Customer Utterance**: The specific customer message being tested
- **Result**: Contextual analysis including search queries and context
- **Secondary Result**: Knowledge-grounded response (if applicable)
- **Processing Status**: Success, failure, or skipped status

#### **Case Summary Results**
- **Case Reference**: The case being summarized
- **Result**: AI-generated case summary
- **Processing Status**: Success or failure status

#### **Work Summary Results**
- **Work Reference**: The messaging session or voice call being summarized
- **Result**: AI-generated work summary
- **Processing Status**: Success or failure status

## 🏗️ Technical Architecture

### Core Components

```
├── Apex Classes
│   ├── ziip_PromptTestBatch.cls           # Batch processing engine
│   ├── ziip_PromptTestUtil_Controller.cls # API and data controller
│   └── ziip_PromptTestBatchTrigger.trigger # Batch status management
├── Lightning Web Components
│   └── ziip_promptTestUtility/           # Main user interface
├── Custom Objects
│   ├── Prompt_Test_Batch__c              # Batch configuration and tracking
│   └── Prompt_Test__c                    # Individual test records
└── Metadata
    ├── Custom Fields                     # Supporting field definitions
    └── Named Credentials                 # API authentication
```

### Data Flow

1. **Template Selection** → User selects prompt templates via LWC
2. **Session Filtering** → Connect API retrieves filtered messaging sessions
3. **Batch Creation** → System creates test batch with selected sessions
4. **Utterance Parsing** → Extract individual customer messages from conversations
5. **Template Processing** → Execute both contextual and grounded templates
6. **Result Storage** → Store formatted results in custom objects

### API Integrations

- **Connect API**: Conversation data retrieval (`/services/data/v62.0/connect/conversation/`)
- **Einstein API**: Prompt template execution (`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`)
- **Salesforce REST API**: Template metadata (`/services/data/v62.0/einstein/prompt-templates`)

## 🔧 Advanced Configuration

### Batch Processing Settings

Customize batch processing in `ziip_PromptTestBatch.cls`:

```apex
// Number of prompt generations per template
private static final Integer NUM_GENERATIONS = 1;

// Application name for Einstein API tracking
private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';

// Default retriever for grounded templates
private static final String DEFAULT_RETRIEVER_ID = 'your-retriever-id';
```

### Performance Tuning

- **Batch Size**: Adjust batch scope size based on your org's processing capacity
- **Pagination**: Modify page sizes in controller methods for optimal performance
- **Timeout Handling**: Configure appropriate timeout values for long-running processes

## 🐛 Troubleshooting

### Common Issues

**Template Not Found**
```
Error: Template ID cannot be blank
```
- Verify Einstein Prompt Templates exist and are active
- Check template ID configuration in batch records

**Connect API Authentication**
```
Error: Unauthorized (401)
```
- Verify Named Credential configuration
- Ensure OAuth flow is properly configured
- Check remote site settings

**No Conversations Retrieved**
```
No conversationEntries found in response
```
- Verify messaging sessions have associated conversations
- Check ConversationId field population
- Ensure proper permissions for conversation access

**Grounded Template Skipped**
```
Grounded template skipped: Context template returned "none"
```
- This is normal behavior when contextual analysis determines no search is needed
- Review contextual template logic if unexpected

### Debug Logging

Enable debug logging for detailed troubleshooting:

1. **Setup** → **Debug Logs**
2. Create traced flag for your user
3. Set Apex Classes to `DEBUG` level
4. Review logs for detailed processing information

### Performance Considerations

- Large batch processing may hit governor limits
- Consider reducing batch size for complex templates
- Monitor API usage for Einstein prompt generations
- Use selective SOQL queries to optimize performance

## 📊 Monitoring and Analytics

### Batch Status Tracking
- Monitor batch progress via `Prompt_Test_Batch__c` records
- Track success/failure rates across test batches
- Analyze processing times and performance metrics

### Result Analysis
- Export test results for external analysis
- Compare template performance across different conversation types
- Identify patterns in contextual vs grounded response effectiveness

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Standards
- Follow Salesforce Apex best practices
- Include comprehensive test coverage (75%+ required)
- Document all public methods and classes
- Use consistent naming conventions



**Built with ❤️ by the Ziipline Team**
