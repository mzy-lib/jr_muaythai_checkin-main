#!/usr/bin/env node
import { resetTestData } from '../src/utils/test/helpers/testData.js';

async function main() {
  try {
    const success = await resetTestData();
    process.exit(success ? 0 : 1);
  } catch (error) {
    console.error('Error resetting test data:', error);
    process.exit(1);
  }
}

main();