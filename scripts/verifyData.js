#!/usr/bin/env node
const { createClient } = require('@supabase/supabase-js');

// Get environment variables
const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing Supabase environment variables');
  process.exit(1);
}

// Create Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

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