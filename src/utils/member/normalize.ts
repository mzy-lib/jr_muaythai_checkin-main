/**
 * Normalizes a name for comparison by:
 * 1. Trimming whitespace
 * 2. Converting to lowercase
 * 3. Normalizing Unicode characters
 * 4. Removing extra spaces
 */
export function normalizeName(name: string): string {
  if (!name) return '';
  
  return name
    .trim()
    .toLowerCase()
    // Normalize Unicode characters
    .normalize('NFKC')
    // Replace multiple spaces with single space
    .replace(/\s+/g, ' ');
}

/**
 * Normalizes a name for database comparison
 */
export function normalizeNameForComparison(name: string): string {
  return normalizeName(name);
}