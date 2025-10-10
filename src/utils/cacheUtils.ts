interface CacheItem<T> {
  data: T;
  timestamp: number;
}

interface CacheConfig {
  ttl: number; // Time to live in milliseconds
}

export class QueryCache<T> {
  private cache: Map<string, CacheItem<T>>;
  private config: CacheConfig;

  constructor(config: CacheConfig = { ttl: 5 * 60 * 1000 }) { // Default 5 minutes TTL
    this.cache = new Map();
    this.config = config;
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

    if (Date.now() - item.timestamp > this.config.ttl) {
      this.cache.delete(key);
      return null;
    }

    return item.data;
  }

  clear(): void {
    this.cache.clear();
  }
}

// Create hash key for cache
export function createCacheKey(prefix: string, params: Record<string, any>): string {
  const sortedParams = Object.keys(params)
    .sort()
    .reduce((acc, key) => {
      if (params[key] !== undefined && params[key] !== null) {
        acc[key] = params[key];
      }
      return acc;
    }, {} as Record<string, any>);

  return `${prefix}:${JSON.stringify(sortedParams)}`;
}