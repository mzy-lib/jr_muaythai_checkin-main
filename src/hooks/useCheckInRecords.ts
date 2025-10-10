import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { CheckIn, ClassType } from '../types/database';
import { useAuth } from './useAuth';

interface FetchFilters {
  startDate?: string;
  endDate?: string;
  classType?: ClassType;
  isExtra?: boolean;
  memberId?: string;
  memberName?: string;
  limit?: number;
}

export function useCheckInRecords(memberId: string, limit: number) {
  const [records, setRecords] = useState<CheckIn[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchRecords = async () => {
    if (!user) {
      setRecords([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const { data, error: fetchError } = await supabase
        .from('check_ins')
        .select('*')
        .eq('member_id', memberId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (fetchError) throw fetchError;
      setRecords(data || []);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch check-in records');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchRecords();
  }, [user]);

  return { records, loading, error, fetchRecords };
}