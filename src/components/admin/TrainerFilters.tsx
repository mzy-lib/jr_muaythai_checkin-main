import React from 'react';
import { Search } from 'lucide-react';

interface Props {
  dateRange: {
    start: Date | null;
    end: Date | null;
  };
  searchTerm: string;
  onDateRangeChange: (range: { start: Date | null; end: Date | null }) => void;
  onSearchChange: (term: string) => void;
  onQuickDateSelect: (period: 'today' | 'week' | 'month') => void;
}

export default function TrainerFilters({
  dateRange,
  searchTerm,
  onDateRangeChange,
  onSearchChange,
  onQuickDateSelect
}: Props) {
  return (
    <div className="bg-white p-4 rounded-lg shadow-sm mb-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* 日期范围选择 */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            时间范围 Date Range
          </label>
          <div className="flex items-center gap-2">
            <button
              onClick={() => onQuickDateSelect('today')}
              className="px-3 py-1 text-sm rounded-full border hover:bg-gray-50"
            >
              今日 Today
            </button>
            <button
              onClick={() => onQuickDateSelect('week')}
              className="px-3 py-1 text-sm rounded-full border hover:bg-gray-50"
            >
              本周 Week
            </button>
            <button
              onClick={() => onQuickDateSelect('month')}
              className="px-3 py-1 text-sm rounded-full border hover:bg-gray-50"
            >
              本月 Month
            </button>
          </div>
          <div className="flex items-center gap-2">
            <input
              type="date"
              value={dateRange.start ? dateRange.start.toISOString().split('T')[0] : ''}
              onChange={(e) => onDateRangeChange({
                start: e.target.value ? new Date(e.target.value) : null,
                end: dateRange.end
              })}
              className="px-3 py-1 border rounded-lg text-sm"
            />
            <span className="text-gray-500">至</span>
            <input
              type="date"
              value={dateRange.end ? dateRange.end.toISOString().split('T')[0] : ''}
              onChange={(e) => onDateRangeChange({
                start: dateRange.start,
                end: e.target.value ? new Date(e.target.value) : null
              })}
              className="px-3 py-1 border rounded-lg text-sm"
            />
          </div>
        </div>

        {/* 教练搜索 */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            搜索教练 Search Trainer
          </label>
          <div className="relative">
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => onSearchChange(e.target.value)}
              placeholder="输入教练姓名..."
              className="w-full pl-10 pr-3 py-2 border rounded-lg text-sm"
            />
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-gray-400" />
          </div>
        </div>
      </div>
    </div>
  );
} 