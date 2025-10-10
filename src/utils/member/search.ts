import { supabase } from '../../lib/supabase';
import { MemberSearchResult } from './types';
import { normalizeNameForComparison } from './normalize';
import { logger } from '../logger/core';

export async function findMemberForCheckIn({ 
  name, 
  email 
}: { 
  name: string; 
  email?: string | null; 
}): Promise<MemberSearchResult> {
  try {
    const normalizedName = normalizeNameForComparison(name);
    
    logger.info('Member search attempt', { 
      originalName: name,
      normalizedName, 
      email 
    });

    // Call RPC function
    const { data, error } = await supabase.rpc(
      'find_member_for_checkin',
      {
        p_name: normalizedName,
        p_email: email?.trim() || null
      }
    );

    if (error) {
      logger.error('Member search RPC error', { error });
      throw error;
    }

    // Important: Handle array result properly
    const result = Array.isArray(data) ? data[0] : data;

    if (!result || !result.member_id) {
      logger.warn('No member found', { normalizedName });
      return {
        member_id: null,
        is_new: true,
        needs_email: false
      };
    }

    logger.info('Member search result', result);

    return {
      member_id: result.member_id,
      is_new: result.is_new || false,
      needs_email: result.needs_email || false
    };

  } catch (error) {
    logger.error('Member search error', { error });
    throw error;
  }
}