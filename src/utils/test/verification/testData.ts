import { supabase } from '../../../lib/supabase';
import { Member } from '../../../types/database';

interface VerificationResult {
  success: boolean;
  members?: Member[];
  checkIns?: number;
  error?: string;
}

/**
 * Verifies test data in the database
 */
export async function verifyTestData(): Promise<VerificationResult> {
  try {
    // Check test members
    const { data: members, error: memberError } = await supabase
      .from('members')
      .select('*')
      .like('email', '%.test.mt@example.com');

    if (memberError) {
      throw memberError;
    }

    if (!members?.length) {
      return {
        success: false,
        error: 'No test members found in database'
      };
    }

    // Verify required test members exist
    const requiredMembers = ['张三', '李四', '王五'];
    const missingMembers = requiredMembers.filter(name => 
      !members.some(m => normalizeName(m.name) === normalizeName(name))
    );

    if (missingMembers.length > 0) {
      return {
        success: false,
        error: `Missing required test members: ${missingMembers.join(', ')}`
      };
    }

    // Check check-ins
    const { data: checkIns, error: checkInError } = await supabase
      .from('check_ins')
      .select('*')
      .in('member_id', members.map(m => m.id));

    if (checkInError) {
      throw checkInError;
    }

    return {
      success: true,
      members,
      checkIns: checkIns?.length || 0
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

function normalizeName(name: string): string {
  return name.trim().toLowerCase();
}