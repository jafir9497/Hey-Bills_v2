/**
 * TypeScript Database Definitions for Hey Bills Supabase Schema
 * Generated from database schema - do not edit manually
 * 
 * To regenerate, run: npx supabase gen types typescript --project-id=your-project > types/supabase.ts
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      budgets: {
        Row: {
          alert_at_percentage: number | null
          budget_amount: number
          category_id: string | null
          created_at: string | null
          end_date: string | null
          id: string
          is_active: boolean | null
          name: string
          period_type: string
          start_date: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          alert_at_percentage?: number | null
          budget_amount: number
          category_id?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          is_active?: boolean | null
          name: string
          period_type?: string
          start_date: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          alert_at_percentage?: number | null
          budget_amount?: number
          category_id?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          is_active?: boolean | null
          name?: string
          period_type?: string
          start_date?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "budgets_category_id_fkey"
            columns: ["category_id"]
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budgets_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      categories: {
        Row: {
          color: string | null
          created_at: string | null
          description: string | null
          icon: string | null
          id: string
          is_active: boolean | null
          is_default: boolean | null
          name: string
          parent_category_id: string | null
          sort_order: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          description?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean | null
          is_default?: boolean | null
          name: string
          parent_category_id?: string | null
          sort_order?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          color?: string | null
          created_at?: string | null
          description?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean | null
          is_default?: boolean | null
          name?: string
          parent_category_id?: string | null
          sort_order?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "categories_parent_category_id_fkey"
            columns: ["parent_category_id"]
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "categories_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      notifications: {
        Row: {
          created_at: string | null
          delivery_attempts: number | null
          delivery_method: Database["public"]["Enums"]["delivery_method"][] | null
          expires_at: string | null
          id: string
          is_read: boolean | null
          is_sent: boolean | null
          message: string
          metadata: Json | null
          priority: Database["public"]["Enums"]["priority_level"] | null
          read_at: string | null
          related_entity_id: string | null
          related_entity_type: string | null
          scheduled_for: string | null
          sent_at: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Insert: {
          created_at?: string | null
          delivery_attempts?: number | null
          delivery_method?: Database["public"]["Enums"]["delivery_method"][] | null
          expires_at?: string | null
          id?: string
          is_read?: boolean | null
          is_sent?: boolean | null
          message: string
          metadata?: Json | null
          priority?: Database["public"]["Enums"]["priority_level"] | null
          read_at?: string | null
          related_entity_id?: string | null
          related_entity_type?: string | null
          scheduled_for?: string | null
          sent_at?: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Update: {
          created_at?: string | null
          delivery_attempts?: number | null
          delivery_method?: Database["public"]["Enums"]["delivery_method"][] | null
          expires_at?: string | null
          id?: string
          is_read?: boolean | null
          is_sent?: boolean | null
          message?: string
          metadata?: Json | null
          priority?: Database["public"]["Enums"]["priority_level"] | null
          read_at?: string | null
          related_entity_id?: string | null
          related_entity_type?: string | null
          scheduled_for?: string | null
          sent_at?: string | null
          title?: string
          type?: Database["public"]["Enums"]["notification_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      receipt_embeddings: {
        Row: {
          content_hash: string
          content_text: string
          created_at: string | null
          embedding: string
          embedding_model: string
          id: string
          metadata: Json | null
          receipt_id: string
          updated_at: string | null
        }
        Insert: {
          content_hash: string
          content_text: string
          created_at?: string | null
          embedding: string
          embedding_model?: string
          id?: string
          metadata?: Json | null
          receipt_id: string
          updated_at?: string | null
        }
        Update: {
          content_hash?: string
          content_text?: string
          created_at?: string | null
          embedding?: string
          embedding_model?: string
          id?: string
          metadata?: Json | null
          receipt_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "receipt_embeddings_receipt_id_fkey"
            columns: ["receipt_id"]
            referencedRelation: "receipts"
            referencedColumns: ["id"]
          }
        ]
      }
      receipt_items: {
        Row: {
          barcode: string | null
          brand: string | null
          created_at: string | null
          id: string
          item_category: string | null
          item_name: string
          line_number: number | null
          ocr_confidence: number | null
          quantity: number | null
          receipt_id: string
          sku: string | null
          tax_amount: number | null
          total_price: number
          unit_price: number | null
        }
        Insert: {
          barcode?: string | null
          brand?: string | null
          created_at?: string | null
          id?: string
          item_category?: string | null
          item_name: string
          line_number?: number | null
          ocr_confidence?: number | null
          quantity?: number | null
          receipt_id: string
          sku?: string | null
          tax_amount?: number | null
          total_price: number
          unit_price?: number | null
        }
        Update: {
          barcode?: string | null
          brand?: string | null
          created_at?: string | null
          id?: string
          item_category?: string | null
          item_name?: string
          line_number?: number | null
          ocr_confidence?: number | null
          quantity?: number | null
          receipt_id?: string
          sku?: string | null
          tax_amount?: number | null
          total_price?: number
          unit_price?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "receipt_items_receipt_id_fkey"
            columns: ["receipt_id"]
            referencedRelation: "receipts"
            referencedColumns: ["id"]
          }
        ]
      }
      receipts: {
        Row: {
          category_id: string | null
          created_at: string | null
          currency: string | null
          id: string
          image_hash: string | null
          image_url: string
          is_business_expense: boolean | null
          is_reimbursable: boolean | null
          location_address: string | null
          location_lat: number | null
          location_lng: number | null
          merchant_address: string | null
          merchant_name: string
          notes: string | null
          ocr_confidence: number | null
          ocr_data: Json | null
          payment_method: string | null
          processed_data: Json | null
          purchase_date: string
          purchase_time: string | null
          tags: string[] | null
          tax_amount: number | null
          tip_amount: number | null
          total_amount: number
          updated_at: string | null
          user_id: string
        }
        Insert: {
          category_id?: string | null
          created_at?: string | null
          currency?: string | null
          id?: string
          image_hash?: string | null
          image_url: string
          is_business_expense?: boolean | null
          is_reimbursable?: boolean | null
          location_address?: string | null
          location_lat?: number | null
          location_lng?: number | null
          merchant_address?: string | null
          merchant_name: string
          notes?: string | null
          ocr_confidence?: number | null
          ocr_data?: Json | null
          payment_method?: string | null
          processed_data?: Json | null
          purchase_date: string
          purchase_time?: string | null
          tags?: string[] | null
          tax_amount?: number | null
          tip_amount?: number | null
          total_amount: number
          updated_at?: string | null
          user_id: string
        }
        Update: {
          category_id?: string | null
          created_at?: string | null
          currency?: string | null
          id?: string
          image_hash?: string | null
          image_url?: string
          is_business_expense?: boolean | null
          is_reimbursable?: boolean | null
          location_address?: string | null
          location_lat?: number | null
          location_lng?: number | null
          merchant_address?: string | null
          merchant_name?: string
          notes?: string | null
          ocr_confidence?: number | null
          ocr_data?: Json | null
          payment_method?: string | null
          processed_data?: Json | null
          purchase_date?: string
          purchase_time?: string | null
          tags?: string[] | null
          tax_amount?: number | null
          tip_amount?: number | null
          total_amount?: number
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "receipts_category_id_fkey"
            columns: ["category_id"]
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receipts_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      system_settings: {
        Row: {
          description: string | null
          key: string
          updated_at: string | null
          updated_by: string | null
          value: Json
        }
        Insert: {
          description?: string | null
          key: string
          updated_at?: string | null
          updated_by?: string | null
          value: Json
        }
        Update: {
          description?: string | null
          key?: string
          updated_at?: string | null
          updated_by?: string | null
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "system_settings_updated_by_fkey"
            columns: ["updated_by"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      user_profiles: {
        Row: {
          business_type: string | null
          created_at: string | null
          currency: string | null
          date_format: string | null
          full_name: string
          id: string
          notification_preferences: Json | null
          timezone: string | null
          updated_at: string | null
        }
        Insert: {
          business_type?: string | null
          created_at?: string | null
          currency?: string | null
          date_format?: string | null
          full_name: string
          id: string
          notification_preferences?: Json | null
          timezone?: string | null
          updated_at?: string | null
        }
        Update: {
          business_type?: string | null
          created_at?: string | null
          currency?: string | null
          date_format?: string | null
          full_name?: string
          id?: string
          notification_preferences?: Json | null
          timezone?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_profiles_id_fkey"
            columns: ["id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      warranties: {
        Row: {
          alert_preferences: Json | null
          category: string | null
          created_at: string | null
          id: string
          is_active: boolean | null
          manufacturer: string | null
          model_number: string | null
          notes: string | null
          product_name: string
          purchase_date: string
          purchase_price: number | null
          receipt_id: string | null
          registration_completed: boolean | null
          registration_date: string | null
          registration_required: boolean | null
          retailer: string | null
          serial_number: string | null
          status: Database["public"]["Enums"]["warranty_status"] | null
          updated_at: string | null
          user_id: string
          warranty_document_url: string | null
          warranty_end_date: string
          warranty_period_months: number | null
          warranty_start_date: string
          warranty_terms: string | null
          warranty_type: string | null
        }
        Insert: {
          alert_preferences?: Json | null
          category?: string | null
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          manufacturer?: string | null
          model_number?: string | null
          notes?: string | null
          product_name: string
          purchase_date: string
          purchase_price?: number | null
          receipt_id?: string | null
          registration_completed?: boolean | null
          registration_date?: string | null
          registration_required?: boolean | null
          retailer?: string | null
          serial_number?: string | null
          updated_at?: string | null
          user_id: string
          warranty_document_url?: string | null
          warranty_end_date: string
          warranty_start_date: string
          warranty_terms?: string | null
          warranty_type?: string | null
        }
        Update: {
          alert_preferences?: Json | null
          category?: string | null
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          manufacturer?: string | null
          model_number?: string | null
          notes?: string | null
          product_name?: string
          purchase_date?: string
          purchase_price?: number | null
          receipt_id?: string | null
          registration_completed?: boolean | null
          registration_date?: string | null
          registration_required?: boolean | null
          retailer?: string | null
          serial_number?: string | null
          updated_at?: string | null
          user_id?: string
          warranty_document_url?: string | null
          warranty_end_date?: string
          warranty_start_date?: string
          warranty_terms?: string | null
          warranty_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "warranties_receipt_id_fkey"
            columns: ["receipt_id"]
            referencedRelation: "receipts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warranties_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      warranty_embeddings: {
        Row: {
          content_hash: string
          content_text: string
          created_at: string | null
          embedding: string
          embedding_model: string
          id: string
          metadata: Json | null
          updated_at: string | null
          warranty_id: string
        }
        Insert: {
          content_hash: string
          content_text: string
          created_at?: string | null
          embedding: string
          embedding_model?: string
          id?: string
          metadata?: Json | null
          updated_at?: string | null
          warranty_id: string
        }
        Update: {
          content_hash?: string
          content_text?: string
          created_at?: string | null
          embedding?: string
          embedding_model?: string
          id?: string
          metadata?: Json | null
          updated_at?: string | null
          warranty_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "warranty_embeddings_warranty_id_fkey"
            columns: ["warranty_id"]
            referencedRelation: "warranties"
            referencedColumns: ["id"]
          }
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      delivery_method: "push" | "email" | "in_app"
      notification_type: "warranty_expiring" | "warranty_expired" | "system_alert" | "budget_alert"
      priority_level: "low" | "medium" | "high" | "critical"
      warranty_status: "active" | "expiring_soon" | "expired"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

// Convenience type aliases
export type UserProfile = Database['public']['Tables']['user_profiles']['Row'];
export type UserProfileInsert = Database['public']['Tables']['user_profiles']['Insert'];
export type UserProfileUpdate = Database['public']['Tables']['user_profiles']['Update'];

export type Category = Database['public']['Tables']['categories']['Row'];
export type CategoryInsert = Database['public']['Tables']['categories']['Insert'];
export type CategoryUpdate = Database['public']['Tables']['categories']['Update'];

export type Receipt = Database['public']['Tables']['receipts']['Row'];
export type ReceiptInsert = Database['public']['Tables']['receipts']['Insert'];
export type ReceiptUpdate = Database['public']['Tables']['receipts']['Update'];

export type ReceiptItem = Database['public']['Tables']['receipt_items']['Row'];
export type ReceiptItemInsert = Database['public']['Tables']['receipt_items']['Insert'];
export type ReceiptItemUpdate = Database['public']['Tables']['receipt_items']['Update'];

export type Warranty = Database['public']['Tables']['warranties']['Row'];
export type WarrantyInsert = Database['public']['Tables']['warranties']['Insert'];
export type WarrantyUpdate = Database['public']['Tables']['warranties']['Update'];

export type Notification = Database['public']['Tables']['notifications']['Row'];
export type NotificationInsert = Database['public']['Tables']['notifications']['Insert'];
export type NotificationUpdate = Database['public']['Tables']['notifications']['Update'];

export type Budget = Database['public']['Tables']['budgets']['Row'];
export type BudgetInsert = Database['public']['Tables']['budgets']['Insert'];
export type BudgetUpdate = Database['public']['Tables']['budgets']['Update'];

export type ReceiptEmbedding = Database['public']['Tables']['receipt_embeddings']['Row'];
export type ReceiptEmbeddingInsert = Database['public']['Tables']['receipt_embeddings']['Insert'];
export type ReceiptEmbeddingUpdate = Database['public']['Tables']['receipt_embeddings']['Update'];

export type WarrantyEmbedding = Database['public']['Tables']['warranty_embeddings']['Row'];
export type WarrantyEmbeddingInsert = Database['public']['Tables']['warranty_embeddings']['Insert'];
export type WarrantyEmbeddingUpdate = Database['public']['Tables']['warranty_embeddings']['Update'];

export type SystemSetting = Database['public']['Tables']['system_settings']['Row'];
export type SystemSettingInsert = Database['public']['Tables']['system_settings']['Insert'];
export type SystemSettingUpdate = Database['public']['Tables']['system_settings']['Update'];

// Enum types
export type WarrantyStatus = Database['public']['Enums']['warranty_status'];
export type NotificationType = Database['public']['Enums']['notification_type'];
export type DeliveryMethod = Database['public']['Enums']['delivery_method'];
export type PriorityLevel = Database['public']['Enums']['priority_level'];

// Extended types with relationships
export type ReceiptWithItems = Receipt & {
  receipt_items: ReceiptItem[];
  category: Category | null;
};

export type ReceiptWithCategory = Receipt & {
  category: Category | null;
};

export type WarrantyWithReceipt = Warranty & {
  receipt: Receipt | null;
};

export type NotificationWithRelated = Notification & {
  related_receipt?: Receipt;
  related_warranty?: Warranty;
};

// Search and query types
export type ReceiptSearchParams = {
  user_id: string;
  search?: string;
  category_id?: string;
  merchant_name?: string;
  start_date?: string;
  end_date?: string;
  min_amount?: number;
  max_amount?: number;
  tags?: string[];
  is_business_expense?: boolean;
  limit?: number;
  offset?: number;
};

export type WarrantySearchParams = {
  user_id: string;
  status?: WarrantyStatus;
  product_name?: string;
  manufacturer?: string;
  expiring_within_days?: number;
  limit?: number;
  offset?: number;
};

// API Response types
export type ApiResponse<T> = {
  data: T | null;
  error: string | null;
  count?: number;
  status: number;
};

export type PaginatedResponse<T> = {
  data: T[];
  count: number;
  page: number;
  per_page: number;
  total_pages: number;
};

// Vector similarity search types
export type SimilaritySearchResult<T> = T & {
  similarity_score: number;
};

export type ReceiptSimilarityResult = SimilaritySearchResult<Receipt>;
export type WarrantySimilarityResult = SimilaritySearchResult<Warranty>;