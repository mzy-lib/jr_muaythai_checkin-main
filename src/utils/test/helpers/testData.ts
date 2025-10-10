import { supabase } from '../../../lib/supabase';

const TEST_EMAIL_PATTERN = '%.test.mt@example.com';

/**
 * Clears all check-in records for test members
 */
export async function clearCheckIns() {
  const { error } = await supabase
    .from('check_ins')
    .delete()
    .like('member_id::text', TEST_EMAIL_PATTERN);
    
  if (error) throw error;
}

/**
 * Resets test member status
 */
export async function resetMemberStatus() {
  const { error } = await supabase
    .from('members')
    .update({ 
      extra_check_ins: 0,
      is_new_member: true,
      remaining_classes: 5 // Reset class-based memberships
    })
    .like('email', TEST_EMAIL_PATTERN);
    
  if (error) throw error;
}

/**
 * Resets all test data to initial state
 */
export async function resetTestData() {
  try {
    await clearCheckIns();
    await resetMemberStatus();
    console.log('✓ Test data reset successfully');
    return true;
  } catch (error) {
    console.error('Failed to reset test data:', error);
    return false;
  }
}