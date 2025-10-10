#!/usr/bin/env node
import { supabase } from '../src/lib/supabase';
import { normalizeName } from '../src/utils/member/normalize';

async function verifyMember(name: string) {
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