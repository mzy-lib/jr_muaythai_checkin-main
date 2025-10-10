import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { CheckIn, ClassType } from '../types/database';
import { PostgrestFilterBuilder } from '@supabase/postgrest-js';

interface FetchRecordsParams {
  memberName?: string;
  startDate?: string;
  endDate?: string;
  timeSlot?: string;
  classType?: string;
  isExtra?: boolean;
  is1v2?: boolean;
  trainerId?: string;
  page?: number;
  pageSize?: number;
  isPrivate?: boolean;
  courseType?: string;
  classTypes?: string[];
}

interface CheckInStats {
  total: number;
  regular: number;
  extra: number;
  oneOnOne: number;
  oneOnTwo: number;
  kidsGroup: number;
  normalGroup: number;
}

interface CheckInRecord {
  id: string;
  member_id: string;
  time_slot: string;
  is_extra: boolean;
  is_private: boolean;
  is_1v2: boolean;
  created_at: string;
  check_in_date: string;
  trainer_id: string | null;
  members: { name: string; email: string }[];
  trainer: { name: string }[];
  [key: string]: any; // 允许其他字段
}

export function useCheckInRecordsPaginated(initialPageSize: number = 10) {
  const [records, setRecords] = useState<CheckInRecord[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState<CheckInStats>({ 
    total: 0, 
    regular: 0, 
    extra: 0,
    oneOnOne: 0,
    oneOnTwo: 0,
    kidsGroup: 0,
    normalGroup: 0
  });

  // 创建基础查询构建函数，用于构建一致的查询条件
  const createBaseQuery = async (params: FetchRecordsParams) => {
    const { memberName, startDate, endDate, timeSlot, classType, isExtra, is1v2, trainerId, isPrivate, courseType, classTypes } = params;
    
    // 创建基础查询
    let query = supabase
      .from('check_ins')
      .select('*');
    
    // 如果有会员名称，先找到相应的会员ID
    let foundMemberIds: string[] = [];
    if (memberName) {
      const { data: membersData } = await supabase
        .from('members')
        .select('id')
        .or(`name.ilike.%${memberName}%,email.ilike.%${memberName}%`);
      
      if (membersData && membersData.length > 0) {
        foundMemberIds = membersData.map(m => m.id);
        query = query.in('member_id', foundMemberIds);
      } else {
        // 没有找到匹配的会员，返回空查询
        return { query, memberIds: [] as string[] };
      }
    }
    
    // 应用其他筛选条件
    if (startDate) {
      query = query.gte('check_in_date', startDate);
    }
    if (endDate) {
      query = query.lte('check_in_date', endDate);
    }
    if (timeSlot) {
      query = query.eq('time_slot', timeSlot);
    }
    if (classType) {
      query = query.eq('class_type', classType);
    }
    if (classTypes && classTypes.length > 0) {
      query = query.in('class_type', classTypes);
    }
    if (courseType) {
      console.warn('不推荐使用courseType参数，请使用classTypes参数进行枚举类型的匹配');
    }
    if (isExtra !== undefined) {
      query = query.eq('is_extra', isExtra);
    }
    if (isPrivate !== undefined) {
      query = query.eq('is_private', isPrivate);
    }
    if (is1v2 !== undefined) {
      query = query.eq('is_1v2', is1v2);
    }
    if (trainerId) {
      query = query.eq('trainer_id', trainerId);
    }
    
    return { query, memberIds: foundMemberIds };
  };

  const fetchStats = async (params: FetchRecordsParams) => {
    try {
      // 获取各类型的签到统计
      const getCountWithFilter = async (additionalFilters: Partial<FetchRecordsParams> = {}) => {
        // 合并基础参数和额外筛选条件
        const mergedParams = { ...params, ...additionalFilters };
        const { query } = await createBaseQuery(mergedParams);
        
        // 计数查询 - 使用更简单的方法来获取数量
        // 需要先调用select，然后获取结果的长度
        const { data, error } = await query;
        
        if (error) {
          console.error('获取计数错误:', error);
          return 0;
        }
        
        return data?.length || 0;
      };

      // 检查是否为儿童团课
      const isKidsGroupClass = (classType: any): boolean => {
        if (!classType) return false;
        
        if (typeof classType === 'string') {
          const typeStr = classType.toLowerCase();
          return typeStr === 'kids group' || typeStr.includes('kids') || typeStr.includes('儿童');
        }
        
        try {
          const typeStr = String(classType).toLowerCase();
          return typeStr === 'kids group' || typeStr.includes('kids') || typeStr.includes('儿童');
        } catch (e) {
          return false;
        }
      };

      // 获取所有签到记录以统计课程类型
      const getAllRecordsForClassTypeCount = async () => {
        const { query } = await createBaseQuery(params);
        const { data, error } = await query.select('class_type, is_private');
        
        if (error || !data) {
          console.error('获取课程类型统计错误:', error);
          return { kidsGroup: 0, normalGroup: 0 };
        }
        
        const kidsGroup = data.filter(record => 
          !record.is_private && isKidsGroupClass(record.class_type)
        ).length;
        
        const normalGroup = data.filter(record => 
          !record.is_private && !isKidsGroupClass(record.class_type)
        ).length;
        
        return { kidsGroup, normalGroup };
      };
      
      // 并行获取各种计数
      const [total, regular, extra, oneOnOne, oneOnTwo, groupCounts] = await Promise.all([
        getCountWithFilter(),
        getCountWithFilter({ isExtra: false }),
        getCountWithFilter({ isExtra: true }),
        getCountWithFilter({ isPrivate: true, is1v2: false }),
        getCountWithFilter({ isPrivate: true, is1v2: true }),
        getAllRecordsForClassTypeCount()
      ]);
      
      return {
        total,
        regular,
        extra,
        oneOnOne,
        oneOnTwo,
        kidsGroup: groupCounts.kidsGroup,
        normalGroup: groupCounts.normalGroup
      };
    } catch (error) {
      console.error('Error fetching stats:', error);
      return { 
        total: 0, 
        regular: 0, 
        extra: 0, 
        oneOnOne: 0,
        oneOnTwo: 0,
        kidsGroup: 0,
        normalGroup: 0
      };
    }
  };

  const fetchRecords = async ({
    memberName,
    startDate,
    endDate,
    timeSlot,
    classType,
    isExtra,
    is1v2,
    trainerId,
    page = 1,
    pageSize = initialPageSize,
    isPrivate,
    courseType,
    classTypes
  }: FetchRecordsParams) => {
    try {
      setLoading(true);
      setError(null);

      console.log('筛选条件:', {
        memberName,
        startDate,
        endDate,
        timeSlot,
        classType,
        isExtra,
        is1v2,
        trainerId,
        isPrivate,
        courseType,
        classTypes
      });
      
      // 使用共享的查询构建函数创建基础查询
      const { query, memberIds } = await createBaseQuery({
        memberName,
        startDate,
        endDate,
        timeSlot,
        classType,
        isExtra,
        is1v2,
        trainerId,
        isPrivate,
        courseType,
        classTypes
      });
      
      // 如果没有找到匹配的会员，且提供了会员名称，直接返回空结果
      if (memberName && memberIds.length === 0) {
        setRecords([]);
        setTotalCount(0);
        setCurrentPage(page);
        setTotalPages(0);
        setStats({ total: 0, regular: 0, extra: 0, oneOnOne: 0, oneOnTwo: 0, kidsGroup: 0, normalGroup: 0 });
        setLoading(false);
        return;
      }
      
      // 查询数据并计算总数
      const { data: checkInsData, error: checkInsError, count } = await query
        .select('id, member_id, time_slot, is_extra, is_private, is_1v2, created_at, check_in_date, trainer_id, class_type')
        .order('check_in_date', { ascending: false })
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1);
      
      if (checkInsError) {
        console.error('获取签到记录错误:', checkInsError);
        throw checkInsError;
      }
      
      console.log('签到记录数量:', checkInsData?.length);
      
      // 如果找不到记录，返回空数组
      if (!checkInsData || checkInsData.length === 0) {
        setRecords([]);
        setTotalCount(0);
        setCurrentPage(page);
        setTotalPages(0);
        
        // 也清空统计数据
        setStats({ total: 0, regular: 0, extra: 0, oneOnOne: 0, oneOnTwo: 0, kidsGroup: 0, normalGroup: 0 });
        setLoading(false);
        return;
      }
      
      // 获取会员数据
      const checkInMemberIds = checkInsData.map(record => record.member_id).filter(Boolean);
      const { data: membersData, error: membersError } = await supabase
        .from('members')
        .select('id, name, email')
        .in('id', checkInMemberIds);
        
      if (membersError) {
        console.error('获取会员数据错误:', membersError);
        throw membersError;
      }
      
      // 获取教练数据
      const trainerIds = checkInsData.map(record => record.trainer_id).filter(Boolean);
      const { data: trainersData, error: trainersError } = trainerIds.length > 0 ? 
        await supabase
          .from('trainers')
          .select('id, name')
          .in('id', trainerIds) : 
        { data: [], error: null };
        
      if (trainersError) {
        console.error('获取教练数据错误:', trainersError);
        throw trainersError;
      }
      
      // 创建查找映射
      const memberMap = new Map(membersData?.map(m => [m.id, m]) || []);
      const trainerMap = new Map(trainersData?.map(t => [t.id, t]) || []);
      
      // 处理数据，生成最终记录
      const processedRecords = checkInsData.map(checkIn => {
        const member = memberMap.get(checkIn.member_id);
        const trainer = trainerMap.get(checkIn.trainer_id);
        
        return {
          ...checkIn,
          members: member ? [{ name: member.name, email: member.email }] : [],
          trainer: trainer ? [{ name: trainer.name }] : []
        };
      });

      setRecords(processedRecords as CheckInRecord[]);
      setTotalCount(count || 0);
      setCurrentPage(page);
      setTotalPages(Math.ceil((count || 0) / pageSize));
      
      // 获取并更新统计数据，使用相同的参数以确保一致性
      const statsData = await fetchStats({
        memberName,
        startDate,
        endDate,
        timeSlot,
        classType,
        isExtra,
        is1v2,
        trainerId,
        isPrivate,
        courseType,
        classTypes
      });
      setStats(statsData);
      
    } catch (error) {
      console.error('Error fetching check-in records:', error);
      setError(error instanceof Error ? error.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return {
    records,
    totalCount,
    currentPage,
    totalPages,
    loading,
    error,
    fetchRecords,
    stats
  };
}