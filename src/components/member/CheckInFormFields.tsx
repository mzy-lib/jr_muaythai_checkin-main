import React, { useEffect } from 'react';

interface Props {
  name: string;
  email: string;
  timeSlot: string;
  loading: boolean;
  isNewMember?: boolean;
  showTimeSlot?: boolean;
  courseType?: 'group' | 'private' | 'kids_group';
  onChange: (field: string, value: string) => void;
}

export default function CheckInFormFields({ 
  name, 
  email,
  timeSlot, 
  loading, 
  isNewMember,
  showTimeSlot = true,
  courseType = 'group',
  onChange 
}: Props) {
  // 团课固定时间段
  const groupTimeSlots = [
    { id: '09:00-10:30', label: '早课 Morning (09:00-10:30)' },
    { id: '17:00-18:30', label: '晚课 Evening (17:00-18:30)' }
  ];

  // 根据课程类型设置默认时段
  useEffect(() => {
    if (courseType === 'kids_group' && timeSlot !== '10:30-12:00') {
      // 儿童团课固定时段
      onChange('timeSlot', '10:30-12:00');
    }
  }, [courseType, timeSlot, onChange]);

  return (
    <>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          姓名 Name
        </label>
        <input
          type="text"
          value={name}
          onChange={(e) => onChange('name', e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-md"
          placeholder={isNewMember ? "请输入姓名 Enter your name" : "请输入会员姓名 Enter member name"}
          required
          disabled={loading}
          autoFocus
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          邮箱 Email
        </label>
        <input
          type="email"
          value={email}
          onChange={(e) => onChange('email', e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-md"
          placeholder="请输入邮箱 Enter email"
          required
          disabled={loading}
        />
      </div>

      {showTimeSlot && (
        <div>
          <label className="block text-sm font-medium">时间段 Time Slot</label>
          {courseType === 'kids_group' ? (
            // 儿童团课固定时段
            <div className="mt-1 p-2 bg-gray-100 rounded">
              10:30-12:00
            </div>
          ) : (
            // 原有的团课时段选择
            <select
              value={timeSlot}
              onChange={(e) => onChange('timeSlot', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              disabled={loading}
            >
              <option value="">请选择时间段...</option>
              <option value="9:00-10:30">早课 9:00-10:30</option>
              <option value="17:00-18:30">晚课 17:00-18:30</option>
            </select>
          )}
        </div>
      )}
    </>
  );
}