#!/usr/bin/env node
import { supabase } from '../src/lib/supabase';

async function checkTestData() {
  try {
    const { data, error } = await supabase
      .from('members')
      .select('*')
      .like('email', '%.test.mt@example.com');

    if (error) {
      throw error;
    }

    console.log('Test members in database:', data.map(m => ({
      name: m.name,
      email: m.email,
      membership: m.membership
    })));

    return true;
  } catch (error) {
    console.error('Error checking test data:', error);
    return false;
  }
}

async function main() {
  const success = await checkTestData();
  process.exit(success ? 0 : 1);
}

main();