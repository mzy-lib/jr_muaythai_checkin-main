#!/usr/bin/env node
import { supabase } from '../src/lib/supabase';

async function verifyTestData() {
  try {
    // Check test members
    const { data: members, error: memberError } = await supabase
      .from('members')
      .select('*')
      .like('email', '%.test.mt@example.com');

    if (memberError) throw memberError;

    console.log('\nTest Members:');
    members.forEach(m => {
      console.log(`- ${m.name} (${m.email})`);
      console.log(`  Membership: ${m.membership}`);
      console.log(`  Status: ${m.is_new_member ? 'New' : 'Regular'}`);
    });

    // Check check-ins
    const { data: checkIns, error: checkInError } = await supabase
      .from('check_ins')
      .select('*')
      .in('member_id', members.map(m => m.id));

    if (checkInError) throw checkInError;

    console.log('\nCheck-ins:', checkIns.length);

    return true;
  } catch (error) {
    console.error('Error verifying test data:', error);
    return false;
  }
}

async function main() {
  const success = await verifyTestData();
  process.exit(success ? 0 : 1);
}

main();