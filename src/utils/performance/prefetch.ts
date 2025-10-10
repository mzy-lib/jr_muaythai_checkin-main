import { supabase } from '../../lib/supabase';
import { memberCache } from './cacheManager';

/**
 * Prefetches common data used across the application
 */
export async function prefetchCommonData() {
  try {
    const today = new Date().toISOString().split('T')[0];

    // Parallel fetch of common data
    const [membersPromise, checkInsPromise, schedulePromise] = await Promise.all([
      // Active members
      supabase
        .from('members')
        .select('id, name, email, membership, membership_expiry')
        .eq('is_new_member', false)
        .limit(50),

      // Today's check-ins
      supabase
        .from('check_ins')
        .select('id, member_id, class_type, is_extra')
        .eq('check_in_date', today),

      // Class schedule
      supabase
        .from('class_schedule')
        .select('*')
        .order('day_of_week', { ascending: true })
    ]);

    // Cache member data
    if (membersPromise.data) {
      membersPromise.data.forEach(member => {
        memberCache.set(member.id, member);
      });
    }

    // Handle any errors
    if (membersPromise.error) console.error('Failed to prefetch members:', membersPromise.error);
    if (checkInsPromise.error) console.error('Failed to prefetch check-ins:', checkInsPromise.error);
    if (schedulePromise.error) console.error('Failed to prefetch schedule:', schedulePromise.error);

  } catch (error) {
    console.error('Prefetch failed:', error);
  }
}