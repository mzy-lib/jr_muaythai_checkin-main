import { Member, CheckIn } from '../../types/database';

/**
 * Generic cache manager with TTL support
 */
class CacheManager<T> {
  private cache = new Map<string, { data: T; timestamp: number }>();
  private ttl: number;

  constructor(ttlMinutes: number = 5) {
    this.ttl = ttlMinutes * 60 * 1000;
  }

  set(key: string, data: T): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now()
    });
  }

  get(key: string): T | null {
    const item = this.cache.get(key);
    if (!item) return null;

    if (Date.now() - item.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }

    return item.data;
  }

  clear(): void {
    this.cache.clear();
  }
}

// Create typed cache instances
export const memberCache = new CacheManager<Member>(5); // 5 minutes TTL
export const checkInCache = new CacheManager<CheckIn[]>(1); // 1 minute TTL