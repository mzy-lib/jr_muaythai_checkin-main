import { supabase } from '../../lib/supabase';

export async function debugMemberSearch(name: string) {
  console.group('Member Search Debug');
  try {
    // 1. Log raw search attempt
    console.log('Raw search:', { name });

    // 2. Check exact match
    const { data: exactMatch, error: exactError } = await supabase
      .from('members')
      .select('*')
      .eq('name', name);
    console.log('Exact match:', exactMatch, exactError);

    // 3. Check case-insensitive match
    const { data: caseMatch, error: caseError } = await supabase
      .from('members')
      .select('*')
      .ilike('name', name);
    console.log('Case-insensitive match:', caseMatch, caseError);

    // 4. Check RPC function
    const { data: rpcMatch, error: rpcError } = await supabase
      .rpc('find_member_for_checkin', {
        p_name: name,
        p_email: null
      });
    console.log('RPC match:', rpcMatch, rpcError);

  } catch (error) {
    console.error('Debug error:', error);
  } finally {
    console.groupEnd();
  }
}