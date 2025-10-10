import { Member, ClassType, CardType, CardSubtype, TrainerType } from '../../types/database';

export interface ParsedRow {
  data: {
    member: Partial<Member>;
    card: {
      card_type: CardType;
      card_subtype: CardSubtype;
      card_category?: string;
      remaining_group_sessions?: number;
      remaining_private_sessions?: number;
      valid_until?: string;
      trainer_type?: TrainerType;
    };
  };
  errors: string[];
  rowNumber: number;
}

export interface ExcelRow {
  name?: string;
  email?: string;
  membership?: string;
  remaining_classes?: string | number;
  membership_expiry?: string;
  check_in_date?: string;
  class_type?: string;
  is_extra?: boolean;
  registration_date?: string;
  status?: string;
  notes?: string;
}

export interface ExcelMemberRow {
  name: string;
  email?: string;
  phone?: string;
  card_type?: CardType;
  card_category?: string;
  card_subtype?: CardSubtype;
  remaining_group_sessions?: number;
  remaining_private_sessions?: number;
  valid_until?: string;
  trainer_type?: TrainerType;
  notes?: string;
}

export interface ExcelCheckInRow {
  name: string;
  email?: string;
  class_type: ClassType;
  is_private?: boolean;
  trainer_id?: string;
  check_in_date: string;
  check_in_time?: string;
  is_extra?: boolean;
}

export interface ParsedMemberData {
  name: string;
  email: string | null;
  phone: string | null;
  card_type: CardType | null;
  card_category: string | null;
  card_subtype: CardSubtype | null;
  remaining_group_sessions: number | null;
  remaining_private_sessions: number | null;
  valid_until: string | null;
  trainer_type: TrainerType | null;
  notes: string | null;
}

export interface ParsedCheckInData {
  name: string;
  email: string | null;
  class_type: ClassType;
  is_private: boolean;
  trainer_id: string | null;
  check_in_date: string;
  check_in_time: string | null;
  is_extra: boolean;
}