import { LogEntry } from './types';

class Logger {
  private logs: LogEntry[] = [];

  private log(level: LogEntry['level'], message: string, details?: unknown) {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      details: details ? JSON.parse(JSON.stringify(details)) : undefined
    };

    this.logs.push(entry);
    
    if (process.env.NODE_ENV !== 'production') {
      console[level](message, details);
    }
  }

  info(message: string, details?: unknown) {
    this.log('info', message, details);
  }

  warn(message: string, details?: unknown) {
    this.log('warn', message, details);
  }

  error(message: string, details?: unknown) {
    this.log('error', message, details);
  }

  getLogs(): LogEntry[] {
    return [...this.logs];
  }
}

export const logger = new Logger();