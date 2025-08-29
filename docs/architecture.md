# Hey-Bills Full-Stack Architecture Document

## 🏗️ PROJECT OVERVIEW

**Project Name**: Hey-Bills - AI-Powered Financial Wellness Companion  
**Architecture Type**: Mobile-First, Serverless Architecture  
**Technology Stack**: Flutter + Supabase  
**Architect**: Winston  

---

## **Section 1: Introduction**

This document outlines the complete fullstack architecture for Hey-Bills, including backend systems, frontend implementation, and their integration. It serves as the single source of truth for AI-driven development, ensuring consistency across the entire technology stack.

**Starter Template**: N/A - Greenfield project  
**Change Log**: Initial architecture creation - v1.0  

---

## **Section 2: High Level Architecture**

### **Technical Summary**
Hey-Bills uses a **mobile-first, serverless architecture** with Flutter for cross-platform mobile development and Supabase as the comprehensive backend-as-a-service platform. The architecture emphasizes rapid development, cost-effectiveness, and scalability while maintaining security and performance standards.

### **Platform and Infrastructure Choice**
**Selected Platform**: Supabase + Flutter  
**Key Services**: Supabase Auth, Database, Storage, Edge Functions  
**Deployment**: Supabase Cloud (managed service)  

### **Repository Structure**
**Structure**: Monorepo  
**Organization**: Single Flutter project with Supabase backend configuration  

### **Architectural Patterns**
- **Serverless Architecture**: Supabase provides serverless backend services
- **Mobile-First Design**: Flutter app as primary interface
- **Event-Driven Architecture**: Real-time updates for warranty alerts
- **Repository Pattern**: Abstract data access through Supabase client
- **Component-Based UI**: Reusable Flutter widgets and screens
- **API-First Design**: All functionality exposed through Supabase APIs

---

## **Section 3: Tech Stack**

### **Technology Stack Table**

| Category | Technology | Version | Purpose | Rationale |
|----------|------------|---------|---------|------------|
| **Frontend Language** | Dart | 3.0+ | Mobile app development | Flutter's native language |
| **Frontend Framework** | Flutter | 3.16+ | Cross-platform mobile UI | Rapid development, native performance |
| **State Management** | Provider/Riverpod | 6.0+ | App state management | Flutter ecosystem standard |
| **Backend Platform** | Supabase | Latest | Backend-as-a-Service | Rapid development, built-in services |
| **Database** | PostgreSQL | 15+ | Primary data storage | ACID compliance, excellent performance |
| **Authentication** | Supabase Auth | Built-in | User management | Google OAuth, email/password |
| **File Storage** | Supabase Storage | Built-in | Receipt images, documents | Integrated with auth, CDN |
| **Edge Functions** | TypeScript | 5.0+ | Serverless business logic | Type safety, Supabase integration |
| **Testing** | Flutter Test | 3.16+ | Testing framework | Native Flutter testing |
| **Monitoring** | Sentry | Latest | Error tracking | Excellent Flutter support |

---

## **Section 4: Data Models**

### **Core Entities**
1. **User**: Authentication, profile, business type
2. **Receipt**: OCR data, categorization, metadata
3. **Warranty**: Product protection, expiration tracking
4. **Budget**: Spending limits, threshold alerts

### **Key Relationships**
- User has many Receipts
- User has many Warranties  
- Receipt can have one Warranty
- User has many Budgets

---

## **Section 5: API Specification**

### **REST API + Real-time**
- **Authentication**: Supabase Auth endpoints
- **Receipts**: CRUD operations with OCR processing
- **Warranties**: Management and expiration tracking
- **Analytics**: Spending insights and reporting
- **Real-time**: Supabase subscriptions for live updates

---

## **Section 6: Components**

### **Frontend Components**
- **Authentication Component**: Login, registration, session management
- **Receipt Scanner Component**: Camera integration, OCR processing
- **Receipt Management Component**: CRUD operations, categorization
- **Warranty Tracker Component**: Warranty management, alerts
- **Analytics Dashboard Component**: Spending insights, budget tracking
- **Notification Service Component**: Push notifications, in-app alerts

### **Backend Components**
- **Supabase Database Service**: Data persistence, RLS policies
- **Supabase Storage Service**: File storage, image optimization
- **Edge Functions Service**: Business logic, external integrations
- **Authentication Service**: JWT management, OAuth integration

---

## **Section 7: Database Schema**

### **Core Tables**
```sql
-- Users table with RLS policies
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Receipts table with OCR data
CREATE TABLE receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    image_url TEXT NOT NULL,
    merchant_name VARCHAR(255) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    ocr_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Warranties table with expiration tracking
CREATE TABLE warranties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    product_name VARCHAR(255) NOT NULL,
    warranty_end_date DATE NOT NULL,
    alert_preferences JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## **Section 8: Frontend Architecture**

### **Component Organization**
```
lib/
├── features/                   # Feature-based modules
│   ├── auth/                  # Authentication
│   ├── receipts/              # Receipt management
│   ├── warranties/            # Warranty tracking
│   └── analytics/             # Analytics dashboard
├── shared/                    # Shared components
└── core/                      # Core utilities
```

### **State Management**
- **Provider Pattern**: Simple state management
- **ChangeNotifier**: Reactive UI updates
- **Local State**: Component-specific state

---

## **Section 9: Backend Architecture**

### **Service Architecture**
- **Serverless**: Supabase Edge Functions
- **Database**: Managed PostgreSQL with RLS
- **Storage**: Managed file storage with CDN
- **Authentication**: Managed auth with OAuth

### **Edge Functions**
- **OCR Processor**: Image processing optimization
- **Warranty Alerts**: Expiration checking and notifications
- **Data Export**: Receipt and analytics export
- **Analytics**: Complex calculations and reporting

---

## **Section 10: Project Structure**

### **Monorepo Organization**
```
hey-bills/
├── lib/                       # Flutter application
├── supabase/                  # Backend configuration
│   ├── functions/             # Edge Functions
│   ├── migrations/            # Database migrations
│   └── config.toml           # Supabase config
├── test/                      # Flutter tests
└── docs/                      # Documentation
```

---

## **Section 11: Development Workflow**

### **Local Setup**
```bash
# Install dependencies
flutter pub get
supabase start

# Run development
flutter run
supabase functions serve
```

### **Environment Configuration**
- **Frontend**: Supabase URL, API keys
- **Backend**: Service role keys, JWT secrets
- **Shared**: Environment flags, debug mode

---

## **Section 12: Deployment Architecture**

### **Deployment Strategy**
- **Frontend**: Flutter build outputs + App Store deployment
- **Backend**: Supabase Cloud (managed deployment)
- **CI/CD**: GitHub Actions with automated testing

### **Environments**
- **Development**: Local Supabase + Flutter
- **Staging**: Supabase staging project
- **Production**: Supabase production project

---

## **Section 13: Security and Performance**

### **Security Requirements**
- **Row Level Security**: Database-level access control
- **JWT Authentication**: Secure token-based auth
- **Input Validation**: Edge Function validation
- **Data Encryption**: Supabase managed encryption

### **Performance Optimization**
- **Frontend**: Lazy loading, local caching
- **Backend**: Database indexing, query optimization
- **Targets**: App launch < 3s, OCR < 5s, API < 200ms

---

## **Section 14: Testing Strategy**

### **Testing Pyramid**
- **E2E Tests**: Flutter Integration Tests
- **Integration Tests**: API + Database testing
- **Unit Tests**: Flutter Test + Jest

### **Test Organization**
- **Frontend**: Unit, widget, integration tests
- **Backend**: Edge Function testing
- **Coverage**: Business logic, UI components, API endpoints

---

## **Section 15: Coding Standards**

### **Critical Rules**
- **Type Sharing**: Define types in shared models
- **API Calls**: Use service layer, never direct HTTP
- **Error Handling**: Standard error handler for all APIs
- **State Updates**: Use proper state management patterns

### **Naming Conventions**
- **Components**: PascalCase (ReceiptListScreen)
- **Services**: camelCase (receiptService)
- **Database**: snake_case (receipts, warranties)

---

## **Section 16: Error Handling**

### **Error Strategy**
- **Standard Format**: Consistent error response structure
- **User-Friendly Messages**: Clear, actionable error messages
- **Logging**: Sentry integration for monitoring
- **Recovery**: Graceful fallbacks and retry mechanisms

---

## **Section 17: Monitoring**

### **Monitoring Stack**
- **Frontend**: Flutter Performance + Custom metrics
- **Backend**: Supabase Dashboard + Edge Function logs
- **Error Tracking**: Sentry for crash reporting
- **Performance**: Custom performance metrics

---

## **Next Steps**

### **UX Expert Prompt**
Create UX/UI design specifications based on this architecture document, focusing on user experience flows and interface design.

### **Architect Prompt**
Review and validate this architecture document, ensuring technical feasibility and implementation readiness.

---

*Architecture created by Architect Winston on [Current Date]*
