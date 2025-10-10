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

const env = loadEnv();
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verifyMember(name) {
  console.log('\nVerifying member:', name);
  
  // Try exact match
  const { data: exactMatch, error: exactError } = await supabase
    .from('members')
    .select('*')
    .eq('name', name);
    
  console.log('\nExact match results:', exactMatch);
  
  // Try normalized match
  const { data: normalizedMatch, error: normalizedError } = await supabase
    .from('members')
    .select('*')
    .ilike('name', name);
    
  console.log('\nNormalized match results:', normalizedMatch);
  
  if (exactError || normalizedError) {
    console.error('Errors:', { exactError, normalizedError });
  }
}

// Get name from command line argument
const name = process.argv[2];
if (!name) {
  console.error('Please provide a name to verify');
  process.exit(1);
}

verifyMember(name);