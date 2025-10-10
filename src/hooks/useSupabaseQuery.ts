import { useState, useCallback } from 'react';
import { retryWithBackoff, handleSupabaseError } from '../utils/fetchUtils';

export function useSupabaseQuery<T>() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const executeQuery = useCallback(async (queryFn: () => Promise<T>) => {
    setLoading(true);
    setError(null);
    
    try {
      const result = await retryWithBackoff(queryFn);
      return result;
    } catch (err) {
      const errorMessage = handleSupabaseError(err);
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  return { executeQuery, loading, error };
}