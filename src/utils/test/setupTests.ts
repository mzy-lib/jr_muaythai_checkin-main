import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeAll, vi } from 'vitest';
import { supabase } from '../../lib/supabase';

// 在所有测试开始前初始化 Supabase
beforeAll(async () => {
  if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
    console.warn('Missing Supabase environment variables in test environment');
    return;
  }

  try {
    // 使用测试用户登录
    const { error } = await supabase.auth.signInWithPassword({
      email: 'test@example.com',
      password: 'test-password'
    });

    if (error) {
      // 如果登录失败，尝试创建测试用户
      const { error: signUpError } = await supabase.auth.signUp({
        email: 'test@example.com',
        password: 'test-password'
      });

      if (signUpError) {
        console.warn('无法创建测试用户:', signUpError.message);
      }
    }
  } catch (error) {
    console.warn('Supabase 测试环境初始化失败:', error);
  }
});

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Mock IntersectionObserver
class IntersectionObserver {
  observe = vi.fn();
  disconnect = vi.fn();
  unobserve = vi.fn();
}

Object.defineProperty(window, 'IntersectionObserver', {
  writable: true,
  configurable: true,
  value: IntersectionObserver,
});

// Mock ResizeObserver
class ResizeObserver {
  observe = vi.fn();
  disconnect = vi.fn();
  unobserve = vi.fn();
}

Object.defineProperty(window, 'ResizeObserver', {
  writable: true,
  configurable: true,
  value: ResizeObserver,
});

// Cleanup after each test
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});