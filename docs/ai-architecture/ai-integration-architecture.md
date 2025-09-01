# Hey-Bills AI Integration Architecture

## Executive Summary

Hey-Bills implements a comprehensive AI system combining OpenRouter LLM integration, OCR capabilities, vector embeddings, and personalized query processing. The system enables natural language interaction with receipt data, providing intelligent answers to queries like "when did I pay school fees?" while offering budget analysis, warranty alerts, and purchase advice.

## Current Implementation Status

### ✅ Already Implemented
- OpenRouter LLM integration with fallback mechanisms
- Tesseract.js OCR with image preprocessing
- Basic vector embedding generation (hash-based approach)
- RAG pipeline with query analysis and context retrieval
- Supabase vector search functions
- Chat interface with conversation history

### 🔄 Enhancement Opportunities
- Advanced embedding models (move from hash-based to transformer models)
- Enhanced mobile AI integration
- Predictive analytics and budget forecasting
- Warranty alert automation
- Purchase recommendation engine

## System Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│   Express API    │◄──►│   Supabase DB   │
│                 │    │                  │    │                 │
│ • Chat UI       │    │ • RAG Service    │    │ • Vector Store  │
│ • Camera OCR    │    │ • OCR Service    │    │ • Embeddings    │
│ • Receipt Mgmt  │    │ • OpenRouter     │    │ • Chat History  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                       ┌──────┴──────┐
                       │ OpenRouter  │
                       │ LLM API     │
                       └─────────────┘
```

## 1. OpenRouter LLM Integration

### Current Implementation
- **Model**: Llama-3.1-8b-instruct (free tier)
- **Features**: Chat completion, context-aware responses
- **Fallbacks**: Error handling with graceful degradation
- **Rate Limits**: Built-in timeout and retry mechanisms

### Recommendations for Enhancement

#### Model Selection Strategy
```javascript
// Multi-model approach for cost optimization
const MODEL_TIERS = {
  premium: 'anthropic/claude-3.5-sonnet',    // Complex analysis
  standard: 'meta-llama/llama-3.1-70b',     // General queries  
  budget: 'meta-llama/llama-3.1-8b',        // Simple queries
  free: 'meta-llama/llama-3.1-8b:free'      // Fallback
};

// Query complexity scoring for model selection
function selectOptimalModel(query, contextSize) {
  const complexity = calculateQueryComplexity(query, contextSize);
  if (complexity > 0.8) return MODEL_TIERS.premium;
  if (complexity > 0.5) return MODEL_TIERS.standard;
  return MODEL_TIERS.budget;
}
```

#### Cost Optimization Techniques
- **Caching**: Store common query responses
- **Query Classification**: Route simple queries to cheaper models
- **Context Compression**: Summarize long conversation histories
- **Batch Processing**: Combine multiple queries when possible

## 2. OCR Capabilities Analysis

### Current Tesseract Implementation
- **Strengths**: No API costs, works offline, good accuracy for clear receipts
- **Limitations**: Slower processing, struggles with poor quality images
- **Preprocessing**: Sharp enhancement, grayscale conversion, threshold application

### Alternative OCR Solutions Comparison

| Solution | Accuracy | Speed | Cost | Mobile Support | Best For |
|----------|----------|-------|------|---------------|----------|
| **Tesseract.js** | 75-85% | Slow | Free | ✅ | Clear text receipts |
| **Google Vision** | 90-95% | Fast | $1.50/1K | ✅ | High accuracy needs |
| **Azure OCR** | 88-93% | Fast | $1/1K | ✅ | Enterprise integration |
| **AWS Textract** | 92-97% | Fast | $1.50/1K | ✅ | Complex documents |

### Hybrid OCR Strategy Recommendation
```javascript
// Adaptive OCR selection based on image quality and user preferences
const OCR_STRATEGIES = {
  highQuality: 'tesseract',      // Clear, well-lit receipts
  mediumQuality: 'google-vision', // Moderate quality images
  poorQuality: 'aws-textract',    // Crumpled, dark receipts
  bulk: 'tesseract',             // Batch processing
  premium: 'google-vision'        // Paid users
};

async function processReceiptWithAdaptiveOCR(imageBuffer, userTier) {
  const quality = await assessImageQuality(imageBuffer);
  const strategy = selectOCRStrategy(quality, userTier);
  return await processWithStrategy(imageBuffer, strategy);
}
```

## 3. Vector Embeddings Architecture

### Current Hash-Based Approach
- **Method**: Simple hash-based embeddings (384 dimensions)
- **Limitations**: Poor semantic understanding, no similarity learning
- **Benefits**: Fast, no API costs, works offline

### Enhanced Embedding Strategy

#### Model Selection
```javascript
// Tiered embedding approach
const EMBEDDING_MODELS = {
  premium: {
    model: 'text-embedding-3-large',
    provider: 'openai',
    dimensions: 3072,
    cost: '$0.13/1M tokens',
    use_case: 'Complex semantic search'
  },
  standard: {
    model: 'text-embedding-3-small', 
    provider: 'openai',
    dimensions: 1536,
    cost: '$0.02/1M tokens',
    use_case: 'General purpose search'
  },
  budget: {
    model: 'sentence-transformers/all-MiniLM-L6-v2',
    provider: 'local',
    dimensions: 384,
    cost: 'Free',
    use_case: 'Offline processing'
  }
};
```

#### Chunking Strategy for Receipts
```javascript
// Multi-granular chunking for better retrieval
const CHUNKING_STRATEGIES = {
  receipt_overview: {
    // High-level receipt information
    fields: ['merchant', 'total', 'date', 'category'],
    weight: 0.4
  },
  item_details: {
    // Individual items and prices
    fields: ['items', 'quantities', 'prices'],
    weight: 0.3
  },
  contextual: {
    // Derived insights and categorization
    fields: ['location', 'time_context', 'purchase_reason'],
    weight: 0.3
  }
};
```

#### Hybrid Search Implementation
```javascript
// Combine semantic and keyword search
async function hybridSearch(query, userId, options = {}) {
  const [semanticResults, keywordResults] = await Promise.all([
    vectorSearch(query, userId, { ...options, type: 'semantic' }),
    keywordSearch(query, userId, { ...options, type: 'fulltext' })
  ]);
  
  // Weighted combination with RRF (Reciprocal Rank Fusion)
  return combineResults(semanticResults, keywordResults, {
    semantic_weight: 0.7,
    keyword_weight: 0.3
  });
}
```

## 4. Natural Language Query Processing Pipeline

### Current Query Analysis
- **Intent Detection**: Pattern matching for receipt/warranty/spending queries
- **Entity Extraction**: Basic regex for dates, amounts, merchants
- **Context Retrieval**: Strategy-based search routing

### Enhanced NLP Pipeline

#### Query Understanding Pipeline
```javascript
const NLP_PIPELINE = {
  // Stage 1: Intent Classification
  intent_classifier: {
    models: ['receipt_search', 'warranty_query', 'budget_analysis', 'general_qa'],
    confidence_threshold: 0.8,
    fallback: 'general_qa'
  },
  
  // Stage 2: Named Entity Recognition
  entity_extractor: {
    entities: ['DATE', 'MONEY', 'ORG', 'PRODUCT', 'LOCATION'],
    custom_patterns: {
      merchant_names: /\b(walmart|target|amazon|costco)\b/gi,
      receipt_amounts: /\$\d+\.?\d*/g,
      time_references: /(last month|this year|yesterday)/gi
    }
  },
  
  // Stage 3: Query Expansion
  query_expander: {
    synonyms: true,
    related_terms: true,
    user_history: true
  }
};
```

#### Context-Aware Processing
```javascript
// User context integration
async function processContextualQuery(query, userId) {
  const userProfile = await getUserProfile(userId);
  const recentActivity = await getRecentUserActivity(userId);
  
  const contextualizedQuery = {
    original_query: query,
    user_preferences: userProfile.preferences,
    spending_patterns: userProfile.spending_patterns,
    recent_context: recentActivity.slice(-5),
    temporal_context: getTemporalContext(query),
    location_context: userProfile.location_patterns
  };
  
  return enhanceQueryWithContext(contextualizedQuery);
}
```

## 5. Natural Language to Receipt Mapping

### Query Examples and Processing

#### "When did I pay school fees?"
```javascript
// Processing pipeline
const query = "When did I pay school fees?";
const processing = {
  intent: 'date_search',
  entities: {
    category: ['education', 'school'],
    temporal: ['when'],
    amount_type: 'fees'
  },
  search_strategy: 'category_temporal',
  filters: {
    categories: ['Education', 'Childcare', 'School Supplies'],
    keywords: ['school', 'tuition', 'fees', 'education'],
    date_range: 'last_12_months'
  }
};
```

#### "How much did I spend on groceries last month?"
```javascript
const query = "How much did I spend on groceries last month?";
const processing = {
  intent: 'spending_analysis',
  entities: {
    category: 'groceries',
    temporal: 'last_month',
    aggregation: 'sum'
  },
  search_strategy: 'category_aggregation',
  filters: {
    categories: ['Groceries', 'Food & Dining'],
    date_range: {
      start: '2024-01-01',
      end: '2024-01-31'
    }
  }
};
```

#### Advanced Query Processing
```javascript
// Context-aware query enhancement
async function enhanceQuery(originalQuery, userContext) {
  return {
    enhanced_query: await expandQueryWithSynonyms(originalQuery),
    search_filters: await generateSearchFilters(originalQuery, userContext),
    expected_result_type: await classifyExpectedOutput(originalQuery),
    confidence_requirements: await determineConfidenceThresholds(originalQuery)
  };
}
```

## 6. Budget Analysis & ML Predictions

### Current Analytics Capabilities
- Basic spending aggregation
- Category-based analysis
- Simple trend identification

### Enhanced Predictive Analytics

#### Machine Learning Models
```javascript
// Spending prediction models
const ML_MODELS = {
  monthly_budget_predictor: {
    algorithm: 'linear_regression',
    features: ['historical_spending', 'seasonal_trends', 'category_patterns'],
    accuracy: 0.85,
    use_case: 'Monthly budget forecasting'
  },
  
  anomaly_detector: {
    algorithm: 'isolation_forest',
    features: ['amount', 'merchant', 'time', 'location'],
    accuracy: 0.92,
    use_case: 'Fraud detection and unusual spending'
  },
  
  category_classifier: {
    algorithm: 'random_forest',
    features: ['merchant_name', 'item_descriptions', 'amount_patterns'],
    accuracy: 0.88,
    use_case: 'Automatic receipt categorization'
  }
};
```

#### Budget Insights Generation
```javascript
// AI-powered budget insights
async function generateBudgetInsights(userId) {
  const [spendingData, predictions, patterns] = await Promise.all([
    getSpendingData(userId),
    getBudgetPredictions(userId),
    getSpendingPatterns(userId)
  ]);
  
  return {
    current_status: analyzeBudgetHealth(spendingData),
    predictions: {
      next_month: predictions.monthly,
      year_end: predictions.annual,
      category_trends: predictions.categories
    },
    recommendations: generateRecommendations(patterns),
    alerts: generateBudgetAlerts(spendingData, predictions)
  };
}
```

## 7. Warranty Alert System

### Intelligent Date Tracking
```javascript
// AI-powered warranty detection and tracking
const WARRANTY_AI = {
  extraction: {
    // Extract warranty information from receipts
    warranty_detector: async (receiptText) => {
      const patterns = [
        /warranty[:\s]*(\d+)\s*(year|month|day)s?/gi,
        /guarantee[:\s]*(\d+)\s*(year|month|day)s?/gi,
        /protection plan[:\s]*(\d+)\s*(year|month|day)s?/gi
      ];
      
      return extractWarrantyTerms(receiptText, patterns);
    },
    
    // Predict warranty coverage for items
    warranty_predictor: async (item, merchant, category) => {
      const defaultWarranties = await getDefaultWarrantyData(merchant, category);
      const itemClassification = await classifyItemType(item);
      return predictWarrantyCoverage(itemClassification, defaultWarranties);
    }
  },
  
  alerts: {
    // Smart alert scheduling
    alert_scheduler: {
      '90_days_before': 'Consider extended warranty',
      '30_days_before': 'Warranty expiring soon',
      '7_days_before': 'Last chance for warranty claims',
      'on_expiry': 'Warranty expired today'
    }
  }
};
```

### Warranty Intelligence
```javascript
// Context-aware warranty management
async function manageWarrantyAlerts(userId) {
  const warranties = await getUserWarranties(userId);
  const currentDate = new Date();
  
  const processedWarranties = warranties.map(warranty => ({
    ...warranty,
    days_remaining: calculateDaysRemaining(warranty.end_date, currentDate),
    risk_assessment: assessWarrantyRisk(warranty),
    recommended_actions: generateWarrantyActions(warranty),
    similar_claims: findSimilarWarrantyClaims(warranty)
  }));
  
  return {
    active_warranties: processedWarranties.filter(w => w.days_remaining > 0),
    expiring_soon: processedWarranties.filter(w => w.days_remaining <= 30),
    expired_recently: processedWarranties.filter(w => w.days_remaining <= 0 && w.days_remaining > -90),
    recommendations: generateWarrantyRecommendations(processedWarranties)
  };
}
```

## 8. Purchase Advice Engine

### Spending Pattern Analysis
```javascript
// AI-powered purchase recommendations
const PURCHASE_ADVISOR = {
  pattern_analysis: {
    // Analyze user spending patterns
    spending_profiler: async (userId) => {
      const transactions = await getUserTransactions(userId);
      return {
        category_preferences: analyzeCategoryPreferences(transactions),
        price_sensitivity: analyzePriceSensitivity(transactions),
        seasonal_patterns: analyzeSeasonalSpending(transactions),
        merchant_loyalty: analyzeMerchantLoyalty(transactions),
        purchase_frequency: analyzePurchaseFrequency(transactions)
      };
    }
  },
  
  recommendations: {
    // Generate personalized recommendations
    recommendation_engine: async (userId, context) => {
      const profile = await getUserSpendingProfile(userId);
      const marketData = await getMarketComparisons(context.category);
      
      return {
        price_alerts: generatePriceAlerts(profile, marketData),
        better_alternatives: findBetterAlternatives(context, profile),
        seasonal_timing: recommendOptimalTiming(context, profile),
        budget_impact: assessBudgetImpact(context, profile),
        similar_user_insights: getSimilarUserInsights(profile, context)
      };
    }
  }
};
```

### Smart Purchase Timing
```javascript
// Optimal purchase timing recommendations
async function generatePurchaseAdvice(userId, potentialPurchase) {
  const userProfile = await getUserProfile(userId);
  const marketAnalysis = await analyzeMarketTrends(potentialPurchase.category);
  const budgetImpact = await assessBudgetImpact(userId, potentialPurchase);
  
  return {
    recommendation: calculatePurchaseScore(userProfile, marketAnalysis, budgetImpact),
    timing_advice: {
      buy_now: marketAnalysis.price_trend === 'increasing',
      wait_for_sale: marketAnalysis.seasonal_discount_probability > 0.7,
      optimal_date: predictOptimalPurchaseDate(marketAnalysis),
    },
    alternatives: await findAlternatives(potentialPurchase),
    budget_impact: {
      monthly_impact: budgetImpact.monthly_percentage,
      category_impact: budgetImpact.category_percentage,
      opportunity_cost: budgetImpact.opportunity_cost
    }
  };
}
```

## 9. Mobile AI Integration Architecture

### Flutter AI Integration Strategy

#### On-Device vs Cloud Processing
```dart
// Adaptive processing strategy
class AIProcessingManager {
  static const PROCESSING_STRATEGIES = {
    'local': {
      'ocr': 'ml_kit',              // Google ML Kit for basic OCR
      'category': 'tflite_model',   // On-device classification
      'embedding': 'sentence_piece' // Lightweight embeddings
    },
    'cloud': {
      'ocr': 'backend_api',         // Full OCR processing
      'llm': 'openrouter_api',      // LLM queries
      'embedding': 'openai_api'     // Advanced embeddings
    },
    'hybrid': {
      'preprocessing': 'local',     // Image enhancement locally
      'extraction': 'cloud',       // Complex processing in cloud
      'caching': 'local'           // Cache responses locally
    }
  };
  
  static ProcessingStrategy selectStrategy(
    TaskType task, 
    NetworkStatus network, 
    BatteryLevel battery
  ) {
    if (network.isOffline || battery.isLow) {
      return PROCESSING_STRATEGIES['local'];
    }
    if (task.complexity > 0.8) {
      return PROCESSING_STRATEGIES['cloud'];
    }
    return PROCESSING_STRATEGIES['hybrid'];
  }
}
```

#### Mobile-Optimized Features
```dart
// Smart caching for mobile performance
class MobileAICache {
  // Cache frequently used embeddings
  static final Map<String, List<double>> _embeddingCache = {};
  
  // Cache OCR results for similar images
  static final Map<String, OCRResult> _ocrCache = {};
  
  // Cache LLM responses for common queries
  static final Map<String, String> _responseCache = {};
  
  static Future<OCRResult> getCachedOCR(String imageHash) async {
    if (_ocrCache.containsKey(imageHash)) {
      return _ocrCache[imageHash]!;
    }
    
    final result = await performOCR(imageHash);
    _ocrCache[imageHash] = result;
    return result;
  }
}
```

## 10. Performance Optimization & Scalability

### Caching Strategy
```javascript
// Multi-tier caching system
const CACHE_STRATEGY = {
  embeddings: {
    redis: '7 days',           // Frequently accessed embeddings
    memory: '1 hour',          // Recently computed embeddings
    disk: '30 days'            // Long-term storage
  },
  llm_responses: {
    redis: '24 hours',         // Common query responses  
    memory: '15 minutes',      // Session-based responses
  },
  ocr_results: {
    s3: 'permanent',           // Original results
    redis: '3 days',           // Frequently accessed
  }
};
```

### Database Optimization
```sql
-- Optimized indexes for AI queries
CREATE INDEX CONCURRENTLY idx_receipts_embedding_cosine 
ON receipts USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX CONCURRENTLY idx_receipts_category_date 
ON receipts (category, purchase_date DESC);

CREATE INDEX CONCURRENTLY idx_receipts_user_merchant 
ON receipts (user_id, merchant_name) 
WHERE merchant_name IS NOT NULL;

-- Partitioning for large datasets
CREATE TABLE receipts_y2024m01 PARTITION OF receipts
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## 11. Technical Decisions Summary

### OpenRouter Integration
- **Decision**: Multi-model strategy with automatic fallbacks
- **Rationale**: Cost optimization while maintaining quality
- **Implementation**: Model selection based on query complexity

### OCR Strategy  
- **Decision**: Hybrid approach starting with Tesseract, upgrading selectively
- **Rationale**: Balance cost, accuracy, and performance
- **Implementation**: Quality-based OCR selection

### Vector Embeddings
- **Decision**: Migrate from hash-based to transformer embeddings gradually  
- **Rationale**: Improve search quality while managing costs
- **Implementation**: Tiered embedding strategy

### Mobile Processing
- **Decision**: Adaptive local/cloud processing
- **Rationale**: Optimize for network conditions and battery life
- **Implementation**: Strategy selection based on context

### Data Architecture
- **Decision**: Extend existing Supabase schema with AI-specific tables
- **Rationale**: Leverage existing investment while adding AI capabilities
- **Implementation**: Incremental schema evolution

## 12. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Enhance vector embedding system
- Implement advanced query analysis  
- Add ML-based receipt categorization

### Phase 2: Intelligence (Weeks 3-4)
- Deploy budget prediction models
- Implement warranty alert automation
- Add purchase recommendation engine

### Phase 3: Optimization (Weeks 5-6)
- Mobile AI integration
- Performance optimization
- Advanced caching implementation

### Phase 4: Advanced Features (Weeks 7-8)
- Predictive analytics dashboard
- Advanced fraud detection
- Cross-platform AI synchronization

## Conclusion

The Hey-Bills AI architecture provides a comprehensive foundation for intelligent receipt management. The existing implementation covers core functionality, while the enhancement roadmap delivers advanced AI capabilities including predictive analytics, smart alerts, and personalized recommendations. The architecture emphasizes cost optimization, performance, and user experience while maintaining scalability for future growth.