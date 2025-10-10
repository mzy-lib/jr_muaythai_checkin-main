import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { 
  startOfMonth, endOfMonth, 
  subMonths, 
  startOfQuarter, endOfQuarter,
  startOfYear, endOfYear 
} from 'date-fns';

interface TrainerStat {
  trainerId: string;
  trainerName: string;
  sessionCount: number;
  oneOnOneCount: number;
  oneOnTwoCount: number;
}

export type TimeRange = 'thisMonth' | 'lastMonth' | 'last3Months' | 'thisQuarter' | 'thisYear';

export const useTrainerWorkload = (timeRange: TimeRange = 'thisMonth') => {
  const [trainerStats, setTrainerStats] = useState<TrainerStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchTrainerWorkload = async () => {
      try {
        setLoading(true);
        
        // 根据选择的时间范围获取开始和结束日期
        const now = new Date();
        let startDate: Date;
        let endDate: Date;
        
        switch(timeRange) {
          case 'thisMonth':
            startDate = startOfMonth(now);
            endDate = endOfMonth(now);
            break;
          case 'lastMonth':
            const lastMonth = subMonths(now, 1);
            startDate = startOfMonth(lastMonth);
            endDate = endOfMonth(lastMonth);
            break;
          case 'last3Months':
            startDate = startOfMonth(subMonths(now, 2));
            endDate = endOfMonth(now);
            break;
          case 'thisQuarter':
            startDate = startOfQuarter(now);
            endDate = endOfQuarter(now);
            break;
          case 'thisYear':
            startDate = startOfYear(now);
            endDate = endOfYear(now);
            break;
          default:
            startDate = startOfMonth(now);
            endDate = endOfMonth(now);
        }

        // 获取所有教练信息
        const { data: trainers, error: trainersError } = await supabase
          .from('trainers')
          .select('id, name');
        
        if (trainersError) throw trainersError;
        
        // 获取指定时间范围内的私教签到记录
        const { data: checkIns, error: checkInsError } = await supabase
          .from('check_ins')
          .select('*')
          .eq('is_private', true)
          .gte('check_in_date', startDate.toISOString())
          .lte('check_in_date', endDate.toISOString());
        
        if (checkInsError) throw checkInsError;
        
        // 处理数据统计
        const stats: TrainerStat[] = trainers?.map(trainer => {
          const trainerCheckIns = checkIns?.filter(
            checkIn => checkIn.trainer_id === trainer.id
          ) || [];
          
          return {
            trainerId: trainer.id,
            trainerName: trainer.name,
            sessionCount: trainerCheckIns.length,
            oneOnOneCount: trainerCheckIns.filter(checkIn => !checkIn.is_1v2).length,
            oneOnTwoCount: trainerCheckIns.filter(checkIn => checkIn.is_1v2).length,
          };
        }) || [];
        
        // 按课时数量排序
        const sortedStats = stats.sort((a, b) => b.sessionCount - a.sessionCount);
        
        setTrainerStats(sortedStats);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchTrainerWorkload();
  }, [timeRange]);

  return { trainerStats, loading, error };
}; 