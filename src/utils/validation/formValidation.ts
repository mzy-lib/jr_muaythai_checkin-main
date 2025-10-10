import { validateMemberName } from './memberValidation';
import { validateEmail } from './emailValidation';
import { messages } from '../messageUtils';

export interface ValidationResult {
  isValid: boolean;
  error?: string;
}

export function validateCheckInForm(name: string, email: string): ValidationResult {
  if (!name?.trim()) {
    return {
      isValid: false,
      error: messages.validation.nameRequired
    };
  }

  if (!validateMemberName(name)) {
    return {
      isValid: false,
      error: messages.validation.invalidName
    };
  }

  if (!email?.trim()) {
    return {
      isValid: false,
      error: messages.validation.emailRequired
    };
  }

  if (!validateEmail(email)) {
    return {
      isValid: false,
      error: messages.validation.invalidEmail
    };
  }

  return { isValid: true };
}

export function validateNewMemberForm(name: string, email: string): ValidationResult {
  return validateCheckInForm(name, email);
}