import { describe, it, expect } from 'vitest';
import { getMemberByEmail, checkIn } from '../helpers/checkInHelpers';

describe('Monthly Membership Check-in Tests', () => {
  describe('Single Daily Monthly', () => {
    it('should allow first check-in of the day', async () => {
      const memberId = await getMemberByEmail('zhang.san.test.mt@example.com');
      const result = await checkIn(memberId, 'morning');
      expect(result.is_extra).toBe(false);
    });

    it('should mark second check-in of the day as extra', async () => {
      const memberId = await getMemberByEmail('zhang.san.test.mt@example.com');
      await checkIn(memberId, 'morning');
      const result = await checkIn(memberId, 'evening');
      expect(result.is_extra).toBe(true);
    });
  });

  describe('Double Daily Monthly', () => {
    it('should allow two check-ins in different class types', async () => {
      const memberId = await getMemberByEmail('li.si.test.mt@example.com');
      const result1 = await checkIn(memberId, 'morning');
      const result2 = await checkIn(memberId, 'evening');
      expect(result1.is_extra).toBe(false);
      expect(result2.is_extra).toBe(false);
    });

    it('should mark third check-in as extra', async () => {
      const memberId = await getMemberByEmail('li.si.test.mt@example.com');
      await checkIn(memberId, 'morning');
      await checkIn(memberId, 'evening');
      const result = await checkIn(memberId, 'morning');
      expect(result.is_extra).toBe(true);
    });
  });
});