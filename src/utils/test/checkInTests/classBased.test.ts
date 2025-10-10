import { describe, it, expect } from 'vitest';
import { getMemberByEmail, checkIn } from '../helpers/checkInHelpers';

describe('Class-based Membership Check-in Tests', () => {
  describe('Ten Classes Package', () => {
    it('should deduct one class and allow check-in with remaining classes', async () => {
      const memberId = await getMemberByEmail('zhao.liu.test.mt@example.com');
      const result = await checkIn(memberId, 'morning');
      expect(result.is_extra).toBe(false);
    });
  });

  describe('No Remaining Classes', () => {
    it('should mark check-in as extra when no classes remain', async () => {
      const memberId = await getMemberByEmail('zhou.ba.test.mt@example.com');
      const result = await checkIn(memberId, 'morning');
      expect(result.is_extra).toBe(true);
    });
  });
});