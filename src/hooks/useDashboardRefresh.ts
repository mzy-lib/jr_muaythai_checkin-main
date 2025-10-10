import { useState, useEffect, useCallback } from 'react';

interface RefreshConfig {
  interval?: number;
  enabled?: boolean;
}

export function useDashboardRefresh(config: RefreshConfig = {}) {
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());
  const [autoRefresh, setAutoRefresh] = useState(config.enabled ?? false);

  const refresh = useCallback(() => {
    setLastUpdate(new Date());
  }, []);

  const toggleAutoRefresh = useCallback(() => {
    setAutoRefresh(prev => !prev);
  }, []);

  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      refresh();
    }, config.interval || 15 * 60 * 1000);

    return () => clearInterval(interval);
  }, [autoRefresh, config.interval, refresh]);

  return {
    lastUpdate,
    autoRefresh,
    refresh,
    toggleAutoRefresh
  };
}