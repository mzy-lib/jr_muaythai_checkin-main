import { testSupabase } from './supabase';

export async function cleanupTestData() {
  try {
    // Delete check-ins first due to foreign key constraints
    await testSupabase
      .from('check_ins')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    // Then delete test members
    await testSupabase
      .from('members')
      .delete()
      .or('email.like.%.test.mt@example.com,email.like.%test.checkin%');
      
    return true;
  } catch (error) {
    console.error('Failed to cleanup test data:', error);
    return false;
  }
}

export async function setupTestData(members: any[]) {
  try {
    // Clean up any existing test data first
    await cleanupTestData();
    
    // Insert new test members
    for (const member of members) {
      const { error } = await testSupabase
        .from('members')
        .upsert(member);
      
      if (error) throw error;
    }
    
    return true;
  } catch (error) {
    console.error('Failed to setup test data:', error);
    return false;
  }
}