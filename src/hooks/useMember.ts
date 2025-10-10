import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Member, CheckIn } from '../types/database';

export function useMember(memberId: string) {
  const [member, setMember] = useState<Member | null>(null);
  const [checkIns, setCheckIns] = useState<CheckIn[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchMemberData() {
      try {
        const [memberResponse, checkInsResponse] = await Promise.all([
          supabase
            .from('members')
            .select('*')
            .eq('id', memberId)
            .single(),
          supabase
            .from('check_ins')
            .select('*')
            .eq('member_id', memberId)
            .order('created_at', { ascending: false })
            .limit(10)
        ]);

        if (memberResponse.error) throw memberResponse.error;
        if (checkInsResponse.error) throw checkInsResponse.error;

        setMember(memberResponse.data);
        setCheckIns(checkInsResponse.data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setLoading(false);
      }
    }

    fetchMemberData();
  }, [memberId]);

  return { member, checkIns, loading, error };
}