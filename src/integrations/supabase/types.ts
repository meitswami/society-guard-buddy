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
          created_at: string
          guard_id: string
          id: string
          name: string
          password: string
          society_id: string | null
        }
        Insert: {
          created_at?: string
          guard_id: string
          id?: string
          name: string
          password: string
          society_id?: string | null
        }
        Update: {
          created_at?: string
          guard_id?: string
          id?: string
          name?: string
          password?: string
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
