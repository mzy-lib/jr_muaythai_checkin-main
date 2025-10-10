import { testSupabase } from './supabase';
import { testMembers, testScenarios } from './checkInTestData';

// Test runner function for browser environment
export async function runCheckInTests() {
  console.log('Starting check-in system tests...\n');

  try {
    // Setup test data
    console.log('Setting up test data...');
    for (const member of testMembers) {
      const { error } = await testSupabase.from('members').upsert(member);
      if (error) throw error;
    }
    console.log('✅ Test members created\n');

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

    // Cleanup test data
    console.log('\nCleaning up test data...');
    const emails = testMembers.map(m => m.email).filter(Boolean);
    const { error } = await testSupabase.from('members').delete().in('email', emails);
    if (error) throw error;
    console.log('✅ Test data cleaned up');

  } catch (err) {
    console.error('Test execution failed:', err);
  }

  console.log('\nTests completed.');
}

// Make test runner available globally
declare global {
  interface Window {
    runCheckInTests: () => Promise<void>;
  }
}

// Expose test runner to window object
window.runCheckInTests = runCheckInTests;