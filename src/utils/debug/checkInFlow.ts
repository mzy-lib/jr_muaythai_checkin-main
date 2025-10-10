import { supabase } from '../../lib/supabase';

export async function debugCheckInFlow(name: string) {
  console.group('Check-in Flow Debug');
  try {
    // 1. Test data verification
    const { data: testData } = await supabase
      .from('members')
      .select('*')
      .like('email', '%.test.mt@example.com');
    console.log('Test members in database:', testData);

    // 2. Direct member lookup
    const { data: directMatch } = await supabase
      .from('members')
      .select('*')
      .eq('name', name);
    console.log('Direct member lookup:', directMatch);

    // 3. RPC function call
    const { data: rpcResult, error: rpcError } = await supabase
      .rpc('find_member_for_checkin', {
        p_name: name,
        p_email: null
      });
    console.log('RPC function result:', rpcResult);
    if (rpcError) console.error('RPC error:', rpcError);

  } catch (error) {
    console.error('Debug error:', error);
  } finally {
    console.groupEnd();
  }
}