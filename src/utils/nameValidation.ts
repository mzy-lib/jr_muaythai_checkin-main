// Basic validation rules
const MIN_LENGTH = 2;
const MAX_LENGTH = 50;

// Character sets
const CHINESE_CHARS = /[\u4e00-\u9fa5]/;
const ENGLISH_CHARS = /[a-zA-Z]/;
const NUMBERS = /[0-9]/;
const SPECIAL_CHARS = /[@._\-]/;

export const isValidLength = (name: string): boolean => {
  const trimmed = name.trim();
  return trimmed.length >= MIN_LENGTH && trimmed.length <= MAX_LENGTH;
};

export const hasValidCharacters = (name: string): boolean => {
  // Allow Chinese, English, numbers, and specified special chars
  const validChars = /^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$/;
  return validChars.test(name);
};

export const hasValidStructure = (name: string): boolean => {
  const trimmed = name.trim();
  
  // Must contain at least one alphanumeric or Chinese character
  const hasValidContent = CHINESE_CHARS.test(trimmed) || 
                         ENGLISH_CHARS.test(trimmed) || 
                         NUMBERS.test(trimmed);

  // Allow special characters more flexibly
  const noExcessiveSpecials = !/[@._\-\s]{4,}/.test(trimmed);

  return hasValidContent && noExcessiveSpecials;
};

export const validateName = (name: string | undefined): boolean => {
  if (!name) return false;
  
  // Remove any potential CSV artifacts
  const cleanName = name.split(',')[0].trim();
  
  return (
    isValidLength(cleanName) &&
    hasValidCharacters(cleanName) &&
    hasValidStructure(cleanName)
  );
};

export const normalizeNameForComparison = (name: string): string => {
  return name.trim().toLowerCase();
};