import { useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';

interface CheckInStats {
  totalCheckins: number;
  extraCheckins: number;
  regularCheckins: number;
  memberStats: {
    name: string;
    totalCheckins: number;
    extraCheckins: number;
    regularCheckins: number;
  }[];
}

interface StatsFilters {
  memberName?: string;
  startDate?: string;
  endDate?: string;
  classType?: string;
  isExtra?: boolean;
}

export function useCheckInStats() {
  const [stats, setStats] = useState<CheckInStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchStats = useCallback(async (filters?: StatsFilters) => {
    try {
      setLoading(true);
      setError(null);

      // 调用总体统计函数
      const { data: totalStats, error: totalError } = await supabase
        .rpc('get_checkin_total_stats', {
          p_member_name: filters?.memberName || null,
          p_start_date: filters?.startDate || null,
          p_end_date: filters?.endDate || null,
          p_class_type: filters?.classType || null,
          p_is_extra: filters?.isExtra || null
        });

      if (totalError) throw totalError;

      // 调用会员统计函数
      const { data: memberStats, error: memberError } = await supabase
        .rpc('get_checkin_member_stats', {
          p_start_date: filters?.startDate || null,
          p_end_date: filters?.endDate || null,
          p_class_type: filters?.classType || null,
          p_is_extra: filters?.isExtra || null
        });

      if (memberError) throw memberError;

      setStats({
        ...totalStats[0],
        memberStats: memberStats || []
      });

    } catch (err) {
      console.error('Error fetching check-in stats:', err);
      setError(err instanceof Error ? err.message : '获取统计数据失败');
    } finally {
      setLoading(false);
    }
  }, []);

  return {
    stats,
    loading,
    error,
    fetchStats
  };
} 