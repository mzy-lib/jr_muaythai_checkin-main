#!/usr/bin/env node
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { readFileSync } from 'fs';

// Get current directory
const __dirname = dirname(fileURLToPath(import.meta.url));

// Load environment variables from .env file
function loadEnv() {
  try {
    const envPath = join(__dirname, '..', '.env');
    const envContent = readFileSync(envPath, 'utf8');
    return Object.fromEntries(
      envContent
        .split('\n')
        .filter(line => line && !line.startsWith('#'))
        .map(line => line.split('=').map(part => part.trim()))
    );
  } catch (error) {
    console.error('Failed to load .env file:', error);
    return process.env;
  }
}

// Get environment variables
const env = loadEnv();
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing required Supabase environment variables');
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

    console.log('\nTest Members:', members?.length || 0);
    members?.forEach(m => {
      console.log(`- ${m.name} (${m.email || 'no email'})`);
      console.log(`  Membership: ${m.membership || 'none'}`);
      console.log(`  Status: ${m.is_new_member ? 'New' : 'Regular'}`);
      if (m.membership_expiry) {
        console.log(`  Expires: ${new Date(m.membership_expiry).toLocaleDateString()}`);
      }
      if (m.remaining_classes) {
        console.log(`  Classes: ${m.remaining_classes}`);
      }
    });

    // Check check-ins
    if (members?.length) {
      const { data: checkIns, error: checkInError } = await supabase
        .from('check_ins')
        .select('*')
        .in('member_id', members.map(m => m.id));

      if (checkInError) throw checkInError;
      console.log('\nCheck-ins:', checkIns?.length || 0);
    }

    console.log('\n✓ Test data verified successfully');
    return true;
  } catch (error) {
    console.error('\nError verifying test data:', error);
    return false;
  }
}

verifyTestData()
  .then(success => process.exit(success ? 0 : 1))
  .catch(() => process.exit(1));