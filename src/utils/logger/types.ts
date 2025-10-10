export interface LogEntry {
  timestamp: string;
  level: 'info' | 'warn' | 'error';
  message: string;
  details?: unknown;
}

export interface CheckInLogDetails {
  memberId?: string;
  classType?: string;
  isExtra?: boolean;
  success?: boolean;
  error?: string;
}