# Receipt Management API

This document describes the comprehensive receipt management API endpoints for the Hey-Bills backend.

## Base URL
All API endpoints are prefixed with `/api/receipts`

## Authentication
All endpoints require authentication via JWT token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

## Endpoints Overview

### 1. GET /api/receipts
List user's receipts with filtering and pagination.

**Query Parameters:**
- `page` (number, optional): Page number (default: 1)
- `limit` (number, optional): Items per page, max 100 (default: 20)
- `category_id` (string, optional): Filter by category ID
- `merchant_name` (string, optional): Filter by merchant name (partial match)
- `date_from` (string, optional): Filter from date (YYYY-MM-DD format)
- `date_to` (string, optional): Filter to date (YYYY-MM-DD format)
- `min_amount` (number, optional): Filter by minimum amount
- `max_amount` (number, optional): Filter by maximum amount
- `is_business_expense` (boolean, optional): Filter business expenses
- `is_reimbursable` (boolean, optional): Filter reimbursable receipts
- `tags` (string, optional): Filter by tags (comma-separated)
- `search` (string, optional): Full-text search across merchant and notes
- `sort_by` (string, optional): Sort field (purchase_date|total_amount|merchant_name|created_at)
- `sort_order` (string, optional): Sort direction (asc|desc, default: desc)

**Response:**
```json
{
  "message": "Receipts retrieved successfully",
  "data": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "category_id": "uuid",
      "image_url": "string",
      "merchant_name": "string",
      "merchant_address": "string",
      "total_amount": "25.99",
      "tax_amount": "2.34",
      "tip_amount": "0.00",
      "currency": "USD",
      "payment_method": "credit_card",
      "purchase_date": "2024-01-15",
      "purchase_time": "14:30:00",
      "location_lat": 40.7128,
      "location_lng": -74.0060,
      "location_address": "New York, NY",
      "is_business_expense": true,
      "is_reimbursable": false,
      "notes": "Business lunch",
      "tags": ["business", "meal"],
      "ocr_confidence": 0.95,
      "created_at": "2024-01-15T14:30:00Z",
      "updated_at": "2024-01-15T14:30:00Z",
      "categories": {
        "id": "uuid",
        "name": "Food & Dining",
        "color": "#FF6B6B",
        "icon": "🍽️"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### 2. GET /api/receipts/:id
Get single receipt with detailed information including line items.

**Response:**
```json
{
  "message": "Receipt retrieved successfully",
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    // ... receipt fields ...
    "categories": {
      "id": "uuid",
      "name": "Food & Dining",
      "color": "#FF6B6B",
      "icon": "🍽️"
    },
    "receipt_items": [
      {
        "id": "uuid",
        "item_name": "Burger",
        "item_category": "Food",
        "quantity": 1,
        "unit_price": "15.99",
        "total_price": "15.99",
        "tax_amount": "1.44",
        "sku": "ITEM001",
        "barcode": "1234567890123",
        "brand": "Restaurant Brand",
        "ocr_confidence": 0.98,
        "line_number": 1
      }
    ]
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### 3. POST /api/receipts
Create a new receipt.

**Request Body:**
```json
{
  "image_url": "https://storage.example.com/receipt.jpg",
  "merchant_name": "Test Restaurant",
  "total_amount": 25.99,
  "purchase_date": "2024-01-15",
  "category_id": "uuid",
  "merchant_address": "123 Main St, City",
  "tax_amount": 2.34,
  "tip_amount": 3.00,
  "currency": "USD",
  "payment_method": "credit_card",
  "purchase_time": "14:30:00",
  "location_lat": 40.7128,
  "location_lng": -74.0060,
  "location_address": "New York, NY",
  "is_business_expense": true,
  "is_reimbursable": false,
  "notes": "Business lunch",
  "tags": ["business", "meal"],
  "ocr_data": { "raw": "ocr results" },
  "ocr_confidence": 0.95,
  "processed_data": { "structured": "data" },
  "items": [
    {
      "item_name": "Burger",
      "item_category": "Food",
      "quantity": 1,
      "unit_price": 15.99,
      "total_price": 15.99,
      "tax_amount": 1.44
    }
  ]
}
```

**Required Fields:**
- `image_url` (string): URL to receipt image
- `merchant_name` (string): Name of merchant
- `total_amount` (number): Total receipt amount
- `purchase_date` (string): Date of purchase (YYYY-MM-DD)

**Response:** Same as GET single receipt

### 4. PUT /api/receipts/:id
Update an existing receipt.

**Request Body:** Same as POST but all fields are optional (except ID in URL)

**Response:** Same as GET single receipt

### 5. DELETE /api/receipts/:id
Delete a single receipt.

**Response:**
```json
{
  "message": "Receipt deleted successfully",
  "data": {
    "id": "uuid"
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### 6. GET /api/receipts/categories
Get available receipt categories for the user.

**Response:**
```json
{
  "message": "Categories retrieved successfully",
  "data": [
    {
      "id": "uuid",
      "name": "Food & Dining",
      "description": "Restaurants, groceries, and food delivery",
      "icon": "🍽️",
      "color": "#FF6B6B",
      "is_default": true,
      "sort_order": 1,
      "is_active": true
    }
  ],
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### 7. GET /api/receipts/analytics
Get spending analytics and insights.

**Query Parameters:**
- `period` (string, optional): Time period (week|month|quarter|year|custom, default: month)
- `date_from` (string, required if period=custom): Start date (YYYY-MM-DD)
- `date_to` (string, required if period=custom): End date (YYYY-MM-DD)
- `category_id` (string, optional): Filter by specific category
- `group_by` (string, optional): Group results by (category|merchant|date|business_expense, default: category)

**Response:**
```json
{
  "message": "Analytics retrieved successfully",
  "data": {
    "summary": {
      "total_spent": 1250.75,
      "total_receipts": 45,
      "average_amount": 27.79,
      "date_range": {
        "start": "2024-01-01",
        "end": "2024-01-31"
      }
    },
    "grouped_data": [
      {
        "category": {
          "id": "uuid",
          "name": "Food & Dining"
        },
        "count": 15,
        "total": 450.25,
        "average": 30.02
      }
    ],
    "period": "month",
    "group_by": "category"
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

### 8. PATCH /api/receipts/:id/tags
Update receipt tags only.

**Request Body:**
```json
{
  "tags": ["business", "meal", "client"]
}
```

**Validation Rules:**
- Maximum 20 tags per receipt
- Each tag max 50 characters
- Tags must be non-empty strings

**Response:** Same as GET single receipt

### 9. DELETE /api/receipts (Bulk Delete)
Delete multiple receipts at once.

**Request Body:**
```json
{
  "receipt_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Validation Rules:**
- Maximum 50 receipts per request
- Array cannot be empty

**Response:**
```json
{
  "message": "Successfully deleted 3 receipts",
  "data": {
    "deleted_count": 3,
    "failed_ids": []
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

## Error Handling

All endpoints return consistent error responses:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "timestamp": "2024-01-15T14:30:00Z"
}
```

Common HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

## Rate Limiting

- Authenticated users: 100 requests per 15-minute window
- Anonymous users: Rate limited by IP

## Data Validation

### Amount Fields
- Must be positive numbers
- Stored with 2 decimal precision
- Support for various currencies

### Date Fields
- Must be valid dates in YYYY-MM-DD format
- Future dates allowed for planned expenses

### Coordinates
- Latitude: -90 to 90
- Longitude: -180 to 180

### Tags
- Array of strings
- Maximum 20 tags per receipt
- Each tag maximum 50 characters
- No empty tags allowed

### OCR Confidence
- Number between 0 and 1
- Represents confidence level of OCR processing

## Usage Examples

### Search receipts by merchant
```bash
curl -X GET "https://api.heybills.com/api/receipts?merchant_name=Starbucks" \
  -H "Authorization: Bearer your-jwt-token"
```

### Get monthly analytics
```bash
curl -X GET "https://api.heybills.com/api/receipts/analytics?period=month&group_by=category" \
  -H "Authorization: Bearer your-jwt-token"
```

### Create receipt with OCR data
```bash
curl -X POST "https://api.heybills.com/api/receipts" \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://storage.example.com/receipt.jpg",
    "merchant_name": "Coffee Shop",
    "total_amount": 8.50,
    "purchase_date": "2024-01-15",
    "tags": ["coffee", "morning"],
    "ocr_confidence": 0.92
  }'
```

## Database Schema Reference

The Receipt API is built on the following database tables:
- `receipts` - Main receipt data
- `receipt_items` - Individual line items from receipts
- `categories` - Receipt categories (default and user-defined)
- `user_profiles` - Extended user information

See the database migration files for complete schema details.