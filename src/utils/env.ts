import { loadEnv } from './envLoader';

// Load environment variables
const env = loadEnv();

// Export environment variables
export const SUPABASE_URL = env.VITE_SUPABASE_URL;
export const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY;