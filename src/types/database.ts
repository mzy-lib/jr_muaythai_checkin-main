export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          operationName?: string
          query?: string
          variables?: Json
          extensions?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      members: {
        Row: {
          id: string;
          name: string;
          email: string | null;
          phone: string | null;
          created_at: string | null;
          updated_at: string | null;
          last_check_in_date: string | null;
          extra_check_ins: number;
          is_new_member: boolean;
        };
        Insert: {
          id?: string;
          name: string;
          email?: string | null;
          phone?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
          last_check_in_date?: string | null;
          extra_check_ins?: number;
          is_new_member?: boolean;
        };
        Update: {
          id?: string;
          name?: string;
          email?: string | null;
          phone?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
          last_check_in_date?: string | null;
          extra_check_ins?: number;
          is_new_member?: boolean;
        };
        Relationships: [];
      };
      membership_cards: {
        Row: {
          id: string;
          member_id: string;
          card_type: string;
          card_category: string | null;
          card_subtype: string;
          trainer_type: string | null;
          remaining_group_sessions: number | null;
          remaining_private_sessions: number | null;
          remaining_kids_sessions: number | null;
          valid_until: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          member_id: string;
          card_type: string;
          card_category?: string | null;
          card_subtype: string;
          trainer_type?: string | null;
          remaining_group_sessions?: number | null;
          remaining_private_sessions?: number | null;
          remaining_kids_sessions?: number | null;
          valid_until?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          member_id?: string;
          card_type?: string;
          card_category?: string | null;
          card_subtype?: string;
          trainer_type?: string | null;
          remaining_group_sessions?: number | null;
          remaining_private_sessions?: number | null;
          remaining_kids_sessions?: number | null;
          valid_until?: string | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "membership_cards_member_id_fkey";
            columns: ["member_id"];
            isOneToOne: false;
            referencedRelation: "members";
            referencedColumns: ["id"];
          }
        ];
      };
      check_ins: {
        Row: {
          id: string;
          member_id: string;
          card_id: string | null;
          trainer_id: string | null;
          class_type: ClassType;
          check_in_time: string;
          check_in_date: string;
          is_extra: boolean;
          is_private: boolean;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          member_id: string;
          card_id?: string | null;
          trainer_id?: string | null;
          class_type: ClassType;
          check_in_time?: string;
          check_in_date: string;
          is_extra?: boolean;
          is_private?: boolean;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          member_id?: string;
          card_id?: string | null;
          trainer_id?: string | null;
          class_type?: ClassType;
          check_in_time?: string;
          check_in_date?: string;
          is_extra?: boolean;
          is_private?: boolean;
          created_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "check_ins_member_id_fkey";
            columns: ["member_id"];
            isOneToOne: false;
            referencedRelation: "members";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "check_ins_card_id_fkey";
            columns: ["card_id"];
            isOneToOne: false;
            referencedRelation: "membership_cards";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "check_ins_trainer_id_fkey";
            columns: ["trainer_id"];
            isOneToOne: false;
            referencedRelation: "trainers";
            referencedColumns: ["id"];
          }
        ];
      };
      trainers: {
        Row: {
          id: string;
          name: string;
          type: TrainerType;
          notes: string | null;
          created_at: string | null;
          updated_at: string | null;
        };
        Insert: {
          id?: string;
          name: string;
          type: TrainerType;
          notes?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Update: {
          id?: string;
          name?: string;
          type?: TrainerType;
          notes?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Relationships: [];
      };
      class_schedule: {
        Row: {
          id: string;
          class_type: ClassType;
          day_of_week: number;
          start_time: string;
          end_time: string;
          created_at: string | null;
          updated_at: string | null;
        };
        Insert: {
          id?: string;
          class_type: ClassType;
          day_of_week: number;
          start_time: string;
          end_time: string;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Update: {
          id?: string;
          class_type?: ClassType;
          day_of_week?: number;
          start_time?: string;
          end_time?: string;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Relationships: [];
      };
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      create_new_member: {
        Args: {
          p_name: string;
          p_email: string;
          p_class_type: ClassType;
        };
        Returns: Json;
      };
      find_member_for_checkin: {
        Args: {
          p_name: string;
          p_email?: string;
        };
        Returns: {
          member_id: string;
          is_new: boolean;
          needs_email: boolean;
        }[];
      };
      search_members: {
        Args: {
          search_query: string;
        };
        Returns: Member[];
      };
      validate_member_name: {
        Args: {
          p_name: string;
          p_email?: string;
        };
        Returns: boolean;
      };
    }
    Enums: {
      class_type: "morning" | "evening";
      membership_type:
        | "single_class" 
        | "two_classes" 
        | "ten_classes" 
        | "single_monthly" 
        | "double_monthly"
        | "kids_ten_classes";
      
      ClassType: "morning" | "evening" | "private" | "kids group";
        CardType: "class" | "private" | "kids_group" | "团课" | "私教课" | "儿童团课" | "all_cards";
      CardCategory: "group" | "private";
      CardSubtype: 
        | "single_class" 
        | "two_classes" 
        | "ten_classes" 
        | "single_monthly" 
        | "double_monthly" 
        | "single_private" 
        | "ten_private";
      TrainerType: "jr" | "senior";
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type PublicSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  PublicTableNameOrOptions extends
    | keyof (PublicSchema["Tables"] & PublicSchema["Views"])
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
      Database[PublicTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : PublicTableNameOrOptions extends keyof (PublicSchema["Tables"] &
        PublicSchema["Views"])
    ? (PublicSchema["Tables"] &
        PublicSchema["Views"])[PublicTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  PublicEnumNameOrOptions extends
    | keyof PublicSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends PublicEnumNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = PublicEnumNameOrOptions extends { schema: keyof Database }
  ? Database[PublicEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : PublicEnumNameOrOptions extends keyof PublicSchema["Enums"]
    ? PublicSchema["Enums"][PublicEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof PublicSchema["CompositeTypes"]
    | { schema: keyof Database },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
  ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof PublicSchema["CompositeTypes"]
    ? PublicSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export interface NewMemberFormData {
    name: string;
    email: string;
    classType: Database['public']['Enums']['class_type'];
    timeSlot: string;
    trainerId?: string;
    is1v2?: boolean;
}

export interface DatabaseError {
    message: string;
    code?: string;
    details?: string;
    hint?: string;
}

export interface MemberSearchResult {
    member_id: string | null;
    is_new: boolean;
    needs_email: boolean;
}

export interface RegisterResult {
    success: boolean;
    message: string;
}

export type Member = Database['public']['Tables']['members']['Row'];
export type MembershipType = Database['public']['Enums']['membership_type'];

export interface MembershipCard {
  id: string;
  member_id: string;
  card_type: string | null;
  card_category: string | null;
  card_subtype: string | null;
  trainer_type: string | null;
  valid_until: string | null;
  remaining_group_sessions: number | null;
  remaining_private_sessions: number | null;
  remaining_kids_sessions: number | null;
  created_at: string;
  updated_at: string | null;
}

export type CheckIn = Database['public']['Tables']['check_ins']['Row'];
export type Trainer = Database['public']['Tables']['trainers']['Row'];
export type ClassSchedule = Database['public']['Tables']['class_schedule']['Row'];

export type ClassType = Database['public']['Enums']['ClassType'];
export type CardType = Database['public']['Enums']['CardType'];
export type CardCategory = Database['public']['Enums']['CardCategory'];
export type CardSubtype = Database['public']['Enums']['CardSubtype'];
export type TrainerType = Database['public']['Enums']['TrainerType'];

export interface CheckInFormData {
  name: string;
  email: string;
  timeSlot: string;
  courseType: 'group' | 'private' | 'kids_group';
  trainerId?: string;
  is1v2?: boolean;
}

