#!/usr/bin/env tsx
import { testSupabase } from './supabase';
import { testMembers, testScenarios } from './checkInTestData';
import { setupTestData, cleanupTestData } from './testUtils';

async function runTests() {
  console.log('Starting check-in system tests...\n');

  try {
    // Setup test data
    const setupSuccess = await setupTestData(testMembers);
    if (!setupSuccess) {
      throw new Error('Failed to setup test data');
    }
    console.log('✅ Test data setup complete\n');
    
    // Run test scenarios
    for (const scenario of testScenarios) {
      console.log(`Testing: ${scenario.description}`);
      
      try {
        const { data, error } = await testSupabase
          .rpc('find_member_for_checkin', {
            p_name: scenario.input.name,
            p_email: scenario.input.email
          });

        if (error) throw error;

        const result = {
          needsEmailVerification: data.needs_email,
          success: data.member_id !== null,
          isExtra: data.is_new || false
        };

        const passed = Object.entries(scenario.expectedResult)
          .every(([key, value]) => result[key as keyof typeof result] === value);

        console.log(passed ? '✅ PASSED' : '❌ FAILED');
        if (!passed) {
          console.log('Expected:', scenario.expectedResult);
          console.log('Got:', result);
        }
      } catch (err) {
        console.log('❌ FAILED');
        console.error('Error:', err);
      }
      console.log('---');
    }
  } finally {
    // Cleanup test data
    await cleanupTestData();
    console.log('\n✅ Test data cleaned up');
  }

  console.log('\nTests completed.');
}

// Run tests if executed directly
if (typeof window === 'undefined') {
  runTests().catch(console.error).finally(() => process.exit());
}