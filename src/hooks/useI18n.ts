import { useState } from 'react';
import { messages } from '../i18n';

type Language = 'zh' | 'en';

export function useI18n() {
  const [language, setLanguage] = useState<Language>('zh');

  const t = (key: string) => {
    const keys = key.split('.');
    let value = messages[language];
    
    for (const k of keys) {
      if (value && typeof value === 'object') {
        value = value[k];
      } else {
        return key;
      }
    }
    
    return value || key;
  };

  return {
    language,
    setLanguage,
    t
  };
}