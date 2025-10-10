import { supabase } from '../../../lib/supabase';
import { ClassType } from '../../../types/database';

const TEST_EMAIL_PATTERN = '%.test.mt@example.com';

/**
 * Gets a test member's ID by email
 */
export async function getMemberByEmail(email: string): Promise<string> {
  const { data, error } = await supabase
    .from('members')
    .select('id')
    .eq('email', email)
    .single();
    
  if (error) throw error;
  return data.id;
}

/**
 * Creates a check-in for testing
 */
export async function checkIn(memberId: string, classType: ClassType) {
  const { data, error } = await supabase
    .from('check_ins')
    .insert({
      member_id: memberId,
      class_type: classType
    })
    .select('is_extra')
    .single();
    
  if (error) throw error;
  return data;
}

/**
 * Clears all check-in records for test members
 */
export async function clearCheckIns() {
  const { error } = await supabase
    .from('check_ins')
    .delete()
    .eq('member_id', 'in', 
      supabase
        .from('members')
        .select('id')
        .like('email', TEST_EMAIL_PATTERN)
    );
    
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
    throw error;
  }
}