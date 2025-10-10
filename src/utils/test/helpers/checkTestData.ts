import { supabase } from '../../../lib/supabase';

export async function checkTestData() {
  const { data, error } = await supabase
    .from('members')
    .select('*')
    .like('email', '%.test.mt@example.com');

  if (error) {
    console.error('Error checking test data:', error);
    return;
  }

  console.log('Test members in database:', data.map(m => ({
    name: m.name,
    email: m.email,
    membership: m.membership
  })));
}