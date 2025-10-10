export interface AppError {
  code: string;
  message: string;
  details?: string;
  hint?: string;
}

export class BaseError extends Error {
  constructor(
    message: string,
    public code: string = 'UNKNOWN_ERROR',
    public details?: string
  ) {
    super(message);
    this.name = 'BaseError';
  }
}