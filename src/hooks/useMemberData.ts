import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useMemberAuth } from '../contexts/MemberAuthContext';

export function useMemberData() {
  const { member, isAuthenticated } = useMemberAuth();
  const [memberInfo, setMemberInfo] = useState<any>(null);
  const [memberCards, setMemberCards] = useState<any[]>([]);
  const [checkInHistory, setCheckInHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 如果会员未登录，不执行数据获取
    if (!isAuthenticated || !member?.id) {
      setLoading(false);
      return;
    }

    const fetchMemberData = async () => {
      try {
        setLoading(true);
        setError(null);

        // 获取会员基本信息
        const { data: memberData, error: memberError } = await supabase
          .from('members')
          .select('*')
          .eq('id', member.id)
          .single();

        if (memberError) throw memberError;
        setMemberInfo(memberData);

        // 获取会员卡信息
        const { data: cardsData, error: cardsError } = await supabase
          .from('membership_cards')
          .select('*')
          .eq('member_id', member.id)
          .order('created_at', { ascending: false });

        if (cardsError) throw cardsError;
        setMemberCards(cardsData || []);

        // 获取签到历史
        const { data: checkInData, error: checkInError } = await supabase
          .from('check_ins')
          .select(`
            *,
            trainers(name)
          `)
          .eq('member_id', member.id)
          .order('check_in_date', { ascending: false })
          .order('created_at', { ascending: false });

        if (checkInError) throw checkInError;
        setCheckInHistory(checkInData || []);

      } catch (err) {
        console.error('获取会员数据失败:', err);
        setError('获取会员数据失败，请重试');
      } finally {
        setLoading(false);
      }
    };

    fetchMemberData();
  }, [member?.id, isAuthenticated]);

  return { memberInfo, memberCards, checkInHistory, loading, error };
} 