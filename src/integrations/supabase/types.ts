export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      admins: {
        Row: {
          admin_id: string
          created_at: string
          email: string | null
          id: string
          name: string
          password: string
          role_id: string | null
          society_id: string | null
        }
        Insert: {
          admin_id: string
          created_at?: string
          email?: string | null
          id?: string
          name: string
          password: string
          role_id?: string | null
          society_id?: string | null
        }
        Update: {
          admin_id?: string
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          password?: string
          role_id?: string | null
          society_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "admins_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "society_roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admins_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      approval_requests: {
        Row: {
          created_at: string
          flat_id: string
          flat_number: string
          guard_id: string
          guard_name: string
          id: string
          purpose: string | null
          responded_at: string | null
          status: string
          visitor_name: string
          visitor_phone: string | null
          visitor_photo: string | null
        }
        Insert: {
          created_at?: string
          flat_id: string
          flat_number: string
          guard_id: string
          guard_name: string
          id?: string
          purpose?: string | null
          responded_at?: string | null
          status?: string
          visitor_name: string
          visitor_phone?: string | null
          visitor_photo?: string | null
        }
        Update: {
          created_at?: string
          flat_id?: string
          flat_number?: string
          guard_id?: string
          guard_name?: string
          id?: string
          purpose?: string | null
          responded_at?: string | null
          status?: string
          visitor_name?: string
          visitor_phone?: string | null
          visitor_photo?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "approval_requests_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          created_at: string
          details: Json | null
          device_info: Json | null
          event_type: string
          id: string
          ip_address: string | null
          severity: string
          society_id: string | null
          user_agent: string | null
          user_id: string | null
          user_name: string | null
          user_type: string
        }
        Insert: {
          created_at?: string
          details?: Json | null
          device_info?: Json | null
          event_type: string
          id?: string
          ip_address?: string | null
          severity?: string
          society_id?: string | null
          user_agent?: string | null
          user_id?: string | null
          user_name?: string | null
          user_type: string
        }
        Update: {
          created_at?: string
          details?: Json | null
          device_info?: Json | null
          event_type?: string
          id?: string
          ip_address?: string | null
          severity?: string
          society_id?: string | null
          user_agent?: string | null
          user_id?: string | null
          user_name?: string | null
          user_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      bank_reconciliation_matches: {
        Row: {
          created_at: string
          finance_entry_id: string | null
          id: string
          maintenance_payment_id: string | null
          match_confidence: number
          match_type: string
          matched_at: string | null
          matched_by: string | null
          notes: string | null
          society_id: string
          statement_line_id: string
          status: string
        }
        Insert: {
          created_at?: string
          finance_entry_id?: string | null
          id?: string
          maintenance_payment_id?: string | null
          match_confidence?: number
          match_type: string
          matched_at?: string | null
          matched_by?: string | null
          notes?: string | null
          society_id: string
          statement_line_id: string
          status?: string
        }
        Update: {
          created_at?: string
          finance_entry_id?: string | null
          id?: string
          maintenance_payment_id?: string | null
          match_confidence?: number
          match_type?: string
          matched_at?: string | null
          matched_by?: string | null
          notes?: string | null
          society_id?: string
          statement_line_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "bank_reconciliation_matches_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bank_reconciliation_matches_maintenance_payment_id_fkey"
            columns: ["maintenance_payment_id"]
            isOneToOne: false
            referencedRelation: "maintenance_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bank_reconciliation_matches_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bank_reconciliation_matches_statement_line_id_fkey"
            columns: ["statement_line_id"]
            isOneToOne: false
            referencedRelation: "bank_statement_lines"
            referencedColumns: ["id"]
          },
        ]
      }
      bank_statement_imports: {
        Row: {
          account_last4: string | null
          bank_name: string | null
          created_at: string
          file_name: string | null
          id: string
          imported_by: string | null
          period_from: string
          period_to: string
          society_id: string
        }
        Insert: {
          account_last4?: string | null
          bank_name?: string | null
          created_at?: string
          file_name?: string | null
          id?: string
          imported_by?: string | null
          period_from: string
          period_to: string
          society_id: string
        }
        Update: {
          account_last4?: string | null
          bank_name?: string | null
          created_at?: string
          file_name?: string | null
          id?: string
          imported_by?: string | null
          period_from?: string
          period_to?: string
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bank_statement_imports_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      bank_statement_lines: {
        Row: {
          amount: number
          balance_after: number | null
          created_at: string
          description: string | null
          id: string
          import_id: string
          line_date: string
          raw_row: Json | null
          reference: string | null
          society_id: string
        }
        Insert: {
          amount: number
          balance_after?: number | null
          created_at?: string
          description?: string | null
          id?: string
          import_id: string
          line_date: string
          raw_row?: Json | null
          reference?: string | null
          society_id: string
        }
        Update: {
          amount?: number
          balance_after?: number | null
          created_at?: string
          description?: string | null
          id?: string
          import_id?: string
          line_date?: string
          raw_row?: Json | null
          reference?: string | null
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bank_statement_lines_import_id_fkey"
            columns: ["import_id"]
            isOneToOne: false
            referencedRelation: "bank_statement_imports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bank_statement_lines_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      biometric_credentials: {
        Row: {
          created_at: string
          credential_id: string
          id: string
          public_key: string
          user_id: string
          user_type: string
        }
        Insert: {
          created_at?: string
          credential_id: string
          id?: string
          public_key: string
          user_id: string
          user_type: string
        }
        Update: {
          created_at?: string
          credential_id?: string
          id?: string
          public_key?: string
          user_id?: string
          user_type?: string
        }
        Relationships: []
      }
      blacklist: {
        Row: {
          added_at: string
          added_by: string
          created_at: string
          id: string
          name: string | null
          phone: string | null
          reason: string
          society_id: string | null
          type: string
          vehicle_number: string | null
        }
        Insert: {
          added_at?: string
          added_by: string
          created_at?: string
          id?: string
          name?: string | null
          phone?: string | null
          reason: string
          society_id?: string | null
          type?: string
          vehicle_number?: string | null
        }
        Update: {
          added_at?: string
          added_by?: string
          created_at?: string
          id?: string
          name?: string | null
          phone?: string | null
          reason?: string
          society_id?: string | null
          type?: string
          vehicle_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "blacklist_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      committee_duties_charts: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          period_from: string
          period_to: string | null
          society_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          period_from: string
          period_to?: string | null
          society_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          period_from?: string
          period_to?: string | null
          society_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "committee_duties_charts_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      committee_duty_rows: {
        Row: {
          chart_id: string
          created_at: string
          duty_label: string
          id: string
          sort_order: number
          supervisor_names: string[]
          updated_at: string
        }
        Insert: {
          chart_id: string
          created_at?: string
          duty_label: string
          id?: string
          sort_order?: number
          supervisor_names?: string[]
          updated_at?: string
        }
        Update: {
          chart_id?: string
          created_at?: string
          duty_label?: string
          id?: string
          sort_order?: number
          supervisor_names?: string[]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "committee_duty_rows_chart_id_fkey"
            columns: ["chart_id"]
            isOneToOne: false
            referencedRelation: "committee_duties_charts"
            referencedColumns: ["id"]
          },
        ]
      }
      committee_members: {
        Row: {
          created_at: string
          flat_id: string | null
          flat_number: string | null
          flat_owner_name: string | null
          gender: string | null
          id: string
          is_active: boolean
          name: string
          phone: string | null
          photo: string | null
          position: string
          rep_name: string | null
          rep_phone: string | null
          rep_photo: string | null
          selection_type: string | null
          show_representative: boolean
          society_id: string
          sort_order: number
          source_option_id: string | null
          source_poll_id: string | null
          term_from: string | null
          term_to: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          flat_id?: string | null
          flat_number?: string | null
          flat_owner_name?: string | null
          gender?: string | null
          id?: string
          is_active?: boolean
          name: string
          phone?: string | null
          photo?: string | null
          position: string
          rep_name?: string | null
          rep_phone?: string | null
          rep_photo?: string | null
          selection_type?: string | null
          show_representative?: boolean
          society_id: string
          sort_order?: number
          source_option_id?: string | null
          source_poll_id?: string | null
          term_from?: string | null
          term_to?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          flat_id?: string | null
          flat_number?: string | null
          flat_owner_name?: string | null
          gender?: string | null
          id?: string
          is_active?: boolean
          name?: string
          phone?: string | null
          photo?: string | null
          position?: string
          rep_name?: string | null
          rep_phone?: string | null
          rep_photo?: string | null
          selection_type?: string | null
          show_representative?: boolean
          society_id?: string
          sort_order?: number
          source_option_id?: string | null
          source_poll_id?: string | null
          term_from?: string | null
          term_to?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "committee_members_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "committee_members_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "committee_members_source_option_id_fkey"
            columns: ["source_option_id"]
            isOneToOne: false
            referencedRelation: "poll_options"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "committee_members_source_poll_id_fkey"
            columns: ["source_poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
        ]
      }
      donation_campaigns: {
        Row: {
          collected_amount: number | null
          created_at: string
          created_by: string | null
          description: string | null
          end_date: string | null
          id: string
          society_id: string | null
          status: string
          target_amount: number | null
          title: string
        }
        Insert: {
          collected_amount?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          society_id?: string | null
          status?: string
          target_amount?: number | null
          title: string
        }
        Update: {
          collected_amount?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          society_id?: string | null
          status?: string
          target_amount?: number | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "donation_campaigns_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      donation_payments: {
        Row: {
          amount: number
          campaign_id: string | null
          created_at: string
          flat_id: string | null
          flat_number: string
          id: string
          notes: string | null
          payment_method: string
          resident_name: string | null
          screenshot_url: string | null
          transaction_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          campaign_id?: string | null
          created_at?: string
          flat_id?: string | null
          flat_number: string
          id?: string
          notes?: string | null
          payment_method?: string
          resident_name?: string | null
          screenshot_url?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          campaign_id?: string | null
          created_at?: string
          flat_id?: string | null
          flat_number?: string
          id?: string
          notes?: string | null
          payment_method?: string
          resident_name?: string | null
          screenshot_url?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "donation_payments_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "donation_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "donation_payments_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      election_audit_events: {
        Row: {
          actor_id: string | null
          actor_name: string | null
          actor_type: string | null
          created_at: string
          event_type: string
          id: string
          payload: Json
          poll_id: string | null
          society_id: string
        }
        Insert: {
          actor_id?: string | null
          actor_name?: string | null
          actor_type?: string | null
          created_at?: string
          event_type: string
          id?: string
          payload?: Json
          poll_id?: string | null
          society_id: string
        }
        Update: {
          actor_id?: string | null
          actor_name?: string | null
          actor_type?: string | null
          created_at?: string
          event_type?: string
          id?: string
          payload?: Json
          poll_id?: string | null
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "election_audit_events_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "election_audit_events_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      election_proxies: {
        Row: {
          authorization_document_url: string | null
          authorization_notes: string | null
          created_at: string
          id: string
          meeting_at: string | null
          poll_id: string
          principal_member_id: string
          proxy_holder_member_id: string
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          society_id: string
          status: string
          submitted_at: string
          submitted_by: string | null
        }
        Insert: {
          authorization_document_url?: string | null
          authorization_notes?: string | null
          created_at?: string
          id?: string
          meeting_at?: string | null
          poll_id: string
          principal_member_id: string
          proxy_holder_member_id: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          society_id: string
          status?: string
          submitted_at?: string
          submitted_by?: string | null
        }
        Update: {
          authorization_document_url?: string | null
          authorization_notes?: string | null
          created_at?: string
          id?: string
          meeting_at?: string | null
          poll_id?: string
          principal_member_id?: string
          proxy_holder_member_id?: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          society_id?: string
          status?: string
          submitted_at?: string
          submitted_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "election_proxies_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "election_proxies_principal_member_id_fkey"
            columns: ["principal_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "election_proxies_proxy_holder_member_id_fkey"
            columns: ["proxy_holder_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "election_proxies_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_alerts: {
        Row: {
          created_at: string
          id: string
          media_items: Json
          message: string
          notification_id: string | null
          push_sent: number
          sender_flat_number: string | null
          sender_name: string
          sender_role: string
          society_id: string
          title: string
          whatsapp_failed: number
          whatsapp_sent: number
        }
        Insert: {
          created_at?: string
          id?: string
          media_items?: Json
          message: string
          notification_id?: string | null
          push_sent?: number
          sender_flat_number?: string | null
          sender_name: string
          sender_role: string
          society_id: string
          title: string
          whatsapp_failed?: number
          whatsapp_sent?: number
        }
        Update: {
          created_at?: string
          id?: string
          media_items?: Json
          message?: string
          notification_id?: string | null
          push_sent?: number
          sender_flat_number?: string | null
          sender_name?: string
          sender_role?: string
          society_id?: string
          title?: string
          whatsapp_failed?: number
          whatsapp_sent?: number
        }
        Relationships: [
          {
            foreignKeyName: "emergency_alerts_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "emergency_alerts_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      event_contributions: {
        Row: {
          adult_count: number | null
          amount: number
          batch_id: string | null
          batch_label: string | null
          contributor_type: string
          created_at: string
          event_id: string | null
          flat_id: string | null
          flat_number: string | null
          id: string
          kid_count: number | null
          outsider_name: string | null
          payment_method: string
          receipt_basis: string
          resident_name: string | null
          screenshot_url: string | null
          split_mode: string | null
          transaction_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          adult_count?: number | null
          amount: number
          batch_id?: string | null
          batch_label?: string | null
          contributor_type?: string
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          kid_count?: number | null
          outsider_name?: string | null
          payment_method?: string
          receipt_basis?: string
          resident_name?: string | null
          screenshot_url?: string | null
          split_mode?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          adult_count?: number | null
          amount?: number
          batch_id?: string | null
          batch_label?: string | null
          contributor_type?: string
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          kid_count?: number | null
          outsider_name?: string | null
          payment_method?: string
          receipt_basis?: string
          resident_name?: string | null
          screenshot_url?: string | null
          split_mode?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_contributions_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_contributions_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      event_food_fund_adjustments: {
        Row: {
          adjustment_kind: string
          amount: number
          created_at: string
          created_by: string | null
          event_id: string | null
          flat_id: string | null
          flat_number: string | null
          id: string
          notes: string | null
          payment_method: string
          society_id: string
          source_type: string
        }
        Insert: {
          adjustment_kind: string
          amount: number
          created_at?: string
          created_by?: string | null
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          notes?: string | null
          payment_method?: string
          society_id: string
          source_type: string
        }
        Update: {
          adjustment_kind?: string
          amount?: number
          created_at?: string
          created_by?: string | null
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          notes?: string | null
          payment_method?: string
          society_id?: string
          source_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_food_fund_adjustments_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_food_fund_adjustments_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_food_fund_adjustments_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      event_rsvps: {
        Row: {
          created_at: string
          event_id: string | null
          flat_id: string | null
          flat_number: string
          id: string
          members_count: number | null
          resident_name: string | null
          status: string
        }
        Insert: {
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number: string
          id?: string
          members_count?: number | null
          resident_name?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string
          id?: string
          members_count?: number | null
          resident_name?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_rsvps_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_rsvps_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          contribution_amount: number | null
          created_at: string
          created_by: string | null
          description: string | null
          event_date: string
          event_time: string | null
          id: string
          location: string | null
          society_id: string | null
          status: string
          title: string
        }
        Insert: {
          contribution_amount?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_date: string
          event_time?: string | null
          id?: string
          location?: string | null
          society_id?: string | null
          status?: string
          title: string
        }
        Update: {
          contribution_amount?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_date?: string
          event_time?: string | null
          id?: string
          location?: string | null
          society_id?: string | null
          status?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      expense_groups: {
        Row: {
          adult_weight: number
          child_weight: number
          created_at: string
          created_by: string | null
          description: string | null
          event_id: string | null
          group_kind: string
          id: string
          major_head: string | null
          name: string
          society_id: string | null
        }
        Insert: {
          adult_weight?: number
          child_weight?: number
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_id?: string | null
          group_kind?: string
          id?: string
          major_head?: string | null
          name: string
          society_id?: string | null
        }
        Update: {
          adult_weight?: number
          child_weight?: number
          created_at?: string
          created_by?: string | null
          description?: string | null
          event_id?: string | null
          group_kind?: string
          id?: string
          major_head?: string | null
          name?: string
          society_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_groups_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_groups_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      expense_splits: {
        Row: {
          amount: number
          created_at: string
          expense_id: string | null
          flat_number: string
          id: string
          is_settled: boolean
          resident_name: string | null
          settled_at: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          expense_id?: string | null
          flat_number: string
          id?: string
          is_settled?: boolean
          resident_name?: string | null
          settled_at?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          expense_id?: string | null
          flat_number?: string
          id?: string
          is_settled?: boolean
          resident_name?: string | null
          settled_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_splits_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["id"]
          },
        ]
      }
      expenses: {
        Row: {
          attachment_urls: Json
          bill_screenshot_url: string | null
          created_at: string
          expense_category: string
          expense_date: string
          group_id: string | null
          id: string
          notes: string | null
          paid_by_flat: string
          paid_by_flats: Json
          paid_by_name: string | null
          payment_method: string
          record_status: string
          recording_date: string
          service_kind: string
          split_type: string
          title: string
          total_amount: number
          vendor_or_service: string | null
        }
        Insert: {
          attachment_urls?: Json
          bill_screenshot_url?: string | null
          created_at?: string
          expense_category?: string
          expense_date?: string
          group_id?: string | null
          id?: string
          notes?: string | null
          paid_by_flat: string
          paid_by_flats?: Json
          paid_by_name?: string | null
          payment_method?: string
          record_status?: string
          recording_date?: string
          service_kind?: string
          split_type?: string
          title: string
          total_amount: number
          vendor_or_service?: string | null
        }
        Update: {
          attachment_urls?: Json
          bill_screenshot_url?: string | null
          created_at?: string
          expense_category?: string
          expense_date?: string
          group_id?: string | null
          id?: string
          notes?: string | null
          paid_by_flat?: string
          paid_by_flats?: Json
          paid_by_name?: string | null
          payment_method?: string
          record_status?: string
          recording_date?: string
          service_kind?: string
          split_type?: string
          title?: string
          total_amount?: number
          vendor_or_service?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expenses_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "expense_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      fcm_web_tokens: {
        Row: {
          app_user_id: string
          flat_number: string | null
          id: string
          society_id: string | null
          token: string
          updated_at: string
          user_type: string
        }
        Insert: {
          app_user_id: string
          flat_number?: string | null
          id?: string
          society_id?: string | null
          token: string
          updated_at?: string
          user_type: string
        }
        Update: {
          app_user_id?: string
          flat_number?: string | null
          id?: string
          society_id?: string | null
          token?: string
          updated_at?: string
          user_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "fcm_web_tokens_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_entries: {
        Row: {
          aggregate_flat_count: number
          allocation_style: string
          charge_id: string | null
          created_at: string
          created_by: string | null
          destination: string
          distributed_at: string | null
          entry_month: string | null
          expense_id: string | null
          id: string
          include_vacant: boolean
          notes: string | null
          payment_method: string
          payment_status: string
          record_mode: string
          screenshot_url: string | null
          society_id: string
          title: string | null
          total_amount: number
          transaction_date: string | null
          transaction_id: string | null
        }
        Insert: {
          aggregate_flat_count?: number
          allocation_style?: string
          charge_id?: string | null
          created_at?: string
          created_by?: string | null
          destination?: string
          distributed_at?: string | null
          entry_month?: string | null
          expense_id?: string | null
          id?: string
          include_vacant?: boolean
          notes?: string | null
          payment_method?: string
          payment_status?: string
          record_mode?: string
          screenshot_url?: string | null
          society_id: string
          title?: string | null
          total_amount?: number
          transaction_date?: string | null
          transaction_id?: string | null
        }
        Update: {
          aggregate_flat_count?: number
          allocation_style?: string
          charge_id?: string | null
          created_at?: string
          created_by?: string | null
          destination?: string
          distributed_at?: string | null
          entry_month?: string | null
          expense_id?: string | null
          id?: string
          include_vacant?: boolean
          notes?: string | null
          payment_method?: string
          payment_status?: string
          record_mode?: string
          screenshot_url?: string | null
          society_id?: string
          title?: string | null
          total_amount?: number
          transaction_date?: string | null
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_entries_charge_id_fkey"
            columns: ["charge_id"]
            isOneToOne: false
            referencedRelation: "maintenance_charges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_entries_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_entries_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_entry_allocations: {
        Row: {
          amount: number
          created_at: string
          finance_entry_id: string
          flat_id: string | null
          flat_number: string
          id: string
        }
        Insert: {
          amount?: number
          created_at?: string
          finance_entry_id: string
          flat_id?: string | null
          flat_number: string
          id?: string
        }
        Update: {
          amount?: number
          created_at?: string
          finance_entry_id?: string
          flat_id?: string | null
          flat_number?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_entry_allocations_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_entry_allocations_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_entry_counterparties: {
        Row: {
          finance_entry_id: string
          id: string
          name: string
          relation_to_society: string | null
        }
        Insert: {
          finance_entry_id: string
          id?: string
          name: string
          relation_to_society?: string | null
        }
        Update: {
          finance_entry_id?: string
          id?: string
          name?: string
          relation_to_society?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_entry_counterparties_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: true
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_opening_balance_anchors: {
        Row: {
          as_on_date: string
          bank_amount: number | null
          cash_amount: number | null
          created_at: string
          id: string
          notes: string | null
          other_amount: number | null
          society_id: string
          updated_at: string
        }
        Insert: {
          as_on_date: string
          bank_amount?: number | null
          cash_amount?: number | null
          created_at?: string
          id?: string
          notes?: string | null
          other_amount?: number | null
          society_id: string
          updated_at?: string
        }
        Update: {
          as_on_date?: string
          bank_amount?: number | null
          cash_amount?: number | null
          created_at?: string
          id?: string
          notes?: string | null
          other_amount?: number | null
          society_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_opening_balance_anchors_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_reminder_dispatch_log: {
        Row: {
          charge_id: string
          created_at: string
          flat_number: string
          id: string
          reminder_date: string
          reminder_slot: string
          society_id: string
        }
        Insert: {
          charge_id: string
          created_at?: string
          flat_number: string
          id?: string
          reminder_date: string
          reminder_slot: string
          society_id: string
        }
        Update: {
          charge_id?: string
          created_at?: string
          flat_number?: string
          id?: string
          reminder_date?: string
          reminder_slot?: string
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_reminder_dispatch_log_charge_id_fkey"
            columns: ["charge_id"]
            isOneToOne: false
            referencedRelation: "maintenance_charges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_reminder_dispatch_log_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_reminder_settings: {
        Row: {
          created_at: string
          due_day: number
          enabled: boolean
          id: string
          schedule: string
          society_id: string
          timezone: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          due_day?: number
          enabled?: boolean
          id?: string
          schedule?: string
          society_id: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          due_day?: number
          enabled?: boolean
          id?: string
          schedule?: string
          society_id?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_reminder_settings_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: true
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      fixed_assets: {
        Row: {
          acquisition_date: string | null
          amc_end_date: string | null
          amc_period_months: number | null
          amc_start_date: string | null
          amc_vendor: string | null
          asset_name: string
          asset_tag: string | null
          bill_attachment_url: string | null
          bill_value: number | null
          created_at: string
          created_by: string | null
          description: string | null
          disposal_date: string | null
          disposal_notes: string | null
          disposal_value: number | null
          expense_group_id: string | null
          expense_id: string | null
          finance_entry_id: string | null
          id: string
          location: string | null
          major_head: string
          notes: string | null
          serial_number: string | null
          society_id: string
          source_type: string
          status: string
          sub_head: string | null
          template_key: string | null
          updated_at: string
          vendor_contact: string | null
          vendor_name: string | null
          warranty_end_date: string | null
          warranty_period_months: number | null
          warranty_start_date: string | null
        }
        Insert: {
          acquisition_date?: string | null
          amc_end_date?: string | null
          amc_period_months?: number | null
          amc_start_date?: string | null
          amc_vendor?: string | null
          asset_name: string
          asset_tag?: string | null
          bill_attachment_url?: string | null
          bill_value?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          disposal_date?: string | null
          disposal_notes?: string | null
          disposal_value?: number | null
          expense_group_id?: string | null
          expense_id?: string | null
          finance_entry_id?: string | null
          id?: string
          location?: string | null
          major_head?: string
          notes?: string | null
          serial_number?: string | null
          society_id: string
          source_type?: string
          status?: string
          sub_head?: string | null
          template_key?: string | null
          updated_at?: string
          vendor_contact?: string | null
          vendor_name?: string | null
          warranty_end_date?: string | null
          warranty_period_months?: number | null
          warranty_start_date?: string | null
        }
        Update: {
          acquisition_date?: string | null
          amc_end_date?: string | null
          amc_period_months?: number | null
          amc_start_date?: string | null
          amc_vendor?: string | null
          asset_name?: string
          asset_tag?: string | null
          bill_attachment_url?: string | null
          bill_value?: number | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          disposal_date?: string | null
          disposal_notes?: string | null
          disposal_value?: number | null
          expense_group_id?: string | null
          expense_id?: string | null
          finance_entry_id?: string | null
          id?: string
          location?: string | null
          major_head?: string
          notes?: string | null
          serial_number?: string | null
          society_id?: string
          source_type?: string
          status?: string
          sub_head?: string | null
          template_key?: string | null
          updated_at?: string
          vendor_contact?: string | null
          vendor_name?: string | null
          warranty_end_date?: string | null
          warranty_period_months?: number | null
          warranty_start_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fixed_assets_expense_group_id_fkey"
            columns: ["expense_group_id"]
            isOneToOne: false
            referencedRelation: "expense_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixed_assets_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixed_assets_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: true
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fixed_assets_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      flats: {
        Row: {
          created_at: string
          designated_voter_member_id: string | null
          flat_number: string
          flat_type: string | null
          floor: string | null
          id: string
          intercom: string | null
          is_occupied: boolean | null
          owner_lives_here: boolean
          owner_name: string | null
          owner_phone: string | null
          society_id: string | null
          tenant_household_type: string | null
          wing: string | null
        }
        Insert: {
          created_at?: string
          designated_voter_member_id?: string | null
          flat_number: string
          flat_type?: string | null
          floor?: string | null
          id?: string
          intercom?: string | null
          is_occupied?: boolean | null
          owner_lives_here?: boolean
          owner_name?: string | null
          owner_phone?: string | null
          society_id?: string | null
          tenant_household_type?: string | null
          wing?: string | null
        }
        Update: {
          created_at?: string
          designated_voter_member_id?: string | null
          flat_number?: string
          flat_type?: string | null
          floor?: string | null
          id?: string
          intercom?: string | null
          is_occupied?: boolean | null
          owner_lives_here?: boolean
          owner_name?: string | null
          owner_phone?: string | null
          society_id?: string | null
          tenant_household_type?: string | null
          wing?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "flats_designated_voter_member_id_fkey"
            columns: ["designated_voter_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "flats_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      geofence_settings: {
        Row: {
          created_at: string
          id: string
          latitude: number
          longitude: number
          radius_meters: number
          set_by: string
          society_id: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          latitude: number
          longitude: number
          radius_meters?: number
          set_by: string
          society_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          latitude?: number
          longitude?: number
          radius_meters?: number
          set_by?: string
          society_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "geofence_settings_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_attachments: {
        Row: {
          created_at: string
          doc_label: string
          file_name: string | null
          file_url: string
          guard_id: string
          id: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          doc_label?: string
          file_name?: string | null
          file_url: string
          guard_id: string
          id?: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          doc_label?: string
          file_name?: string | null
          file_url?: string
          guard_id?: string
          id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "guard_attachments_guard_id_fkey"
            columns: ["guard_id"]
            isOneToOne: false
            referencedRelation: "guards"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_daily_duty: {
        Row: {
          created_at: string
          duty_date: string
          guard_id: string
          guard_name: string
          guard_uuid: string
          id: string
          shift_id: string
          society_id: string
          status: string
          submitted_at: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          duty_date?: string
          guard_id: string
          guard_name: string
          guard_uuid: string
          id?: string
          shift_id: string
          society_id: string
          status?: string
          submitted_at?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          duty_date?: string
          guard_id?: string
          guard_name?: string
          guard_uuid?: string
          id?: string
          shift_id?: string
          society_id?: string
          status?: string
          submitted_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guard_daily_duty_guard_uuid_fkey"
            columns: ["guard_uuid"]
            isOneToOne: false
            referencedRelation: "guards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guard_daily_duty_shift_id_fkey"
            columns: ["shift_id"]
            isOneToOne: true
            referencedRelation: "guard_shifts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guard_daily_duty_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_documents: {
        Row: {
          back_url: string | null
          created_at: string
          doc_label: string
          front_url: string | null
          guard_id: string
          id: string
        }
        Insert: {
          back_url?: string | null
          created_at?: string
          doc_label?: string
          front_url?: string | null
          guard_id: string
          id?: string
        }
        Update: {
          back_url?: string | null
          created_at?: string
          doc_label?: string
          front_url?: string | null
          guard_id?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "guard_documents_guard_id_fkey"
            columns: ["guard_id"]
            isOneToOne: false
            referencedRelation: "guards"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_duty_incidents: {
        Row: {
          category: string
          created_at: string
          duty_id: string
          flat_number: string | null
          id: string
          photo_urls: Json
          problem_preset: string | null
          severity: string
        }
        Insert: {
          category: string
          created_at?: string
          duty_id: string
          flat_number?: string | null
          id?: string
          photo_urls?: Json
          problem_preset?: string | null
          severity?: string
        }
        Update: {
          category?: string
          created_at?: string
          duty_id?: string
          flat_number?: string | null
          id?: string
          photo_urls?: Json
          problem_preset?: string | null
          severity?: string
        }
        Relationships: [
          {
            foreignKeyName: "guard_duty_incidents_duty_id_fkey"
            columns: ["duty_id"]
            isOneToOne: false
            referencedRelation: "guard_daily_duty"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_duty_staff_attendance: {
        Row: {
          absence_reason: string | null
          duty_id: string
          id: string
          staff_name: string | null
          staff_role: string
          status: string
          updated_at: string
        }
        Insert: {
          absence_reason?: string | null
          duty_id: string
          id?: string
          staff_name?: string | null
          staff_role: string
          status?: string
          updated_at?: string
        }
        Update: {
          absence_reason?: string | null
          duty_id?: string
          id?: string
          staff_name?: string | null
          staff_role?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guard_duty_staff_attendance_duty_id_fkey"
            columns: ["duty_id"]
            isOneToOne: false
            referencedRelation: "guard_daily_duty"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_duty_system_checks: {
        Row: {
          check_key: string
          duty_id: string
          id: string
          problem_preset: string | null
          status: string
          updated_at: string
        }
        Insert: {
          check_key: string
          duty_id: string
          id?: string
          problem_preset?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          check_key?: string
          duty_id?: string
          id?: string
          problem_preset?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guard_duty_system_checks_duty_id_fkey"
            columns: ["duty_id"]
            isOneToOne: false
            referencedRelation: "guard_daily_duty"
            referencedColumns: ["id"]
          },
        ]
      }
      guard_shifts: {
        Row: {
          created_at: string
          guard_id: string
          guard_name: string
          id: string
          login_time: string
          logout_time: string | null
          society_id: string | null
        }
        Insert: {
          created_at?: string
          guard_id: string
          guard_name: string
          id?: string
          login_time?: string
          logout_time?: string | null
          society_id?: string | null
        }
        Update: {
          created_at?: string
          guard_id?: string
          guard_name?: string
          id?: string
          login_time?: string
          logout_time?: string | null
          society_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guard_shifts_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      guards: {
        Row: {
          auth_mode: string
          created_at: string
          guard_id: string
          id: string
          kyc_alert_days: number
          name: string
          password: string
          phone: string | null
          photo_url: string | null
          police_verification: string
          police_verification_date: string | null
          society_id: string | null
        }
        Insert: {
          auth_mode?: string
          created_at?: string
          guard_id: string
          id?: string
          kyc_alert_days?: number
          name: string
          password: string
          phone?: string | null
          photo_url?: string | null
          police_verification?: string
          police_verification_date?: string | null
          society_id?: string | null
        }
        Update: {
          auth_mode?: string
          created_at?: string
          guard_id?: string
          id?: string
          kyc_alert_days?: number
          name?: string
          password?: string
          phone?: string | null
          photo_url?: string | null
          police_verification?: string
          police_verification_date?: string | null
          society_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guards_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      head_fund_adjustments: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          expense_group_id: string
          finance_entry_id: string | null
          flat_id: string | null
          flat_number: string | null
          id: string
          notes: string | null
          society_id: string
          source_type: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          expense_group_id: string
          finance_entry_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          notes?: string | null
          society_id: string
          source_type: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          expense_group_id?: string
          finance_entry_id?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          notes?: string | null
          society_id?: string
          source_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "head_fund_adjustments_expense_group_id_fkey"
            columns: ["expense_group_id"]
            isOneToOne: false
            referencedRelation: "expense_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "head_fund_adjustments_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "head_fund_adjustments_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "head_fund_adjustments_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      maintenance_charges: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          due_day: number
          expense_group_id: string | null
          frequency: string
          id: string
          is_active: boolean
          society_id: string | null
          title: string
        }
        Insert: {
          amount?: number
          created_at?: string
          created_by?: string | null
          due_day?: number
          expense_group_id?: string | null
          frequency?: string
          id?: string
          is_active?: boolean
          society_id?: string | null
          title: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          due_day?: number
          expense_group_id?: string | null
          frequency?: string
          id?: string
          is_active?: boolean
          society_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "maintenance_charges_expense_group_id_fkey"
            columns: ["expense_group_id"]
            isOneToOne: false
            referencedRelation: "expense_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "maintenance_charges_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      maintenance_payments: {
        Row: {
          amount: number
          charge_id: string | null
          created_at: string
          due_date: string
          finance_entry_id: string | null
          flat_id: string | null
          flat_number: string
          id: string
          notes: string | null
          payment_date: string | null
          payment_method: string
          payment_status: string
          recording_date: string
          rejection_reason: string | null
          resident_name: string | null
          reviewed_at: string | null
          screenshot_url: string | null
          submitted_by: string
          submitted_by_user_id: string | null
          transaction_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          charge_id?: string | null
          created_at?: string
          due_date: string
          finance_entry_id?: string | null
          flat_id?: string | null
          flat_number: string
          id?: string
          notes?: string | null
          payment_date?: string | null
          payment_method?: string
          payment_status?: string
          recording_date?: string
          rejection_reason?: string | null
          resident_name?: string | null
          reviewed_at?: string | null
          screenshot_url?: string | null
          submitted_by?: string
          submitted_by_user_id?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          charge_id?: string | null
          created_at?: string
          due_date?: string
          finance_entry_id?: string | null
          flat_id?: string | null
          flat_number?: string
          id?: string
          notes?: string | null
          payment_date?: string | null
          payment_method?: string
          payment_status?: string
          recording_date?: string
          rejection_reason?: string | null
          resident_name?: string | null
          reviewed_at?: string | null
          screenshot_url?: string | null
          submitted_by?: string
          submitted_by_user_id?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "maintenance_payments_charge_id_fkey"
            columns: ["charge_id"]
            isOneToOne: false
            referencedRelation: "maintenance_charges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "maintenance_payments_finance_entry_id_fkey"
            columns: ["finance_entry_id"]
            isOneToOne: false
            referencedRelation: "finance_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "maintenance_payments_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      meeting_attendees: {
        Row: {
          attendee_role: string
          created_at: string
          display_name: string
          flat_number: string | null
          guest_name: string | null
          id: string
          is_present: boolean
          meeting_id: string
          member_id: string | null
        }
        Insert: {
          attendee_role?: string
          created_at?: string
          display_name: string
          flat_number?: string | null
          guest_name?: string | null
          id?: string
          is_present?: boolean
          meeting_id: string
          member_id?: string | null
        }
        Update: {
          attendee_role?: string
          created_at?: string
          display_name?: string
          flat_number?: string | null
          guest_name?: string | null
          id?: string
          is_present?: boolean
          meeting_id?: string
          member_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "meeting_attendees_meeting_id_fkey"
            columns: ["meeting_id"]
            isOneToOne: false
            referencedRelation: "meetings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meeting_attendees_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      meeting_decisions: {
        Row: {
          created_at: string
          decision_text: string
          id: string
          meeting_id: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          decision_text: string
          id?: string
          meeting_id: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          decision_text?: string
          id?: string
          meeting_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "meeting_decisions_meeting_id_fkey"
            columns: ["meeting_id"]
            isOneToOne: false
            referencedRelation: "meetings"
            referencedColumns: ["id"]
          },
        ]
      }
      meeting_document_signatures: {
        Row: {
          id: string
          meeting_attendee_id: string
          meeting_document_id: string
          signature_image_url: string
          signed_at: string
          signer_label: string | null
        }
        Insert: {
          id?: string
          meeting_attendee_id: string
          meeting_document_id: string
          signature_image_url: string
          signed_at?: string
          signer_label?: string | null
        }
        Update: {
          id?: string
          meeting_attendee_id?: string
          meeting_document_id?: string
          signature_image_url?: string
          signed_at?: string
          signer_label?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "meeting_document_signatures_meeting_attendee_id_fkey"
            columns: ["meeting_attendee_id"]
            isOneToOne: false
            referencedRelation: "meeting_attendees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meeting_document_signatures_meeting_document_id_fkey"
            columns: ["meeting_document_id"]
            isOneToOne: false
            referencedRelation: "meeting_documents"
            referencedColumns: ["id"]
          },
        ]
      }
      meeting_documents: {
        Row: {
          created_at: string
          file_name: string | null
          file_url: string
          id: string
          meeting_id: string
          mime_type: string | null
          sort_order: number
          title: string
        }
        Insert: {
          created_at?: string
          file_name?: string | null
          file_url: string
          id?: string
          meeting_id: string
          mime_type?: string | null
          sort_order?: number
          title: string
        }
        Update: {
          created_at?: string
          file_name?: string | null
          file_url?: string
          id?: string
          meeting_id?: string
          mime_type?: string | null
          sort_order?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "meeting_documents_meeting_id_fkey"
            columns: ["meeting_id"]
            isOneToOne: false
            referencedRelation: "meetings"
            referencedColumns: ["id"]
          },
        ]
      }
      meetings: {
        Row: {
          audio_recording_url: string | null
          created_at: string
          created_by: string | null
          description: string | null
          discussion_notes: string | null
          executives_present: string | null
          id: string
          location: string | null
          meeting_at: string
          meeting_kind: string
          minutes_summary: string | null
          published: boolean
          society_id: string
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          audio_recording_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          discussion_notes?: string | null
          executives_present?: string | null
          id?: string
          location?: string | null
          meeting_at?: string
          meeting_kind?: string
          minutes_summary?: string | null
          published?: boolean
          society_id: string
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          audio_recording_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          discussion_notes?: string | null
          executives_present?: string | null
          id?: string
          location?: string | null
          meeting_at?: string
          meeting_kind?: string
          minutes_summary?: string | null
          published?: boolean
          society_id?: string
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "meetings_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      member_documents: {
        Row: {
          back_url: string | null
          created_at: string
          doc_kind: string
          doc_type: string
          front_url: string | null
          id: string
          member_id: string
        }
        Insert: {
          back_url?: string | null
          created_at?: string
          doc_kind: string
          doc_type: string
          front_url?: string | null
          id?: string
          member_id: string
        }
        Update: {
          back_url?: string | null
          created_at?: string
          doc_kind?: string
          doc_type?: string
          front_url?: string | null
          id?: string
          member_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "member_documents_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      members: {
        Row: {
          age: number | null
          created_at: string
          date_joining: string | null
          date_leave: string | null
          election_disqualified_until: string | null
          flat_id: string
          gender: string | null
          household_group: string
          id: string
          id_photo_back: string | null
          id_photo_front: string | null
          is_primary: boolean | null
          name: string
          phone: string | null
          photo: string | null
          police_verification: string | null
          relation: string | null
          spouse_name: string | null
          whatsapp_phone: string | null
        }
        Insert: {
          age?: number | null
          created_at?: string
          date_joining?: string | null
          date_leave?: string | null
          election_disqualified_until?: string | null
          flat_id: string
          gender?: string | null
          household_group?: string
          id?: string
          id_photo_back?: string | null
          id_photo_front?: string | null
          is_primary?: boolean | null
          name: string
          phone?: string | null
          photo?: string | null
          police_verification?: string | null
          relation?: string | null
          spouse_name?: string | null
          whatsapp_phone?: string | null
        }
        Update: {
          age?: number | null
          created_at?: string
          date_joining?: string | null
          date_leave?: string | null
          election_disqualified_until?: string | null
          flat_id?: string
          gender?: string | null
          household_group?: string
          id?: string
          id_photo_back?: string | null
          id_photo_front?: string | null
          is_primary?: boolean | null
          name?: string
          phone?: string | null
          photo?: string | null
          police_verification?: string | null
          relation?: string | null
          spouse_name?: string | null
          whatsapp_phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "members_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_comments: {
        Row: {
          author_flat_number: string | null
          author_name: string
          author_resident_id: string | null
          author_role: string
          body: string
          created_at: string
          id: string
          notification_id: string
        }
        Insert: {
          author_flat_number?: string | null
          author_name: string
          author_resident_id?: string | null
          author_role?: string
          body: string
          created_at?: string
          id?: string
          notification_id: string
        }
        Update: {
          author_flat_number?: string | null
          author_name?: string
          author_resident_id?: string | null
          author_role?: string
          body?: string
          created_at?: string
          id?: string
          notification_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_comments_author_resident_id_fkey"
            columns: ["author_resident_id"]
            isOneToOne: false
            referencedRelation: "resident_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_comments_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_dismissals: {
        Row: {
          dismissed_at: string
          id: string
          notification_id: string
          resident_id: string
        }
        Insert: {
          dismissed_at?: string
          id?: string
          notification_id: string
          resident_id: string
        }
        Update: {
          dismissed_at?: string
          id?: string
          notification_id?: string
          resident_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_dismissals_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_dismissals_resident_id_fkey"
            columns: ["resident_id"]
            isOneToOne: false
            referencedRelation: "resident_users"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          created_by: string | null
          delivery_batch_id: string | null
          id: string
          is_read: boolean
          media_items: Json
          message: string
          read_at: string | null
          society_id: string | null
          sound_custom_url: string | null
          sound_key: string
          target_id: string | null
          target_type: string
          title: string
          type: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          delivery_batch_id?: string | null
          id?: string
          is_read?: boolean
          media_items?: Json
          message: string
          read_at?: string | null
          society_id?: string | null
          sound_custom_url?: string | null
          sound_key?: string
          target_id?: string | null
          target_type?: string
          title: string
          type?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          delivery_batch_id?: string | null
          id?: string
          is_read?: boolean
          media_items?: Json
          message?: string
          read_at?: string | null
          society_id?: string | null
          sound_custom_url?: string | null
          sound_key?: string
          target_id?: string | null
          target_type?: string
          title?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      otp_codes: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          otp_code: string
          phone: string
          used: boolean
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          otp_code: string
          phone: string
          used?: boolean
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          otp_code?: string
          phone?: string
          used?: boolean
        }
        Relationships: []
      }
      parking_spaces: {
        Row: {
          allocated_flat_id: string | null
          allocated_flat_number: string | null
          allocated_vehicle_number: string | null
          created_at: string
          floor_level: string | null
          id: string
          is_allocated: boolean
          notes: string | null
          society_id: string | null
          space_number: string
          space_type: string
        }
        Insert: {
          allocated_flat_id?: string | null
          allocated_flat_number?: string | null
          allocated_vehicle_number?: string | null
          created_at?: string
          floor_level?: string | null
          id?: string
          is_allocated?: boolean
          notes?: string | null
          society_id?: string | null
          space_number: string
          space_type?: string
        }
        Update: {
          allocated_flat_id?: string | null
          allocated_flat_number?: string | null
          allocated_vehicle_number?: string | null
          created_at?: string
          floor_level?: string | null
          id?: string
          is_allocated?: boolean
          notes?: string | null
          society_id?: string | null
          space_number?: string
          space_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "parking_spaces_allocated_flat_id_fkey"
            columns: ["allocated_flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parking_spaces_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      password_reset_tokens: {
        Row: {
          created_at: string
          email: string
          expires_at: string
          id: string
          token: string
          used: boolean
          user_id: string
          user_type: string
        }
        Insert: {
          created_at?: string
          email: string
          expires_at: string
          id?: string
          token: string
          used?: boolean
          user_id: string
          user_type: string
        }
        Update: {
          created_at?: string
          email?: string
          expires_at?: string
          id?: string
          token?: string
          used?: boolean
          user_id?: string
          user_type?: string
        }
        Relationships: []
      }
      platform_branding: {
        Row: {
          app_name: string
          background_color: string
          id: string
          logo_url: string | null
          primary_color: string
          primary_dark_color: string
          tagline: string | null
          updated_at: string
        }
        Insert: {
          app_name?: string
          background_color?: string
          id?: string
          logo_url?: string | null
          primary_color?: string
          primary_dark_color?: string
          tagline?: string | null
          updated_at?: string
        }
        Update: {
          app_name?: string
          background_color?: string
          id?: string
          logo_url?: string | null
          primary_color?: string
          primary_dark_color?: string
          tagline?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      poll_documents: {
        Row: {
          created_at: string
          created_by: string | null
          doc_kind: string
          file_name: string | null
          file_url: string
          id: string
          mime_type: string | null
          poll_id: string
          society_id: string | null
          sort_order: number
          title: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          doc_kind?: string
          file_name?: string | null
          file_url: string
          id?: string
          mime_type?: string | null
          poll_id: string
          society_id?: string | null
          sort_order?: number
          title: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          doc_kind?: string
          file_name?: string | null
          file_url?: string
          id?: string
          mime_type?: string | null
          poll_id?: string
          society_id?: string | null
          sort_order?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "poll_documents_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_documents_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      poll_election_ballots: {
        Row: {
          ballot_method: string | null
          choices: Json
          created_at: string
          flat_id: string | null
          flat_number: string | null
          id: string
          is_proxy_vote: boolean
          poll_id: string
          proxy_id: string | null
          rankings: Json
          submitted_at: string
          voter_id: string
          voter_phone: string | null
        }
        Insert: {
          ballot_method?: string | null
          choices?: Json
          created_at?: string
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          is_proxy_vote?: boolean
          poll_id: string
          proxy_id?: string | null
          rankings?: Json
          submitted_at?: string
          voter_id: string
          voter_phone?: string | null
        }
        Update: {
          ballot_method?: string | null
          choices?: Json
          created_at?: string
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          is_proxy_vote?: boolean
          poll_id?: string
          proxy_id?: string | null
          rankings?: Json
          submitted_at?: string
          voter_id?: string
          voter_phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "poll_election_ballots_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_election_ballots_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_election_ballots_proxy_id_fkey"
            columns: ["proxy_id"]
            isOneToOne: false
            referencedRelation: "election_proxies"
            referencedColumns: ["id"]
          },
        ]
      }
      poll_options: {
        Row: {
          created_at: string
          election_post: string | null
          flat_id: string | null
          flat_number: string | null
          id: string
          member_id: string | null
          nominated_by: string | null
          nomination_statement: string | null
          option_text: string
          poll_id: string | null
          votes_count: number
        }
        Insert: {
          created_at?: string
          election_post?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          member_id?: string | null
          nominated_by?: string | null
          nomination_statement?: string | null
          option_text: string
          poll_id?: string | null
          votes_count?: number
        }
        Update: {
          created_at?: string
          election_post?: string | null
          flat_id?: string | null
          flat_number?: string | null
          id?: string
          member_id?: string | null
          nominated_by?: string | null
          nomination_statement?: string | null
          option_text?: string
          poll_id?: string | null
          votes_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "poll_options_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_options_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_options_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
        ]
      }
      poll_votes: {
        Row: {
          created_at: string
          flat_number: string | null
          id: string
          option_id: string | null
          poll_id: string | null
          voter_id: string
          voter_type: string
        }
        Insert: {
          created_at?: string
          flat_number?: string | null
          id?: string
          option_id?: string | null
          poll_id?: string | null
          voter_id: string
          voter_type?: string
        }
        Update: {
          created_at?: string
          flat_number?: string | null
          id?: string
          option_id?: string | null
          poll_id?: string | null
          voter_id?: string
          voter_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "poll_votes_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "poll_options"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_votes_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
        ]
      }
      polls: {
        Row: {
          allow_multiple: boolean
          bye_law_mode: boolean
          created_at: string
          created_by: string | null
          description: string | null
          election_applied_at: string | null
          election_committee_seats: number
          election_phase: string
          election_quorum_required: number | null
          election_results: Json | null
          election_term_from: string | null
          election_term_to: string | null
          end_date: string | null
          first_mc_meeting_deadline: string | null
          id: string
          is_active: boolean
          member_count_at_election: number | null
          nomination_ends_at: string | null
          nomination_starts_at: string | null
          open_posts: Json
          poll_kind: string
          question: string
          separate_office_votes: boolean
          society_id: string | null
          target_committee_size: number
          voting_ends_at: string | null
          voting_method: string | null
          voting_method_recorded_at: string | null
          voting_method_recorded_by: string | null
          voting_starts_at: string | null
          winning_votes: Json
        }
        Insert: {
          allow_multiple?: boolean
          bye_law_mode?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          election_applied_at?: string | null
          election_committee_seats?: number
          election_phase?: string
          election_quorum_required?: number | null
          election_results?: Json | null
          election_term_from?: string | null
          election_term_to?: string | null
          end_date?: string | null
          first_mc_meeting_deadline?: string | null
          id?: string
          is_active?: boolean
          member_count_at_election?: number | null
          nomination_ends_at?: string | null
          nomination_starts_at?: string | null
          open_posts?: Json
          poll_kind?: string
          question: string
          separate_office_votes?: boolean
          society_id?: string | null
          target_committee_size?: number
          voting_ends_at?: string | null
          voting_method?: string | null
          voting_method_recorded_at?: string | null
          voting_method_recorded_by?: string | null
          voting_starts_at?: string | null
          winning_votes?: Json
        }
        Update: {
          allow_multiple?: boolean
          bye_law_mode?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          election_applied_at?: string | null
          election_committee_seats?: number
          election_phase?: string
          election_quorum_required?: number | null
          election_results?: Json | null
          election_term_from?: string | null
          election_term_to?: string | null
          end_date?: string | null
          first_mc_meeting_deadline?: string | null
          id?: string
          is_active?: boolean
          member_count_at_election?: number | null
          nomination_ends_at?: string | null
          nomination_starts_at?: string | null
          open_posts?: Json
          poll_kind?: string
          question?: string
          separate_office_votes?: boolean
          society_id?: string | null
          target_committee_size?: number
          voting_ends_at?: string | null
          voting_method?: string | null
          voting_method_recorded_at?: string | null
          voting_method_recorded_by?: string | null
          voting_starts_at?: string | null
          winning_votes?: Json
        }
        Relationships: [
          {
            foreignKeyName: "polls_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      reserve_fund_transfers: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          direction: string
          entry_month: string
          id: string
          notes: string | null
          payment_method: string
          society_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          direction: string
          entry_month: string
          id?: string
          notes?: string | null
          payment_method?: string
          society_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          direction?: string
          entry_month?: string
          id?: string
          notes?: string | null
          payment_method?: string
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reserve_fund_transfers_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      resident_users: {
        Row: {
          created_at: string
          email: string | null
          flat_id: string
          flat_number: string
          id: string
          must_change_password: boolean
          name: string
          password: string
          phone: string
          whatsapp_phone: string | null
        }
        Insert: {
          created_at?: string
          email?: string | null
          flat_id: string
          flat_number: string
          id?: string
          must_change_password?: boolean
          name: string
          password: string
          phone: string
          whatsapp_phone?: string | null
        }
        Update: {
          created_at?: string
          email?: string | null
          flat_id?: string
          flat_number?: string
          id?: string
          must_change_password?: boolean
          name?: string
          password?: string
          phone?: string
          whatsapp_phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "resident_users_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      resident_vehicles: {
        Row: {
          created_at: string
          flat_id: string | null
          flat_number: string
          id: string
          member_id: string | null
          resident_name: string
          society_id: string | null
          vehicle_color: string | null
          vehicle_display_name: string | null
          vehicle_number: string
          vehicle_photo: string | null
          vehicle_type: string
        }
        Insert: {
          created_at?: string
          flat_id?: string | null
          flat_number: string
          id?: string
          member_id?: string | null
          resident_name: string
          society_id?: string | null
          vehicle_color?: string | null
          vehicle_display_name?: string | null
          vehicle_number: string
          vehicle_photo?: string | null
          vehicle_type?: string
        }
        Update: {
          created_at?: string
          flat_id?: string | null
          flat_number?: string
          id?: string
          member_id?: string | null
          resident_name?: string
          society_id?: string | null
          vehicle_color?: string | null
          vehicle_display_name?: string | null
          vehicle_number?: string
          vehicle_photo?: string | null
          vehicle_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "resident_vehicles_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resident_vehicles_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resident_vehicles_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_report_definitions: {
        Row: {
          columns: Json | null
          created_at: string
          created_by: string | null
          description: string | null
          filters: Json
          group_by: Json | null
          id: string
          name: string
          report_id: string
          society_id: string
          sort: Json | null
          updated_at: string
        }
        Insert: {
          columns?: Json | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          filters?: Json
          group_by?: Json | null
          id?: string
          name: string
          report_id: string
          society_id: string
          sort?: Json | null
          updated_at?: string
        }
        Update: {
          columns?: Json | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          filters?: Json
          group_by?: Json | null
          id?: string
          name?: string
          report_id?: string
          society_id?: string
          sort?: Json | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_report_definitions_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      societies: {
        Row: {
          address: string | null
          admin_push_sound_url: string | null
          basement_usable_for_residents: boolean | null
          block_names: string[] | null
          city: string | null
          contact_email: string | null
          contact_person: string | null
          contact_phone: string | null
          created_at: string
          flat_series_end: string | null
          flat_series_start: string | null
          flats_per_floor: number | null
          has_basement: boolean | null
          id: string
          is_active: boolean
          logo_url: string | null
          name: string
          photo_urls: string[]
          pincode: string | null
          referral_code: string | null
          resident_self_id_upload_enabled: boolean
          state: string | null
          terrace_accessible: boolean | null
          total_flats: number | null
          total_floors: number | null
        }
        Insert: {
          address?: string | null
          admin_push_sound_url?: string | null
          basement_usable_for_residents?: boolean | null
          block_names?: string[] | null
          city?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          flat_series_end?: string | null
          flat_series_start?: string | null
          flats_per_floor?: number | null
          has_basement?: boolean | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name: string
          photo_urls?: string[]
          pincode?: string | null
          referral_code?: string | null
          resident_self_id_upload_enabled?: boolean
          state?: string | null
          terrace_accessible?: boolean | null
          total_flats?: number | null
          total_floors?: number | null
        }
        Update: {
          address?: string | null
          admin_push_sound_url?: string | null
          basement_usable_for_residents?: boolean | null
          block_names?: string[] | null
          city?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          flat_series_end?: string | null
          flat_series_start?: string | null
          flats_per_floor?: number | null
          has_basement?: boolean | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name?: string
          photo_urls?: string[]
          pincode?: string | null
          referral_code?: string | null
          resident_self_id_upload_enabled?: boolean
          state?: string | null
          terrace_accessible?: boolean | null
          total_flats?: number | null
          total_floors?: number | null
        }
        Relationships: []
      }
      society_content_translations: {
        Row: {
          content_key: string
          created_at: string
          id: string
          society_id: string
          text_en: string
          text_hi: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          content_key: string
          created_at?: string
          id?: string
          society_id: string
          text_en?: string
          text_hi?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          content_key?: string
          created_at?: string
          id?: string
          society_id?: string
          text_en?: string
          text_hi?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "society_content_translations_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      society_dashboard_banners: {
        Row: {
          created_at: string
          id: string
          image_url: string
          is_active: boolean
          society_id: string
          sort_order: number
          title: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          image_url: string
          is_active?: boolean
          society_id: string
          sort_order?: number
          title?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string
          is_active?: boolean
          society_id?: string
          sort_order?: number
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "society_dashboard_banners_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      society_documents: {
        Row: {
          category: string
          created_at: string
          description: string | null
          file_name: string
          id: string
          member_reveal_until: string | null
          mime_type: string | null
          published: boolean
          society_id: string
          sort_order: number
          storage_path: string
          title: string
          updated_at: string
          uploaded_by: string | null
        }
        Insert: {
          category?: string
          created_at?: string
          description?: string | null
          file_name: string
          id?: string
          member_reveal_until?: string | null
          mime_type?: string | null
          published?: boolean
          society_id: string
          sort_order?: number
          storage_path: string
          title: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Update: {
          category?: string
          created_at?: string
          description?: string | null
          file_name?: string
          id?: string
          member_reveal_until?: string | null
          mime_type?: string | null
          published?: boolean
          society_id?: string
          sort_order?: number
          storage_path?: string
          title?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "society_documents_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      society_orders: {
        Row: {
          amount_inr: number
          callback_payload: Json
          callback_verified: boolean
          created_at: string
          currency: string
          id: string
          merchant_transaction_id: string
          phonepe_transaction_id: string | null
          provider: string
          redirect_url: string | null
          signup_id: string
          status: string
        }
        Insert: {
          amount_inr: number
          callback_payload?: Json
          callback_verified?: boolean
          created_at?: string
          currency?: string
          id?: string
          merchant_transaction_id: string
          phonepe_transaction_id?: string | null
          provider?: string
          redirect_url?: string | null
          signup_id: string
          status?: string
        }
        Update: {
          amount_inr?: number
          callback_payload?: Json
          callback_verified?: boolean
          created_at?: string
          currency?: string
          id?: string
          merchant_transaction_id?: string
          phonepe_transaction_id?: string | null
          provider?: string
          redirect_url?: string | null
          signup_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "society_orders_signup_id_fkey"
            columns: ["signup_id"]
            isOneToOne: false
            referencedRelation: "society_signups"
            referencedColumns: ["id"]
          },
        ]
      }
      society_referrals: {
        Row: {
          created_at: string
          id: string
          order_id: string
          referral_code_used: string
          referred_reward_inr: number
          referred_society_id: string | null
          referrer_reward_inr: number
          referrer_society_id: string
          reward_percent: number
        }
        Insert: {
          created_at?: string
          id?: string
          order_id: string
          referral_code_used: string
          referred_reward_inr?: number
          referred_society_id?: string | null
          referrer_reward_inr?: number
          referrer_society_id: string
          reward_percent?: number
        }
        Update: {
          created_at?: string
          id?: string
          order_id?: string
          referral_code_used?: string
          referred_reward_inr?: number
          referred_society_id?: string | null
          referrer_reward_inr?: number
          referrer_society_id?: string
          reward_percent?: number
        }
        Relationships: [
          {
            foreignKeyName: "society_referrals_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: true
            referencedRelation: "society_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "society_referrals_referred_society_id_fkey"
            columns: ["referred_society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "society_referrals_referrer_society_id_fkey"
            columns: ["referrer_society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      society_roles: {
        Row: {
          created_at: string
          id: string
          permissions: Json
          role_name: string
          slug: string | null
          society_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          permissions?: Json
          role_name: string
          slug?: string | null
          society_id: string
        }
        Update: {
          created_at?: string
          id?: string
          permissions?: Json
          role_name?: string
          slug?: string | null
          society_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "society_roles_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      society_signups: {
        Row: {
          address: string | null
          admin_id: string | null
          admin_password: string | null
          base_price_inr: number
          block_names: string[] | null
          city: string | null
          client_token: string | null
          contact_email: string | null
          contact_person: string | null
          contact_phone: string | null
          created_at: string
          discount_percent: number
          final_price_inr: number
          flat_series_end: string | null
          flat_series_start: string | null
          flats_per_floor: number | null
          id: string
          notes: string | null
          pincode: string | null
          referral_code_used: string | null
          society_name: string
          state: string | null
          status: string
          total_floors: number | null
        }
        Insert: {
          address?: string | null
          admin_id?: string | null
          admin_password?: string | null
          base_price_inr?: number
          block_names?: string[] | null
          city?: string | null
          client_token?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          discount_percent?: number
          final_price_inr?: number
          flat_series_end?: string | null
          flat_series_start?: string | null
          flats_per_floor?: number | null
          id?: string
          notes?: string | null
          pincode?: string | null
          referral_code_used?: string | null
          society_name: string
          state?: string | null
          status?: string
          total_floors?: number | null
        }
        Update: {
          address?: string | null
          admin_id?: string | null
          admin_password?: string | null
          base_price_inr?: number
          block_names?: string[] | null
          city?: string | null
          client_token?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          discount_percent?: number
          final_price_inr?: number
          flat_series_end?: string | null
          flat_series_start?: string | null
          flats_per_floor?: number | null
          id?: string
          notes?: string | null
          pincode?: string | null
          referral_code_used?: string | null
          society_name?: string
          state?: string | null
          status?: string
          total_floors?: number | null
        }
        Relationships: []
      }
      society_wallet_ledger: {
        Row: {
          amount_inr: number
          created_at: string
          entry_type: string
          id: string
          notes: string | null
          society_id: string
          source_order_id: string | null
        }
        Insert: {
          amount_inr: number
          created_at?: string
          entry_type: string
          id?: string
          notes?: string | null
          society_id: string
          source_order_id?: string | null
        }
        Update: {
          amount_inr?: number
          created_at?: string
          entry_type?: string
          id?: string
          notes?: string | null
          society_id?: string
          source_order_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "society_wallet_ledger_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "society_wallet_ledger_source_order_id_fkey"
            columns: ["source_order_id"]
            isOneToOne: false
            referencedRelation: "society_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      super_admins: {
        Row: {
          created_at: string
          id: string
          name: string
          password: string
          recovery_email: string | null
          totp_enabled: boolean
          totp_secret: string | null
          username: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          password: string
          recovery_email?: string | null
          totp_enabled?: boolean
          totp_secret?: string | null
          username: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          password?: string
          recovery_email?: string | null
          totp_enabled?: boolean
          totp_secret?: string | null
          username?: string
        }
        Relationships: []
      }
      superadmin_recovery_challenges: {
        Row: {
          code: string
          created_at: string
          expires_at: string
          id: string
          super_admin_id: string
        }
        Insert: {
          code: string
          created_at?: string
          expires_at: string
          id?: string
          super_admin_id: string
        }
        Update: {
          code?: string
          created_at?: string
          expires_at?: string
          id?: string
          super_admin_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "superadmin_recovery_challenges_super_admin_id_fkey"
            columns: ["super_admin_id"]
            isOneToOne: false
            referencedRelation: "super_admins"
            referencedColumns: ["id"]
          },
        ]
      }
      support_tickets: {
        Row: {
          audio_url: string | null
          created_at: string
          flat_number: string
          id: string
          media_items: Json
          message: string
          replied_at: string | null
          replied_by_superadmin_id: string | null
          society_id: string | null
          society_name: string | null
          status: string
          submitter_kind: string
          submitter_name: string
          submitter_resident_id: string
          superadmin_reply: string | null
          ticket_number: number
        }
        Insert: {
          audio_url?: string | null
          created_at?: string
          flat_number: string
          id?: string
          media_items?: Json
          message?: string
          replied_at?: string | null
          replied_by_superadmin_id?: string | null
          society_id?: string | null
          society_name?: string | null
          status?: string
          submitter_kind?: string
          submitter_name: string
          submitter_resident_id: string
          superadmin_reply?: string | null
          ticket_number?: never
        }
        Update: {
          audio_url?: string | null
          created_at?: string
          flat_number?: string
          id?: string
          media_items?: Json
          message?: string
          replied_at?: string | null
          replied_by_superadmin_id?: string | null
          society_id?: string | null
          society_name?: string | null
          status?: string
          submitter_kind?: string
          submitter_name?: string
          submitter_resident_id?: string
          superadmin_reply?: string | null
          ticket_number?: never
        }
        Relationships: [
          {
            foreignKeyName: "support_tickets_replied_by_superadmin_id_fkey"
            columns: ["replied_by_superadmin_id"]
            isOneToOne: false
            referencedRelation: "super_admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
      visitor_passes: {
        Row: {
          created_at: string
          created_by_id: string
          created_by_name: string
          created_by_type: string
          flat_id: string
          flat_number: string
          guest_name: string | null
          guest_phone: string | null
          id: string
          otp_code: string
          status: string
          time_slot_end: string | null
          time_slot_start: string | null
          used_at: string | null
          valid_date: string
        }
        Insert: {
          created_at?: string
          created_by_id: string
          created_by_name: string
          created_by_type: string
          flat_id: string
          flat_number: string
          guest_name?: string | null
          guest_phone?: string | null
          id?: string
          otp_code: string
          status?: string
          time_slot_end?: string | null
          time_slot_start?: string | null
          used_at?: string | null
          valid_date: string
        }
        Update: {
          created_at?: string
          created_by_id?: string
          created_by_name?: string
          created_by_type?: string
          flat_id?: string
          flat_number?: string
          guest_name?: string | null
          guest_phone?: string | null
          id?: string
          otp_code?: string
          status?: string
          time_slot_end?: string | null
          time_slot_start?: string | null
          used_at?: string | null
          valid_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "visitor_passes_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      visitors: {
        Row: {
          category: string
          company: string | null
          created_at: string
          document_number: string | null
          document_photo: string | null
          document_type: string
          entry_time: string
          exit_time: string | null
          flat_number: string
          guard_id: string
          guard_name: string
          id: string
          is_blacklisted: boolean | null
          name: string
          phone: string
          purpose: string
          society_id: string | null
          updated_at: string
          vehicle_entry_time: string | null
          vehicle_exit_time: string | null
          vehicle_number: string | null
          vehicle_photo: string | null
          visitor_photos: string[] | null
        }
        Insert: {
          category?: string
          company?: string | null
          created_at?: string
          document_number?: string | null
          document_photo?: string | null
          document_type?: string
          entry_time?: string
          exit_time?: string | null
          flat_number: string
          guard_id: string
          guard_name: string
          id?: string
          is_blacklisted?: boolean | null
          name: string
          phone: string
          purpose?: string
          society_id?: string | null
          updated_at?: string
          vehicle_entry_time?: string | null
          vehicle_exit_time?: string | null
          vehicle_number?: string | null
          vehicle_photo?: string | null
          visitor_photos?: string[] | null
        }
        Update: {
          category?: string
          company?: string | null
          created_at?: string
          document_number?: string | null
          document_photo?: string | null
          document_type?: string
          entry_time?: string
          exit_time?: string | null
          flat_number?: string
          guard_id?: string
          guard_name?: string
          id?: string
          is_blacklisted?: boolean | null
          name?: string
          phone?: string
          purpose?: string
          society_id?: string | null
          updated_at?: string
          vehicle_entry_time?: string | null
          vehicle_exit_time?: string | null
          vehicle_number?: string | null
          vehicle_photo?: string | null
          visitor_photos?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "visitors_society_id_fkey"
            columns: ["society_id"]
            isOneToOne: false
            referencedRelation: "societies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      election_quorum_required: {
        Args: { p_member_count: number }
        Returns: number
      }
      flat_has_maintenance_arrears_over_days: {
        Args: { p_as_of?: string; p_days?: number; p_flat_id: string }
        Returns: boolean
      }
      is_fixed_asset_expense_group: {
        Args: { p_group_id: string }
        Returns: boolean
      }
      log_election_audit_event: {
        Args: {
          p_actor_id?: string
          p_actor_name?: string
          p_actor_type?: string
          p_event_type: string
          p_payload?: Json
          p_poll_id: string
          p_society_id: string
        }
        Returns: string
      }
      member_election_eligibility: {
        Args: {
          p_arrears_days?: number
          p_as_of?: string
          p_member_id: string
          p_society_id: string
        }
        Returns: Json
      }
      record_election_voting_method: {
        Args: {
          p_method: string
          p_poll_id: string
          p_recorded_by?: string
          p_separate_office_votes?: boolean
        }
        Returns: {
          allow_multiple: boolean
          bye_law_mode: boolean
          created_at: string
          created_by: string | null
          description: string | null
          election_applied_at: string | null
          election_committee_seats: number
          election_phase: string
          election_quorum_required: number | null
          election_results: Json | null
          election_term_from: string | null
          election_term_to: string | null
          end_date: string | null
          first_mc_meeting_deadline: string | null
          id: string
          is_active: boolean
          member_count_at_election: number | null
          nomination_ends_at: string | null
          nomination_starts_at: string | null
          open_posts: Json
          poll_kind: string
          question: string
          separate_office_votes: boolean
          society_id: string | null
          target_committee_size: number
          voting_ends_at: string | null
          voting_method: string | null
          voting_method_recorded_at: string | null
          voting_method_recorded_by: string | null
          voting_starts_at: string | null
          winning_votes: Json
        }
        SetofOptions: {
          from: "*"
          to: "polls"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_fixed_asset_from_finance_entry: {
        Args: { p_finance_entry_id: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
