import { useState, useEffect, useCallback } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase, checkAuth } from '../lib/supabase';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkSession = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const session = await checkAuth();
      setUser(session?.user ?? null);

    } catch (err) {
      console.error('Auth error:', err);
      setError('认证失败，请重试。Authentication failed, please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  const retry = useCallback(async () => {
    setError(null);
    await checkSession();
  }, [checkSession]);

  useEffect(() => {
    checkSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, [checkSession]);

  return { user, loading, error, retry };
}