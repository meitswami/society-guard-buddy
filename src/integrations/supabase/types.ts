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
    PostgrestVersion: "14.4"
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
          user_agent?: string | null
          user_id?: string | null
          user_name?: string | null
          user_type?: string
        }
        Relationships: []
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
          type?: string
          vehicle_number?: string | null
        }
        Relationships: []
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
      event_contributions: {
        Row: {
          amount: number
          created_at: string
          event_id: string | null
          flat_id: string | null
          flat_number: string
          id: string
          payment_method: string
          resident_name: string | null
          screenshot_url: string | null
          transaction_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number: string
          id?: string
          payment_method?: string
          resident_name?: string | null
          screenshot_url?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          event_id?: string | null
          flat_id?: string | null
          flat_number?: string
          id?: string
          payment_method?: string
          resident_name?: string | null
          screenshot_url?: string | null
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
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          name: string
          society_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name: string
          society_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name?: string
          society_id?: string | null
        }
        Relationships: [
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
          created_at: string
          group_id: string | null
          id: string
          paid_by_flat: string
          paid_by_name: string | null
          split_type: string
          title: string
          total_amount: number
        }
        Insert: {
          created_at?: string
          group_id?: string | null
          id?: string
          paid_by_flat: string
          paid_by_name?: string | null
          split_type?: string
          title: string
          total_amount: number
        }
        Update: {
          created_at?: string
          group_id?: string | null
          id?: string
          paid_by_flat?: string
          paid_by_name?: string | null
          split_type?: string
          title?: string
          total_amount?: number
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
      flats: {
        Row: {
          created_at: string
          flat_number: string
          flat_type: string | null
          floor: string | null
          id: string
          intercom: string | null
          is_occupied: boolean | null
          owner_name: string | null
          owner_phone: string | null
          society_id: string | null
          wing: string | null
        }
        Insert: {
          created_at?: string
          flat_number: string
          flat_type?: string | null
          floor?: string | null
          id?: string
          intercom?: string | null
          is_occupied?: boolean | null
          owner_name?: string | null
          owner_phone?: string | null
          society_id?: string | null
          wing?: string | null
        }
        Update: {
          created_at?: string
          flat_number?: string
          flat_type?: string | null
          floor?: string | null
          id?: string
          intercom?: string | null
          is_occupied?: boolean | null
          owner_name?: string | null
          owner_phone?: string | null
          society_id?: string | null
          wing?: string | null
        }
        Relationships: [
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
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          latitude: number
          longitude: number
          radius_meters?: number
          set_by: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          latitude?: number
          longitude?: number
          radius_meters?: number
          set_by?: string
          updated_at?: string
        }
        Relationships: []
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
      guard_shifts: {
        Row: {
          created_at: string
          guard_id: string
          guard_name: string
          id: string
          login_time: string
          logout_time: string | null
        }
        Insert: {
          created_at?: string
          guard_id: string
          guard_name: string
          id?: string
          login_time?: string
          logout_time?: string | null
        }
        Update: {
          created_at?: string
          guard_id?: string
          guard_name?: string
          id?: string
          login_time?: string
          logout_time?: string | null
        }
        Relationships: []
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
      maintenance_charges: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          due_day: number
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
          frequency?: string
          id?: string
          is_active?: boolean
          society_id?: string | null
          title?: string
        }
        Relationships: [
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
          flat_id: string | null
          flat_number: string
          id: string
          notes: string | null
          payment_date: string | null
          payment_method: string
          payment_status: string
          resident_name: string | null
          screenshot_url: string | null
          transaction_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          charge_id?: string | null
          created_at?: string
          due_date: string
          flat_id?: string | null
          flat_number: string
          id?: string
          notes?: string | null
          payment_date?: string | null
          payment_method?: string
          payment_status?: string
          resident_name?: string | null
          screenshot_url?: string | null
          transaction_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          charge_id?: string | null
          created_at?: string
          due_date?: string
          flat_id?: string | null
          flat_number?: string
          id?: string
          notes?: string | null
          payment_date?: string | null
          payment_method?: string
          payment_status?: string
          resident_name?: string | null
          screenshot_url?: string | null
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
            foreignKeyName: "maintenance_payments_flat_id_fkey"
            columns: ["flat_id"]
            isOneToOne: false
            referencedRelation: "flats"
            referencedColumns: ["id"]
          },
        ]
      }
      members: {
        Row: {
          age: number | null
          created_at: string
          flat_id: string
          gender: string | null
          id: string
          is_primary: boolean | null
          name: string
          phone: string | null
          photo: string | null
          relation: string | null
        }
        Insert: {
          age?: number | null
          created_at?: string
          flat_id: string
          gender?: string | null
          id?: string
          is_primary?: boolean | null
          name: string
          phone?: string | null
          photo?: string | null
          relation?: string | null
        }
        Update: {
          age?: number | null
          created_at?: string
          flat_id?: string
          gender?: string | null
          id?: string
          is_primary?: boolean | null
          name?: string
          phone?: string | null
          photo?: string | null
          relation?: string | null
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
      notifications: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_read: boolean
          message: string
          society_id: string | null
          target_id: string | null
          target_type: string
          title: string
          type: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_read?: boolean
          message: string
          society_id?: string | null
          target_id?: string | null
          target_type?: string
          title: string
          type?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_read?: boolean
          message?: string
          society_id?: string | null
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
      poll_options: {
        Row: {
          created_at: string
          id: string
          option_text: string
          poll_id: string | null
          votes_count: number
        }
        Insert: {
          created_at?: string
          id?: string
          option_text: string
          poll_id?: string | null
          votes_count?: number
        }
        Update: {
          created_at?: string
          id?: string
          option_text?: string
          poll_id?: string | null
          votes_count?: number
        }
        Relationships: [
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
          created_at: string
          created_by: string | null
          description: string | null
          end_date: string | null
          id: string
          is_active: boolean
          question: string
          society_id: string | null
        }
        Insert: {
          allow_multiple?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_active?: boolean
          question: string
          society_id?: string | null
        }
        Update: {
          allow_multiple?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_active?: boolean
          question?: string
          society_id?: string | null
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
      resident_users: {
        Row: {
          created_at: string
          email: string | null
          flat_id: string
          flat_number: string
          id: string
          name: string
          password: string
          phone: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          flat_id: string
          flat_number: string
          id?: string
          name: string
          password: string
          phone: string
        }
        Update: {
          created_at?: string
          email?: string | null
          flat_id?: string
          flat_number?: string
          id?: string
          name?: string
          password?: string
          phone?: string
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
          resident_name: string
          vehicle_number: string
          vehicle_photo: string | null
          vehicle_type: string
        }
        Insert: {
          created_at?: string
          flat_id?: string | null
          flat_number: string
          id?: string
          resident_name: string
          vehicle_number: string
          vehicle_photo?: string | null
          vehicle_type?: string
        }
        Update: {
          created_at?: string
          flat_id?: string | null
          flat_number?: string
          id?: string
          resident_name?: string
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
        ]
      }
      societies: {
        Row: {
          address: string | null
          city: string | null
          contact_email: string | null
          contact_person: string | null
          contact_phone: string | null
          created_at: string
          id: string
          is_active: boolean
          logo_url: string | null
          name: string
          pincode: string | null
          state: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name: string
          pincode?: string | null
          state?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          contact_email?: string | null
          contact_person?: string | null
          contact_phone?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name?: string
          pincode?: string | null
          state?: string | null
        }
        Relationships: []
      }
      society_roles: {
        Row: {
          created_at: string
          id: string
          role_name: string
          society_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role_name: string
          society_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role_name?: string
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
      super_admins: {
        Row: {
          created_at: string
          id: string
          name: string
          password: string
          username: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          password: string
          username: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          password?: string
          username?: string
        }
        Relationships: []
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
          updated_at?: string
          vehicle_entry_time?: string | null
          vehicle_exit_time?: string | null
          vehicle_number?: string | null
          vehicle_photo?: string | null
          visitor_photos?: string[] | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
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
