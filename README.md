# Einstein Prompt Testing Utility

A Salesforce application for testing multiple types of Einstein prompt templates against real organizational data. This utility enables systematic evaluation of AI-powered responses by processing historical data through various template types including Service Replies, Case Summaries, and Work Summaries.

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

### 2. Configure Named Credential

Create a Named Credential for Connect API access:

1. Navigate to **Setup** → **Named Credentials**
2. Create New Named Credential:
   - **Label**: `Salesforce_Connect_API`
   - **Name**: `Salesforce_Connect_API`
   - **URL**: `https://yourinstance.salesforce.com`
   - **Identity Type**: `Named Principal`
   - **Authentication Protocol**: `OAuth 2.0`
   - **Flow**: `Authorization Code`
   - **Scope**: `api refresh_token`

### 3. Configure Remote Site Settings

Ensure the following remote site is allowed:
- **Remote Site Name**: `Salesforce_API`
- **Remote Site URL**: `https://yourinstance.salesforce.com`

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

## 📖 Usage Guide

### 1. Accessing the Application

Navigate to the **Prompt Testing Utility** tab in your Salesforce org to access the testing utility.

### 2. Test Type Selection

1. **Choose Test Type**: Select from Service Replies, Case Summary, or Work Summary
2. **Configure Templates**: Based on your selection:
   - **Service Replies**: Requires both Primary (Contextual) and Secondary (Grounded) templates
   - **Case Summary**: Requires only Primary template
   - **Work Summary**: Requires only Primary template

### 3. Template Selection

1. **Browse Templates**: View paginated list of available Einstein Prompt Templates
2. **Filter Templates**: Use search and type filters to find relevant templates
3. **Select Templates**: Choose appropriate templates for your test type
4. **Continue**: Proceed to data selection

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
- **Primary Result**: Contextual analysis including search queries and context
- **Secondary Result**: Knowledge-grounded response (if applicable)
- **Processing Status**: Success, failure, or skipped status

#### **Case Summary Results**
- **Case Reference**: The case being summarized
- **Primary Result**: AI-generated case summary
- **Processing Status**: Success or failure status

#### **Work Summary Results**
- **Work Reference**: The messaging session or voice call being summarized
- **Primary Result**: AI-generated work summary
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
