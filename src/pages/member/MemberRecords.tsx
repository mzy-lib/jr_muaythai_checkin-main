import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useMemberAuth } from '../../contexts/MemberAuthContext';
import { ClipboardCheck, AlertCircle, Clock, User, Calendar, ChevronDown } from 'lucide-react';

// 定义泰拳主题色
const MUAYTHAI_RED = '#D32F2F';
const MUAYTHAI_BLUE = '#1559CF';

interface CheckInRecord {
  id: string;                              // UUID 主键
  member_id: string;                       // 会员ID
  check_in_date: string;                   // 签到日期
  created_at?: string;                     // 创建时间
  is_extra: boolean;                       // 是否额外课时
  trainer_id?: string;                     // 教练ID
  is_1v2: boolean;                         // 是否1对2课程
  class_time: string;                      // 上课时间
  card_id?: string;                        // 会员卡ID
  is_private: boolean;                     // 是否私教课
  time_slot: string;                       // 时间段
  class_type?: string;                     // 课程类型
  trainer?: {                              // 关联的教练信息
    name: string;
    type: string;
  };
}

// 日期筛选类型
type DateFilterType = 'all' | 'today' | 'thisMonth' | 'custom';

const MemberRecords: React.FC = () => {
  const { member } = useMemberAuth();
  const [records, setRecords] = useState<CheckInRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // 日期筛选状态
  const [dateFilter, setDateFilter] = useState<DateFilterType>('all');
  const [startDate, setStartDate] = useState<string>('');
  const [endDate, setEndDate] = useState<string>('');
  const [showDatePicker, setShowDatePicker] = useState(false);

  // 获取今天的日期（YYYY-MM-DD格式）
  const getTodayDate = () => {
    const today = new Date();
    return today.toISOString().split('T')[0];
  };

  // 获取本月第一天的日期（YYYY-MM-DD格式）
  const getFirstDayOfMonth = () => {
    const today = new Date();
    return new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
  };

  // 获取本月最后一天的日期（YYYY-MM-DD格式）
  const getLastDayOfMonth = () => {
    const today = new Date();
    return new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0];
  };

  // 根据筛选类型获取日期范围
  const getDateRange = () => {
    switch (dateFilter) {
      case 'today':
        return { start: getTodayDate(), end: getTodayDate() };
      case 'thisMonth':
        return { start: getFirstDayOfMonth(), end: getLastDayOfMonth() };
      case 'custom':
        return { start: startDate, end: endDate };
      default:
        return { start: '', end: '' };
    }
  };

  useEffect(() => {
    if (!member?.id) return;
    fetchRecords();
  }, [member?.id, dateFilter, startDate, endDate]);

  async function fetchRecords() {
    try {
      if (!member) return;
      
      setLoading(true);
      
      // 获取日期范围
      const { start, end } = getDateRange();
      
      // 构建查询
      let query = supabase
        .from('check_ins')
        .select(`
          *,
          trainer:trainers!trainer_id(name, type)
        `)
        .eq('member_id', member.id)
        .order('check_in_date', { ascending: false });
      
      // 添加日期筛选条件
      if (start && end) {
        query = query.gte('check_in_date', start).lte('check_in_date', end);
      }
      
      const { data, error } = await query;

      if (error) throw error;
      setRecords(data || []);
    } catch (err) {
      console.error('Error fetching records:', err);
      setError('获取签到记录失败 Failed to fetch check-in records');
    } finally {
      setLoading(false);
    }
  }

  const handleDateFilterChange = (type: DateFilterType) => {
    setDateFilter(type);
    if (type === 'custom') {
      setShowDatePicker(true);
    } else {
      setShowDatePicker(false);
    }
  };

  const handleCustomDateSubmit = () => {
    if (startDate && endDate) {
      setShowDatePicker(false);
    }
  };

  const subscription = supabase
    .channel('check_ins_changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'check_ins',
        filter: `member_id=eq.${member?.id}`
      },
      fetchRecords
    )
    .subscribe();

  useEffect(() => {
    return () => {
      subscription.unsubscribe();
    };
  }, []);

  if (loading) {
    return <div className="p-4">加载中... Loading...</div>;
  }

  if (error) {
    return <div className="p-4 text-red-600">{error}</div>;
  }

  if (records.length === 0) {
    return (
      <div className="max-w-4xl mx-auto p-4">
        <h2 className="text-2xl font-bold mb-6 border-b-2 border-[#1559CF] pb-2 inline-block">签到记录 Check-in Records</h2>
        <div className="bg-white rounded-lg shadow p-6 text-center text-gray-500">
          <AlertCircle className="w-12 h-12 mx-auto mb-4 text-[#1559CF]" />
          <p>暂无签到记录</p>
          <p>No check-in records found</p>
        </div>
      </div>
    );
  }

  const getClassTypeTranslation = (isPrivate: boolean, classType?: string) => {
    if (isPrivate) {
      return '私教课 Private Class';
    } else if (classType === 'kids group') {
      return '儿童团课 Kids Group Class';
    } else {
      return '团课 Group Class';
    }
  };

  const getExtraCheckInText = () => {
    return '额外课时 Extra Check-in';
  };

  // 格式化日期显示
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    if (date.toDateString() === today.toDateString()) {
      return '今天 Today';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return '昨天 Yesterday';
    } else {
      return date.toLocaleDateString();
    }
  };

  // 获取当前筛选器显示文本
  const getFilterDisplayText = () => {
    switch (dateFilter) {
      case 'today':
        return '今天 Today';
      case 'thisMonth':
        return '本月 This Month';
      case 'custom':
        return `${startDate} - ${endDate}`;
      default:
        return '全部记录 All Records';
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-4">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold border-b-2 border-[#1559CF] pb-2 inline-block">签到记录 Check-in Records</h2>
        
        {/* 日期筛选器 */}
        <div className="relative">
          <div 
            className="flex items-center space-x-2 bg-white px-4 py-2 rounded-lg shadow cursor-pointer"
            onClick={() => setShowDatePicker(!showDatePicker)}
          >
            <Calendar className="w-5 h-5 text-[#1559CF]" />
            <span>{getFilterDisplayText()}</span>
            <ChevronDown className="w-4 h-4" />
          </div>
          
          {/* 筛选选项下拉菜单 */}
          {showDatePicker && (
            <div className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg z-10 p-3">
              <div className="space-y-2">
                <div 
                  className={`p-2 rounded cursor-pointer ${dateFilter === 'all' ? 'bg-blue-50 text-[#1559CF]' : 'hover:bg-gray-100'}`}
                  onClick={() => handleDateFilterChange('all')}
                >
                  全部记录 All Records
                </div>
                <div 
                  className={`p-2 rounded cursor-pointer ${dateFilter === 'today' ? 'bg-blue-50 text-[#1559CF]' : 'hover:bg-gray-100'}`}
                  onClick={() => handleDateFilterChange('today')}
                >
                  今天 Today
                </div>
                <div 
                  className={`p-2 rounded cursor-pointer ${dateFilter === 'thisMonth' ? 'bg-blue-50 text-[#1559CF]' : 'hover:bg-gray-100'}`}
                  onClick={() => handleDateFilterChange('thisMonth')}
                >
                  本月 This Month
                </div>
                <div 
                  className={`p-2 rounded cursor-pointer ${dateFilter === 'custom' ? 'bg-blue-50 text-[#1559CF]' : 'hover:bg-gray-100'}`}
                  onClick={() => handleDateFilterChange('custom')}
                >
                  自定义日期 Custom Date
                </div>
                
                {/* 自定义日期选择器 */}
                {dateFilter === 'custom' && (
                  <div className="mt-2 space-y-2">
                    <div className="flex flex-col">
                      <label className="text-sm text-gray-600 mb-1">开始日期 Start Date</label>
                      <input 
                        type="date" 
                        value={startDate}
                        onChange={(e) => setStartDate(e.target.value)}
                        className="border rounded p-1"
                      />
                    </div>
                    <div className="flex flex-col">
                      <label className="text-sm text-gray-600 mb-1">结束日期 End Date</label>
                      <input 
                        type="date" 
                        value={endDate}
                        onChange={(e) => setEndDate(e.target.value)}
                        className="border rounded p-1"
                      />
                    </div>
                    <button 
                      onClick={handleCustomDateSubmit}
                      className="w-full bg-[#1559CF] text-white py-1 rounded mt-2"
                      disabled={!startDate || !endDate}
                    >
                      应用 Apply
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
      
      <div className="space-y-4">
        {records.map(record => (
          <div key={record.id} className="bg-white rounded-lg shadow overflow-hidden">
            <div className={`p-4 ${record.is_private ? 'bg-blue-50' : 'bg-blue-50'} border-l-4 ${record.is_private ? `border-[${MUAYTHAI_BLUE}]` : `border-[${MUAYTHAI_BLUE}]`}`}>
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <ClipboardCheck className={`w-6 h-6 ${record.is_private ? `text-[${MUAYTHAI_BLUE}]` : `text-[${MUAYTHAI_BLUE}]`}`} />
                  <div>
                    <span className="font-medium">
                      {getClassTypeTranslation(record.is_private, record.class_type)}
                    </span>
                    {record.class_type && record.class_type !== 'private' && record.class_type !== 'kids group' && (
                      <span className="ml-2 text-gray-500">({record.class_type})</span>
                    )}
                    {record.is_extra && (
                      <span className="ml-2 text-orange-500 text-xs px-2 py-0.5 bg-orange-100 rounded-full">
                        {getExtraCheckInText()}
                      </span>
                    )}
                  </div>
                </div>
                <div className="text-sm text-gray-500 font-medium">
                  {formatDate(record.check_in_date)}
                </div>
              </div>
            </div>
            
            <div className="p-4 space-y-3">
              <div className="flex items-center space-x-2 text-gray-600">
                <Clock className="w-4 h-4 text-gray-500" />
                <span className="text-sm">上课时段 Time Slot: {record.time_slot}</span>
              </div>

              {record.trainer && (
                <div className="flex items-center space-x-2 text-gray-600">
                  <User className="w-4 h-4 text-gray-500" />
                  <span className="text-sm">
                    教练 Trainer: {record.trainer.name} ({record.trainer.type === 'senior' ? '高级教练 Senior' : 'JR教练 Junior'})
                    {record.is_1v2 && (
                      <span className="ml-2 text-xs px-2 py-0.5 bg-purple-100 text-purple-800 rounded-full">
                        1对2课程 1-on-2 Class
                      </span>
                    )}
                  </span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default MemberRecords; 