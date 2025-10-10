interface Env {
  VITE_SUPABASE_URL: string;
  VITE_SUPABASE_ANON_KEY: string;
  [key: string]: string;
}

export function loadEnv(): Env {
  // Try loading from import.meta.env first (Vite environment)
  const viteEnv = import.meta.env;
  
  if (viteEnv.VITE_SUPABASE_URL && viteEnv.VITE_SUPABASE_ANON_KEY) {
    return {
      VITE_SUPABASE_URL: viteEnv.VITE_SUPABASE_URL,
      VITE_SUPABASE_ANON_KEY: viteEnv.VITE_SUPABASE_ANON_KEY
    };
  }

  // Fallback to process.env for Node.js environment
  if (process.env.VITE_SUPABASE_URL && process.env.VITE_SUPABASE_ANON_KEY) {
    return {
      VITE_SUPABASE_URL: process.env.VITE_SUPABASE_URL,
      VITE_SUPABASE_ANON_KEY: process.env.VITE_SUPABASE_ANON_KEY
    };
  }

  throw new Error('Missing required Supabase environment variables');
}