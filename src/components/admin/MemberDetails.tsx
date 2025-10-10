import React from 'react';
import { Member, MembershipCard } from '../../types/database';
import { formatDate } from '../../utils/formatters';
import { getFullCardName } from '../../utils/membership/formatters';
import { useCheckInRecords } from '../../hooks/useCheckInRecords';
import LoadingSpinner from '../common/LoadingSpinner';
import ErrorMessage from '../common/ErrorMessage';

interface Props {
  member: Member & { membership_cards?: MembershipCard[] };
}

export default function MemberDetails({ member }: Props) {
  const { records, loading, error } = useCheckInRecords(member.id, 50);

  const getCardDetails = (card: MembershipCard) => {
    const cardName = getFullCardName(card.card_type, card.card_category, card.card_subtype);

    const remaining = card.card_type === '私教课' 
      ? card.remaining_private_sessions 
      : card.remaining_group_sessions;

    return (
      <div key={card.id} className="border-b border-gray-200 py-4 last:border-0">
        <div className="flex justify-between items-center">
          <div>
            <h4 className="font-medium text-gray-900">{cardName}</h4>
            {card.valid_until && (
              <p className="text-sm text-gray-500">
                到期日期: {formatDate(card.valid_until)}
              </p>
            )}
          </div>
          {remaining !== null && (
            <div className="text-right">
              <p className="text-sm text-gray-500">剩余课时</p>
              <p className={`font-medium ${remaining <= 2 ? 'text-orange-600' : 'text-gray-900'}`}>
                {remaining}
              </p>
            </div>
          )}
        </div>
      </div>
    );
  };

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} />;

  return (
    <div className="space-y-6">
      <div className="bg-white p-6 rounded-lg shadow">
        <h3 className="text-lg font-semibold mb-4">会员详情 Member Details</h3>
        <div className="space-y-4">
          <div>
            <h3 className="text-lg font-medium text-gray-900">会员信息 Member Info</h3>
            <div className="mt-2 grid grid-cols-2 gap-4">
              <div>
                <p className="text-gray-600">姓名 Name</p>
                <p className="font-medium">{member.name}</p>
              </div>
              <div>
                <p className="text-gray-600">邮箱 Email</p>
                <p className="font-medium">{member.email || '-'}</p>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-medium text-gray-900">会员卡信息 Membership Cards</h3>
            <div className="mt-2">
              {member.membership_cards?.length ? (
                member.membership_cards.map(card => getCardDetails(card))
              ) : (
                <p className="text-gray-500">暂无会员卡 No membership cards</p>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-lg shadow">
        <h3 className="text-lg font-semibold mb-4">签到记录 Check-in History</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  日期 Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  课程 Class
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  状态 Status
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {records.map((checkIn) => (
                <tr key={checkIn.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    {formatDate(new Date(checkIn.created_at))}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    {checkIn.class_type === 'morning' ? '早课 Morning' : '晚课 Evening'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    {checkIn.is_extra ? (
                      <span className="text-muaythai-red">额外签到 Extra</span>
                    ) : (
                      <span className="text-green-600">正常 Regular</span>
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
    </div>
  );
}