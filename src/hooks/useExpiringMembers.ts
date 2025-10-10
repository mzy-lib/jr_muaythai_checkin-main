import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface ExpiringMember {
  id: string;
  name: string;
  card_id: string;
  card_type: string;
  valid_until: string;
  remaining_sessions?: number;
}

export const useExpiringMembers = () => {
  const [members, setMembers] = useState<ExpiringMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchExpiringMembers = async () => {
      try {
        setLoading(true);
        
        // 获取7天内到期的会员卡
        const today = new Date();
        const sevenDaysFromNow = new Date();
        sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
        
        const todayStr = today.toISOString().split('T')[0];
        const sevenDaysLaterStr = sevenDaysFromNow.toISOString().split('T')[0];

        // 从membership_cards表查询
        const { data, error: cardsError } = await supabase
          .from('membership_cards')
          .select(`
            card_id,
            member_id,
            card_type,
            valid_until,
            remaining_group_sessions,
            members!inner(id, name)
          `)
          .not('valid_until', 'is', null)
          .lte('valid_until', sevenDaysLaterStr)
          .gt('valid_until', todayStr)
          .order('valid_until');

        if (cardsError) throw cardsError;

        // 转换数据格式
        setMembers(data?.map(card => ({
          id: card.member_id,
          name: card.members.name,
          card_id: card.card_id,
          card_type: card.card_type,
          valid_until: card.valid_until,
          remaining_sessions: card.remaining_group_sessions,
        })) || []);

      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchExpiringMembers();
  }, []);

  return { members, loading, error };
};