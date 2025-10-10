import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Trainer } from '../types/database';

/**
 * 获取教练列表的钩子
 * @returns 教练列表和加载状态
 */
export function useTrainers() {
  const [trainers, setTrainers] = useState<Trainer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchTrainers = async () => {
      try {
        setLoading(true);
        
        const { data, error: fetchError } = await supabase
          .from('trainers')
          .select('*');

        if (fetchError) throw fetchError;
        
        // 自定义排序顺序
        const trainerOrder = ['JR', 'Da', 'Ming', 'Big', 'Bas', 'Sumay', 'First'];
        
        // 对教练数据进行自定义排序
        const sortedTrainers = [...(data || [])].sort((a, b) => {
          // 获取教练在排序数组中的索引
          const indexA = trainerOrder.indexOf(a.name);
          const indexB = trainerOrder.indexOf(b.name);
          
          // 如果两个教练都在排序数组中，按照数组中的顺序排序
          if (indexA !== -1 && indexB !== -1) {
            return indexA - indexB;
          }
          
          // 如果只有一个教练在排序数组中，将其排在前面
          if (indexA !== -1) return -1;
          if (indexB !== -1) return 1;
          
          // 如果两个教练都不在排序数组中，按照名称字母顺序排序
          return a.name.localeCompare(b.name);
        });
        
        setTrainers(sortedTrainers);
      } catch (err) {
        console.error('获取教练列表失败:', err);
        setError('获取教练列表失败');
      } finally {
        setLoading(false);
      }
    };

    fetchTrainers();
  }, []);

  return { trainers, loading, error };
} 