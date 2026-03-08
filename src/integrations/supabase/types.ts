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
        }
        Insert: {
          created_at?: string
          guard_id: string
          id?: string
          name: string
          password: string
        }
        Update: {
          created_at?: string
          guard_id?: string
          id?: string
          name?: string
          password?: string
        }
        Relationships: []
      }
      resident_vehicles: {
        Row: {
          created_at: string
          flat_number: string
          id: string
          resident_name: string
          vehicle_number: string
          vehicle_photo: string | null
          vehicle_type: string
        }
        Insert: {
          created_at?: string
          flat_number: string
          id?: string
          resident_name: string
          vehicle_number: string
          vehicle_photo?: string | null
          vehicle_type?: string
        }
        Update: {
          created_at?: string
          flat_number?: string
          id?: string
          resident_name?: string
          vehicle_number?: string
          vehicle_photo?: string | null
          vehicle_type?: string
        }
        Relationships: []
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
