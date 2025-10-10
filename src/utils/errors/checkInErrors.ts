import { PostgrestError } from '@supabase/supabase-js';

export class CheckInError extends Error {
  constructor(
    message: string,
    public code: string,
    public hint?: string
  ) {
    super(message);
    this.name = 'CheckInError';
  }
}

export const createCheckInError = (error: unknown): CheckInError => {
  if (error instanceof Error) {
    const pgError = error as PostgrestError;
    
    // Handle duplicate check-in error
    if (pgError.hint === 'duplicate_checkin') {
      return new CheckInError(
        pgError.message,
        'DUPLICATE_CHECKIN',
        'duplicate_checkin'
      );
    }

    // Handle duplicate name error
    if (pgError.message?.includes('Multiple members found')) {
      return new CheckInError(
        '存在重名会员，请提供邮箱验证身份。Multiple members found, please provide email for verification.',
        'DUPLICATE_NAME',
        'duplicate_name'
      );
    }

    // Handle other database errors
    if (pgError.code) {
      return new CheckInError(
        pgError.message || '签到失败，请重试。Check-in failed, please try again.',
        'DATABASE_ERROR'
      );
    }

    // Network errors
    if (error.message.includes('Failed to fetch') || 
        error.message.includes('Network error')) {
      return new CheckInError(
        '网络连接错误，请检查网络后重试。Network error, please check your connection.',
        'NETWORK_ERROR'
      );
    }

    return new CheckInError(error.message, 'UNKNOWN_ERROR');
  }

  return new CheckInError(
    '签到失败，请重试。Check-in failed, please try again.',
    'UNKNOWN_ERROR'
  );
};