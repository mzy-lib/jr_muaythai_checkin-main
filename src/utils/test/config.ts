// Test environment configuration
export const TEST_CONFIG = {
  supabase: {
    url: import.meta.env?.VITE_SUPABASE_URL || 'https://aflqzzfgyijwvtmlytsc.supabase.co',
    anonKey: import.meta.env?.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFmbHF6emZneWlqd3Z0bWx5dHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2NjYxMjcsImV4cCI6MjA1MDI0MjEyN30.UNMa9frR_EnbeXoxiSvwNARdeE0dP8YE4a7eElt0gCo'
  }
};