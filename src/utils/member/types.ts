// Member search types
export interface MemberSearchResult {
  member_id: string | null;
  is_new: boolean;
  needs_email: boolean;
}

export interface MemberSearchParams {
  name: string;
  email?: string | null;
}