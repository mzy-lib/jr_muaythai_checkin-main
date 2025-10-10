// Basic validation rules
const MIN_LENGTH = 2;
const MAX_LENGTH = 50;

// Character sets
const CHINESE_CHARS = /[\u4e00-\u9fa5]/;
const ENGLISH_CHARS = /[a-zA-Z]/;
const NUMBERS = /[0-9]/;
const SPECIAL_CHARS = /[@._\-]/;

export function validateMemberName(name?: string): boolean {
  if (!name) return false;
  
  const trimmed = name.trim();
  
  // Length validation
  if (trimmed.length < MIN_LENGTH || trimmed.length > MAX_LENGTH) {
    return false;
  }

  // Character validation
  const validChars = /^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$/;
  if (!validChars.test(trimmed)) {
    return false;
  }

  // Must contain at least one alphanumeric or Chinese character
  const hasValidContent = CHINESE_CHARS.test(trimmed) || 
                         ENGLISH_CHARS.test(trimmed) || 
                         NUMBERS.test(trimmed);

  // Not too many special characters
  const noExcessiveSpecials = !/[@._\-\s]{4,}/.test(trimmed);

  return hasValidContent && noExcessiveSpecials;
}