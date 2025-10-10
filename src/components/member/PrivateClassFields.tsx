import React from 'react';
import { useTrainers } from '../../hooks/useTrainers';
import LoadingSpinner from '../common/LoadingSpinner';

interface Props {
  trainerId: string;
  timeSlot: string;
  is1v2: boolean;
  loading: boolean;
  onChange: (field: string, value: string | boolean) => void;
}

export default function PrivateClassFields({
  trainerId,
  timeSlot,
  is1v2,
  loading,
  onChange
}: Props) {
  // 使用钩子获取教练列表
  const { trainers, loading: trainersLoading, error: trainersError } = useTrainers();

  // 私教课时间段
  const timeSlots = [
    // 早课
    { id: '07:00-08:00', label: '07:00-08:00' },
    { id: '08:00-09:00', label: '08:00-09:00' },
    { id: '10:30-11:30', label: '10:30-11:30' },
    // 下午
    { id: '14:00-15:00', label: '14:00-15:00' },
    { id: '15:00-16:00', label: '15:00-16:00' },
    { id: '16:00-17:00', label: '16:00-17:00' },
    // 晚课
    { id: '18:30-19:30', label: '18:30-19:30' }
  ];

  return (
    <div className="space-y-4">
      {/* 教练选择 */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          教练 Trainer
        </label>
        <select
          value={trainerId}
          onChange={(e) => onChange('trainerId', e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-md"
          required
          disabled={loading || trainersLoading}
        >
          <option value="">请选择教练 Select trainer</option>
          {trainersLoading ? (
            <option value="" disabled>加载中... Loading...</option>
          ) : trainersError ? (
            <option value="" disabled>加载失败 Error loading trainers</option>
          ) : (
            trainers.map(trainer => (
              <option key={trainer.id} value={trainer.id}>
                {trainer.name} ({trainer.type === 'senior' ? '高级教练 Senior Trainer' : 'JR教练'})
              </option>
            ))
          )}
        </select>
        {trainersLoading && <div className="mt-1"><LoadingSpinner size="sm" /></div>}
      </div>

      {/* 时段选择 */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          时段 Time Slot
        </label>
        <select
          value={timeSlot}
          onChange={(e) => onChange('timeSlot', e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-md"
          required
          disabled={loading}
        >
          <option value="">请选择时段 Select time slot</option>
          {timeSlots.map(slot => (
            <option key={slot.id} value={slot.id}>
              {slot.label}
            </option>
          ))}
        </select>
      </div>

      {/* 1对1/1对2选择 */}
      <div>
        <label className="flex items-center space-x-2 cursor-pointer">
          <input
            type="checkbox"
            checked={is1v2}
            onChange={(e) => onChange('is1v2', e.target.checked)}
            className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            disabled={loading}
          />
          <span className="text-sm text-gray-700">
            1对2课程 1-on-2 Class
          </span>
        </label>
      </div>
    </div>
  );
} 