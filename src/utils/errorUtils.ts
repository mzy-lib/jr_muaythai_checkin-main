import { PostgrestError } from '@supabase/supabase-js';
import { messages } from './messageUtils';

export function handleCheckInError(error: unknown): string {
  if (error instanceof Error) {
    // Handle specific error messages from the database
    if (error.message.includes('已在该时段签到')) {
      return messages.checkIn.duplicateCheckIn;
    }
    
    // Handle member not found
    if (error.message.includes('Member not found')) {
      return messages.checkIn.memberNotFound;
    }
    
    // Handle Supabase errors
    if ((error as PostgrestError).code) {
      const pgError = error as PostgrestError;
      switch (pgError.code) {
        case 'P0001':
          // Handle custom database errors
          return pgError.message || messages.checkIn.error;
        case '23505': // unique_violation
          return messages.checkIn.duplicateCheckIn;
        case '23503': // foreign_key_violation
          return messages.checkIn.invalidMember;
        default:
          return messages.checkIn.error;
      }
    }
    
    return error.message;
  }
  
  return messages.checkIn.error;
}