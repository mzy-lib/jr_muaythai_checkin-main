import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { CardSubtype } from '../types/database';

interface MembershipData {
  type: CardSubtype;
  count: number;
}

export function useMembershipDistribution() {
  const [data, setData] = useState<MembershipData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchDistribution();
  }, []);

  const fetchDistribution = async () => {
    try {
      const { data: cards, error: fetchError } = await supabase
        .from('membership_cards')
        .select('card_subtype');

      if (fetchError) throw fetchError;

      // 统计各类型会员卡数量
      const distribution = cards.reduce((acc: Record<string, number>, card) => {
        if (!card.card_subtype) return acc;
        acc[card.card_subtype] = (acc[card.card_subtype] || 0) + 1;
        return acc;
      }, {});

      // 转换为数组格式
      const formattedData = Object.entries(distribution).map(([type, count]) => ({
        type: type as CardSubtype,
        count
      }));

      setData(formattedData);
    } catch (err) {
      console.error('Error fetching membership distribution:', err);
      setError('获取会员卡分布数据失败 Failed to fetch membership distribution');
    } finally {
      setLoading(false);
    }
  };

  return { data, loading, error };
}