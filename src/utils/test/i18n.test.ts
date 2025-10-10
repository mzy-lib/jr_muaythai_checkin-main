import { describe, it, expect } from 'vitest';
import { useI18n } from '../../hooks/useI18n';
import { renderHook, act } from '@testing-library/react';

describe('useI18n', () => {
  it('defaults to Chinese language', () => {
    const { result } = renderHook(() => useI18n());
    expect(result.current.language).toBe('zh');
  });

  it('can switch language', () => {
    const { result } = renderHook(() => useI18n());
    
    act(() => {
      result.current.setLanguage('en');
    });
    
    expect(result.current.language).toBe('en');
  });

  it('translates keys correctly', () => {
    const { result } = renderHook(() => useI18n());
    
    expect(result.current.t('checkIn.success')).toBe('签到成功！祝您训练愉快！');
    
    act(() => {
      result.current.setLanguage('en');
    });
    
    expect(result.current.t('checkIn.success')).toBe('Check-in successful! Enjoy your training!');
  });

  it('returns key if translation not found', () => {
    const { result } = renderHook(() => useI18n());
    expect(result.current.t('nonexistent.key')).toBe('nonexistent.key');
  });
});