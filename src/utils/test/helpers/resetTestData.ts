import { supabase } from '../../../lib/supabase';

export async function resetTestData() {
  try {
    // First delete all check-ins for test members
    await supabase
      .from('check_ins')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');

    // Reset test members' counters and status
    await supabase
      .from('members')
      .update({ 
        extra_check_ins: 0,
        is_new_member: true 
      })
      .eq('email', 'new.member.test.mt@example.com');

    return { success: true };
  } catch (error) {
    console.error('Failed to reset test data:', error);
    return { success: false, error };
  }
}