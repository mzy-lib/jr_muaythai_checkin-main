import React from 'react';
import { ClassSchedule as Schedule } from '../../types/database';

interface Props {
  schedule: Schedule[];
}

export default function ClassSchedule({ schedule }: Props) {
  const days = ['周一', 'Tuesday', '周二', 'Wednesday', '周三', 'Thursday', '周四', 'Friday', '周五', 'Saturday', '周六'];

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold mb-4">课程表 Class Schedule</h2>
      <div className="grid gap-4">
        {days.map((day, index) => {
          const daySchedule = schedule.filter(s => s.day_of_week === index + 1);
          return (
            <div key={day} className="border-b pb-2">
              <h3 className="font-medium mb-2">{day}</h3>
              <div className="space-y-2 pl-4">
                {daySchedule.map(s => (
                  <div key={s.id} className="flex justify-between text-sm">
                    <span>
                      {s.class_type === 'morning' ? '早课 Morning' : '晚课 Evening'}
                    </span>
                    <span className="text-gray-600">
                      {s.start_time.slice(0, 5)} - {s.end_time.slice(0, 5)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}