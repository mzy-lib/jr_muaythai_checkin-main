import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { MembershipType } from '../types/database';

interface MembershipTypeCounts {
  single_monthly: number;
  double_monthly: number;
  ten_classes: number;
  two_classes: number;
  single_class: number;
}

interface MembershipStats {
  membershipTypeCounts: MembershipTypeCounts;
  total: number;
}

export const useMembershipStats = () => {
  const [stats, setStats] = useState<MembershipStats>({
    membershipTypeCounts: {
      single_monthly: 0,
      double_monthly: 0,
      ten_classes: 0,
      two_classes: 0,
      single_class: 0,
    },
    total: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchMembershipStats = async () => {
      try {
        console.log('[MembershipStats] 开始获取会员卡统计数据');
        setLoading(true);

        // 尝试从缓存获取数据
        const cached = localStorage.getItem('membership-stats');
        if (cached) {
          const { data, timestamp } = JSON.parse(cached);
          const isValid = Date.now() - timestamp < 5 * 60 * 1000; // 5分钟缓存
          
          if (isValid) {
            console.log('[MembershipStats] 使用缓存数据');
            setStats(data);
            setLoading(false);
            return;
          }
        }

        // 获取所有有效会员的会员卡类型统计
        const { data, error: statsError } = await supabase
          .from('members')
          .select('membership')
          .gt('membership_expiry', new Date().toISOString());

        if (statsError) {
          console.error('[MembershipStats] 查询失败:', statsError);
          throw statsError;
        }

        console.log('[MembershipStats] 查询结果:', data);

        // 统计各类型会员卡数量
        const counts: MembershipTypeCounts = {
          single_monthly: 0,
          double_monthly: 0,
          ten_classes: 0,
          two_classes: 0,
          single_class: 0,
        };

        data?.forEach(member => {
          const membership = member.membership as MembershipType;
          if (membership in counts) {
            counts[membership as keyof MembershipTypeCounts]++;
          }
        });

        const total = Object.values(counts).reduce((sum, count) => sum + count, 0);

        const newStats = { 
          membershipTypeCounts: counts,
          total
        };

        // 更新缓存
        localStorage.setItem('membership-stats', JSON.stringify({
          data: newStats,
          timestamp: Date.now()
        }));

        console.log('[MembershipStats] 统计结果:', newStats);
        setStats(newStats);
      } catch (err) {
        console.error('[MembershipStats] 错误:', err);
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchMembershipStats();
  }, []);

  return { stats, loading, error };
};