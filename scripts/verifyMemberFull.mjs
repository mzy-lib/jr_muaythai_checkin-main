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

async function verifyMember(name) {
  try {
    console.log('\nChecking member:', name);
    console.log('===================');

    // 1. Direct database query
    console.log('\n1. Direct database lookup:');
    const { data: members, error: queryError } = await supabase
      .from('members')
      .select('*')
      .eq('name', name);

    if (queryError) {
      console.error('Query error:', queryError.message);
    } else {
      if (members && members.length > 0) {
        members.forEach(member => {
          console.log('\nMember found:');
          console.log('- Name:', member.name);
          console.log('- Email:', member.email || 'N/A');
          console.log('- New member:', member.is_new_member ? 'Yes' : 'No');
          console.log('- Membership:', member.membership || 'None');
          if (member.membership_expiry) {
            console.log('- Expiry:', new Date(member.membership_expiry).toLocaleDateString());
          }
          if (member.remaining_classes !== null) {
            console.log('- Remaining classes:', member.remaining_classes);
          }
        });
      } else {
        console.log('No members found with direct lookup');
      }
    }

    // 2. RPC function call
    console.log('\n2. RPC function lookup:');
    const { data: rpcResult, error: rpcError } = await supabase
      .rpc('find_member_for_checkin', {
        p_name: name
      });

    if (rpcError) {
      console.error('RPC error:', rpcError.message);
    } else {
      console.log('RPC result:', rpcResult);
    }

  } catch (error) {
    console.error('Verification failed:', error);
  }
}

// Get name from command line argument
const name = process.argv[2];
if (!name) {
  console.error('Please provide a name to verify');
  process.exit(1);
}

verifyMember(name);