import { describe, it, expect } from 'vitest';
import { getMemberByEmail, checkIn } from '../helpers/checkInHelpers';
import { supabase } from '../../../lib/supabase';

describe('New Member Check-in Tests', () => {
  it('should mark new member check-in as extra', async () => {
    const memberId = await getMemberByEmail('new.member.test.mt@example.com');
    const result = await checkIn(memberId, 'morning');
    expect(result.is_extra).toBe(true);
  });

  it('should update new member status after first check-in', async () => {
    const memberId = await getMemberByEmail('new.member.test.mt@example.com');
    await checkIn(memberId, 'morning');
    
    const { data: member } = await supabase
      .from('members')
      .select('is_new_member')
      .eq('id', memberId)
      .single();
      
    expect(member?.is_new_member).toBe(false);
  });
});