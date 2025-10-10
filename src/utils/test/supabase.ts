import { createClient } from '@supabase/supabase-js';
import { TEST_CONFIG } from './config';
import type { Database } from '../../types/database';

// Create Supabase client for testing
export const testSupabase = createClient<Database>(
  TEST_CONFIG.supabase.url,
  TEST_CONFIG.supabase.anonKey
);