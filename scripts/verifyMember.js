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

// Normalize name for comparison
function normalizeName(name) {
  return name
    .trim()
    .toLowerCase()
    .normalize('NFKC')
    .replace(/\s+/g, ' ');
}

async function verifyMember(name) {
  try {
    const normalizedName = normalizeName(name);
    console.log('Searching for member:', {
      original: name,
      normalized: normalizedName
    });

    // Direct database query
    const { data: directMatch, error: directError } = await supabase
      .from('members')
      .select('*')
      .eq('name', name);

    console.log('\nDirect matches:', directMatch?.length || 0);
    if (directMatch?.length) {
      console.log(directMatch);
    }

    // RPC call
    const { data: rpcResult, error: rpcError } = await supabase
      .rpc('find_member_for_checkin', {
        p_name: normalizedName
      });

    console.log('\nRPC result:', rpcResult);

    if (directError || rpcError) {
      console.error('Errors:', { directError, rpcError });
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