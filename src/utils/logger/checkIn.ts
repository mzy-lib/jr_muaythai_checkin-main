import { ClassType } from '../../types/database';
import { logger } from './core';
import { CheckInLogDetails } from './types';

export function logMemberSearch(details: { normalizedName: string; email?: string }) {
  logger.info('Member search', details);
}

export function logMemberNotFound(details: { normalizedName: string }) {
  logger.warn('Member not found', details);
}

export function logCheckInAttempt(memberId: string, classType: ClassType) {
  logger.info('Check-in attempt', { memberId, classType });
}

export function logCheckInResult(details: { success: boolean; isExtra?: boolean }) {
  logger.info('Check-in result', details);
}

export function logCheckInError(error: unknown) {
  const details: CheckInLogDetails = {
    error: error instanceof Error ? error.message : 'Unknown error'
  };
  logger.error('Check-in error', details);
}

// Export all logging functions
export const checkInLogger = {
  logMemberSearch,
  logMemberNotFound,
  logCheckInAttempt,
  logCheckInResult,
  logCheckInError
};