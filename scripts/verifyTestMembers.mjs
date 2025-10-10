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

// Required test members to verify
const REQUIRED_MEMBERS = [
  { name: '张三', membership: 'single_monthly' },
  { name: '李四', membership: 'double_monthly' },
  { name: '王五', membership: 'single_monthly' },
  { name: '赵六', membership: 'ten_classes' },
  { name: '孙七', membership: 'two_classes' },
  { name: '周八', membership: 'single_class' }
];

async function verifyTestMembers() {
  try {
    console.log('\nVerifying test members...');
    console.log('=======================');

    // Get all test members
    const { data: members, error } = await supabase
      .from('members')
      .select('*')
      .like('email', '%.test.mt@example.com');

    if (error) throw error;

    // Check each required member
    for (const required of REQUIRED_MEMBERS) {
      const member = members?.find(m => m.name === required.name);
      console.log(`\nChecking ${required.name}:`);
      
      if (member) {
        console.log('✓ Found in database');
        console.log('- Email:', member.email);
        console.log('- Membership:', member.membership);
        console.log('- New member:', member.is_new_member ? 'Yes' : 'No');
        
        // Verify membership type
        if (member.membership !== required.membership) {
          console.log('⚠️  Wrong membership type!');
          console.log(`  Expected: ${required.membership}`);
          console.log(`  Found: ${member.membership}`);
        }
        
        // Verify not marked as new member
        if (member.is_new_member) {
          console.log('⚠️  Incorrectly marked as new member!');
        }
      } else {
        console.log('❌ Not found in database!');
      }
    }

  } catch (error) {
    console.error('\nVerification failed:', error);
  }
}

verifyTestMembers();