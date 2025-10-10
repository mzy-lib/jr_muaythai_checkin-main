import React, { useEffect, useState } from 'react';
import { useCheckInRecords } from '../../hooks/useCheckInRecords';
import { useAuth } from '../../hooks/useAuth';
import { formatDateTime } from '../../utils/dateUtils';
import LoadingSpinner from '../common/LoadingSpinner';
import ErrorMessage from '../common/ErrorMessage';
import { supabase } from '../../lib/supabase';

interface Props {
  memberId: string;
  limit?: number;
}

// 扩展CheckIn类型以匹配后端返回的数据
interface ExtendedCheckIn {
  id: string;
  member_id: string;
  card_id: string | null;
  trainer_id: string | null;
  class_type: 'morning' | 'evening' | 'kids_group';
  check_in_time: string;
  check_in_date: string;
  is_extra: boolean;
  is_private: boolean;
  created_at: string | null;
  time_slot?: string;
  is_1v2?: boolean;
  members?: { name: string; email: string }[];
  trainer?: { name: string; type: string }[];
}

export default function CheckInRecords({ memberId, limit = 30 }: Props) {
  const { user } = useAuth();
  const { records: basicRecords, loading, error } = useCheckInRecords(memberId, limit);
  const [records, setRecords] = useState<ExtendedCheckIn[]>([]);
  const [extendedLoading, setExtendedLoading] = useState(true);

  // 获取完整的签到记录，包括额外字段
  useEffect(() => {
    const fetchExtendedRecords = async () => {
      if (!user || basicRecords.length === 0) {
        setRecords([]);
        setExtendedLoading(false);
        return;
      }

      try {
        setExtendedLoading(true);
        const { data, error: fetchError } = await supabase
          .from('check_ins')
          .select(`
            *,
            members (name, email),
            trainer:trainer_id (name, type)
          `)
          .eq('member_id', memberId)
          .order('created_at', { ascending: false })
          .limit(limit);

        if (fetchError) throw fetchError;
        setRecords(data as ExtendedCheckIn[] || []);
      } catch (err) {
        console.error('获取扩展签到记录失败:', err);
      } finally {
        setExtendedLoading(false);
      }
    };

    if (basicRecords.length > 0) {
      fetchExtendedRecords();
    } else {
      setExtendedLoading(false);
    }
  }, [basicRecords, memberId, user]);

  // Only show records for admin users
  if (!user) return null;
  if (loading || extendedLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} />;

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <h3 className="text-lg font-semibold mb-4">签到记录 Check-in Records</h3>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                日期 Date
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                上课时段 Time Slot
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                课程性质 Class Type
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                课程类型 Format
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                状态 Status
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {records.map((record) => (
              <tr key={record.id}>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {record.created_at 
                    ? formatDateTime(new Date(record.created_at)) 
                    : '-'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {record.time_slot || (
                    record.class_type === 'morning' ? '早课 9:00-10:30' : 
                    record.class_type === 'kids_group' ? '儿童团课 10:30-12:00' :
                    '晚课 17:00-18:30'
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <span
                    className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      record.is_private
                        ? 'bg-purple-100 text-purple-800'
                        : record.class_type === 'kids_group'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-blue-100 text-blue-800'
                    }`}
                  >
                    {record.is_private 
                      ? '私教课 Private' 
                      : record.class_type === 'kids_group'
                        ? '儿童团课 Kids' 
                        : '团课 Group'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {record.is_private ? (
                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      record.is_1v2
                        ? 'bg-yellow-100 text-yellow-800'
                        : 'bg-indigo-100 text-indigo-800'
                    }`}>
                      {record.is_1v2 ? '1对2' : '1对1'}
                    </span>
                  ) : '-'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {record.is_extra ? (
                    <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">额外签到 Extra</span>
                  ) : (
                    <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">正常 Regular</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {records.length === 0 && (
          <p className="text-center text-gray-500 py-4">
            暂无签到记录 No check-in records
          </p>
        )}
      </div>
    </div>
  );
}