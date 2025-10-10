import React from 'react';
import { CheckIn } from '../../types/database';
import { formatDateTime } from '../../utils/dateUtils';

interface Props {
  checkIns: CheckIn[];
}

export default function CheckInHistory({ checkIns }: Props) {
  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold mb-4">签到记录 Check-in History</h2>
      <div className="space-y-4">
        {checkIns.map((checkIn) => (
          <div
            key={checkIn.id}
            className="flex justify-between items-center border-b pb-2"
          >
            <div>
              <div className="font-medium">
                {checkIn.class_type === 'morning' ? '早课 Morning' : '晚课 Evening'}
              </div>
              <div className="text-sm text-gray-500">
                {formatDateTime(new Date(checkIn.created_at))}
              </div>
            </div>
            {checkIn.is_extra && (
              <span className="text-muaythai-red text-sm">额外签到 Extra</span>
            )}
          </div>
        ))}
        {checkIns.length === 0 && (
          <p className="text-gray-500 text-center">暂无签到记录 No check-ins yet</p>
        )}
      </div>
    </div>
  );
}