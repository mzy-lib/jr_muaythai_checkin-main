export interface CheckInResult {
  success: boolean;
  message: string;
  isExtra?: boolean;
  isDuplicate?: boolean;
  isNewMember?: boolean;
  needsEmailVerification?: boolean;
} 