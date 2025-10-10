import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { startOfToday, startOfWeek, startOfMonth, endOfToday, endOfWeek, endOfMonth, format } from 'date-fns';
import TrainerFilters from './TrainerFilters';
import LoadingSpinner from '../common/LoadingSpinner';
import ErrorMessage from '../common/ErrorMessage';
import { Trainer } from '../../types/database';

type TrainerWithStats = Trainer & {
  stats: {
    totalPrivateClasses: number;
    oneOnOneClasses: number;
    oneOnTwoClasses: number;
    groupClasses: number;
  };
};

interface EditingField {
  trainerId: string;
  field: 'name' | 'type' | 'totalPrivateClasses' | 'oneOnOneClasses' | 'oneOnTwoClasses' | 'groupClasses' | 'notes';
  value: string;
}

export default function TrainerList() {
  const [trainers, setTrainers] = useState<TrainerWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editingField, setEditingField] = useState<EditingField | null>(null);
  
  // 筛选状态
  const [dateRange, setDateRange] = useState<{
    start: Date | null;
    end: Date | null;
  }>({
    start: startOfMonth(new Date()),
    end: endOfToday()
  });
  const [searchTerm, setSearchTerm] = useState('');

  // 获取教练列表和统计数据
  const fetchTrainers = async () => {
    try {
      setLoading(true);
      
      // 1. 获取所有教练
      const { data: trainersData, error: trainersError } = await supabase
        .from('trainers')
        .select('*')
        .ilike('name', `%${searchTerm}%`);

      if (trainersError) throw trainersError;

      // 2. 获取课时统计
      const statsPromises = trainersData.map(async (trainer) => {
        // 获取1对1课时
        const { count: oneOnOneCount } = await supabase
          .from('check_ins')
          .select('*', { count: 'exact' })
          .eq('trainer_id', trainer.id)
          .eq('is_private', true)
          .eq('is_1v2', false)
          .gte('check_in_date', format(dateRange.start!, 'yyyy-MM-dd'))
          .lte('check_in_date', format(dateRange.end!, 'yyyy-MM-dd'));

        // 获取1对2课时
        const { count: oneOnTwoCount } = await supabase
          .from('check_ins')
          .select('*', { count: 'exact' })
          .eq('trainer_id', trainer.id)
          .eq('is_private', true)
          .eq('is_1v2', true)
          .gte('check_in_date', format(dateRange.start!, 'yyyy-MM-dd'))
          .lte('check_in_date', format(dateRange.end!, 'yyyy-MM-dd'));

        return {
          ...trainer,
          stats: {
            totalPrivateClasses: (oneOnOneCount || 0) + (oneOnTwoCount || 0),
            oneOnOneClasses: oneOnOneCount || 0,
            oneOnTwoClasses: oneOnTwoCount || 0,
            groupClasses: 0 // 暂时保持为0
          }
        };
      });

      const trainersWithStats = await Promise.all(statsPromises);
      setTrainers(trainersWithStats);
    } catch (err) {
      console.error('Error fetching trainers:', err);
      setError('获取教练数据失败 Failed to fetch trainer data');
    } finally {
      setLoading(false);
    }
  };

  // 监听筛选条件变化
  useEffect(() => {
    fetchTrainers();
  }, [dateRange, searchTerm]);

  // 更新教练信息
  const handleUpdate = async (trainerId: string, field: string, value: string) => {
    try {
      const updates: any = { [field]: value };
      
      const { error: updateError } = await supabase
        .from('trainers')
        .update(updates)
        .eq('id', trainerId);

      if (updateError) throw updateError;

      // 更新本地状态
      setTrainers(trainers.map(trainer => 
        trainer.id === trainerId 
          ? { ...trainer, [field]: value }
          : trainer
      ));
      setEditingField(null);
    } catch (err) {
      console.error('Error updating trainer:', err);
      setError('更新失败 Update failed');
    }
  };

  // 开始编辑
  const startEditing = (trainer: TrainerWithStats, field: EditingField['field']) => {
    setEditingField({
      trainerId: trainer.id,
      field,
      value: trainer[field]?.toString() || ''
    });
  };

  // 渲染可编辑单元格
  const renderEditableCell = (trainer: TrainerWithStats, field: EditingField['field'], displayValue: string | React.ReactNode) => {
    const isEditing = editingField?.trainerId === trainer.id && editingField?.field === field;

    if (isEditing) {
      if (field === 'type') {
        return (
          <div className="flex items-center space-x-2">
            <select
              value={editingField.value}
              onChange={(e) => setEditingField({ ...editingField, value: e.target.value })}
              className="border rounded px-2 py-1 text-sm"
              autoFocus
            >
              <option value="jr">JR教练</option>
              <option value="senior">高级教练</option>
            </select>
            <button
              onClick={() => handleUpdate(trainer.id, field, editingField.value)}
              className="text-green-600 hover:text-green-800"
            >
              ✓
            </button>
            <button
              onClick={() => setEditingField(null)}
              className="text-red-600 hover:text-red-800"
            >
              ✕
            </button>
          </div>
        );
      }

      return (
        <div className="flex items-center space-x-2">
          <input
            type="text"
            value={editingField.value}
            onChange={(e) => setEditingField({ ...editingField, value: e.target.value })}
            className="border rounded px-2 py-1 text-sm w-full"
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                handleUpdate(trainer.id, field, editingField.value);
              } else if (e.key === 'Escape') {
                setEditingField(null);
              }
            }}
            autoFocus
          />
          <button
            onClick={() => handleUpdate(trainer.id, field, editingField.value)}
            className="text-green-600 hover:text-green-800"
          >
            ✓
          </button>
          <button
            onClick={() => setEditingField(null)}
            className="text-red-600 hover:text-red-800"
          >
            ✕
          </button>
        </div>
      );
    }

    if (field === 'type') {
      return (
        <div
          className="cursor-pointer hover:bg-gray-100 px-2 py-1 rounded"
          onClick={() => startEditing(trainer, field)}
        >
          <span className={`px-2 py-1 rounded-full text-xs ${
            trainer.type === 'senior' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'
          }`}>
            {trainer.type === 'senior' ? '高级教练' : 'JR教练'}
          </span>
        </div>
      );
    }

    return (
      <div
        className="cursor-pointer hover:bg-gray-100 px-2 py-1 rounded"
        onClick={() => startEditing(trainer, field)}
      >
        {displayValue}
      </div>
    );
  };

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} />;

  return (
    <div className="space-y-6">
      <TrainerFilters
        dateRange={dateRange}
        searchTerm={searchTerm}
        onDateRangeChange={setDateRange}
        onSearchChange={setSearchTerm}
        onQuickDateSelect={(period) => {
          const today = new Date();
          switch (period) {
            case 'today':
              setDateRange({
                start: startOfToday(),
                end: endOfToday()
              });
              break;
            case 'week':
              setDateRange({
                start: startOfWeek(today, { weekStartsOn: 1 }),
                end: endOfWeek(today, { weekStartsOn: 1 })
              });
              break;
            case 'month':
              setDateRange({
                start: startOfMonth(today),
                end: endOfToday()
              });
              break;
          }
        }}
      />

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                教练姓名 Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                等级 Level
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                总私教课时 Total Private
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                1对1课时
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                1对2课时
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                团课课时 Group
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                备注 Notes
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {trainers.map((trainer) => (
              <tr key={trainer.id}>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {renderEditableCell(trainer, 'name', trainer.name)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {renderEditableCell(trainer, 'type', trainer.type)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {trainer.stats.totalPrivateClasses}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {trainer.stats.oneOnOneClasses}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {trainer.stats.oneOnTwoClasses}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {trainer.stats.groupClasses}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {renderEditableCell(trainer, 'notes', trainer.notes || '-')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
} 