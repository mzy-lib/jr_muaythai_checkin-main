import { describe, it, expect } from 'vitest';
import { supabase } from '../../../lib/supabase';

describe('Duplicate Name Check-in Tests', () => {
  it('should require email when name has duplicates', async () => {
    const { data } = await supabase.rpc('find_member_for_checkin', {
      p_name: '王小明'
    });
    expect(data.needs_email).toBe(true);
  });

  it('should find correct member with email', async () => {
    const { data } = await supabase.rpc('find_member_for_checkin', {
      p_name: '王小明',
      p_email: 'wang.xm1.test.mt@example.com'
    });
    expect(data.member_id).toBeTruthy();
  });

  it('should handle incorrect email for duplicate name', async () => {
    const { data } = await supabase.rpc('find_member_for_checkin', {
      p_name: '王小明',
      p_email: 'wrong@email.com'
    });
    expect(data.member_id).toBeNull();
  });
});