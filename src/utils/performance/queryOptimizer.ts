import { supabase } from '../../lib/supabase';
import { memberCache, checkInCache } from './cacheManager';

/**
 * Optimizes database queries with caching
 */
export const queryOptimizer = {
  // Batch fetch members with cache
  async batchGetMembers(ids: string[]) {
    const uncachedIds = ids.filter(id => !memberCache.get(id));
    
    if (uncachedIds.length > 0) {
      const { data } = await supabase
        .from('members')
        .select('*')
        .in('id', uncachedIds);
        
      data?.forEach(member => {
        memberCache.set(member.id, member);
      });
    }
    
    return ids.map(id => memberCache.get(id));
  },

  // Get check-in records with cache
  async getCheckInRecords(memberId: string, limit: number = 10) {
    const cacheKey = `checkins:${memberId}:${limit}`;
    const cached = checkInCache.get(cacheKey);
    
    if (cached) return cached;

    const { data } = await supabase
      .from('check_ins')
      .select('*')
      .eq('member_id', memberId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (data) {
      checkInCache.set(cacheKey, data);
    }
    
    return data || [];
  }
};