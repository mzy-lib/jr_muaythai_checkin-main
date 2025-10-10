import { supabase } from '../../../lib/supabase';
import { ClassType } from '../../../types/database';

export async function getMemberByEmail(email: string) {
  const { data, error } = await supabase
    .from('members')
    .select('id')
    .eq('email', email)
    .single();
    
  if (error) throw error;
  return data.id;
}

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

export async function clearCheckIns() {
  const { error } = await supabase
    .from('check_ins')
    .delete()
    .neq('id', '00000000-0000-0000-0000-000000000000');
  
  if (error) throw error;
}

export async function resetTestData() {
  await clearCheckIns();
  
  const { error } = await supabase
    .from('members')
    .update({ 
      extra_check_ins: 0,
      is_new_member: true 
    })
    .eq('email', 'new.member.test.mt@example.com');
    
  if (error) throw error;
}