import React from 'react';
import { useExpiringMembers } from '../../../hooks/useExpiringMembers';
import LoadingSpinner from '../../common/LoadingSpinner';
import ErrorMessage from '../../common/ErrorMessage';

interface ExpiringMember {
  id: string;
  name: string;
  card_id: string;
  card_type: string;
  valid_until: string;
  remaining_sessions?: number;
}

const ExpiringMembersList: React.FC = () => {
  const { members, loading, error } = useExpiringMembers();

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error.message} />;

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h3 className="text-lg font-semibold mb-4">即将到期会员 Expiring Memberships</h3>
      {members.length === 0 ? (
        <p className="text-gray-500">暂无即将到期的会员</p>
      ) : (
        <div className="space-y-4">
          {members.map((member: ExpiringMember) => (
            <div key={member.card_id} className="flex justify-between items-center">
              <div>
                <p className="font-medium">{member.name}</p>
                <p className="text-sm text-gray-500">{member.card_type}</p>
                {member.remaining_sessions !== undefined && (
                  <p className="text-xs text-gray-500">剩余课时: {member.remaining_sessions}</p>
                )}
              </div>
              <div className="text-right">
                <p className="text-sm text-red-600">
                  到期日期: {new Date(member.valid_until).toLocaleDateString()}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ExpiringMembersList;