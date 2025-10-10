import { Env } from './types';

/**
 * Loads environment variables from various sources
 * with proper error handling and validation
 */
export function loadEnv(): Env {
  // Try Vite environment first
  if (typeof import.meta !== 'undefined' && import.meta.env) {
    const { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY } = import.meta.env;
    
    if (VITE_SUPABASE_URL && VITE_SUPABASE_ANON_KEY) {
      return validateEnv({ VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY });
    }
  }

  // Try Node.js environment variables
  if (typeof process !== 'undefined' && process.env) {
    const { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY } = process.env;
    
    if (VITE_SUPABASE_URL && VITE_SUPABASE_ANON_KEY) {
      return validateEnv({ VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY });
    }
  }

  throw new Error(
    'Missing required Supabase environment variables. ' +
    'Please ensure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set.'
  );
}

function validateEnv(env: Partial<Env>): Env {
  const { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY } = env;

  if (!VITE_SUPABASE_URL || !VITE_SUPABASE_ANON_KEY) {
    throw new Error('Invalid environment variables');
  }

  // Validate URL format
  try {
    new URL(VITE_SUPABASE_URL);
  } catch {
    throw new Error('Invalid Supabase URL format');
  }

  // Validate anon key format (should be JWT)
  if (!VITE_SUPABASE_ANON_KEY.includes('.')) {
    throw new Error('Invalid Supabase anon key format');
  }

  return { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY };
}