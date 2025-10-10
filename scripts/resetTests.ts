#!/usr/bin/env node
import { resetTestData } from '../src/utils/test/helpers/testDb';

async function main() {
  try {
    await resetTestData();
    process.exit(0);
  } catch (error) {
    console.error('Error resetting test data:', error);
    process.exit(1);
  }
}

main();