import React, { useState } from 'react';
import { Database } from '../../types/database';
import { formatCardType, formatCardValidity, formatRemainingClasses, formatCardInfo, getCardTypeDisplay, getCardCategoryDisplay, getCardSubtypeDisplay, getTrainerTypeDisplay } from '../../utils/membership/formatters';
import EditMemberModal from './EditMemberModal';
import { supabase } from '../../lib/supabase';

type Member = Database['public']['Tables']['members']['Row'];
type MembershipCard = Database['public']['Tables']['membership_cards']['Row'];

interface MemberTableProps {
  members: (Member & { membership_cards: MembershipCard[] })[];
  onMemberUpdated: () => void;
  onEdit: (member: Member & { membership_cards: MembershipCard[] }) => void;
  onDelete: (memberId: string) => void;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

export default function MemberTable({ 
  members, 
  onMemberUpdated, 
  onEdit, 
  onDelete,
  currentPage,
  totalPages,
  onPageChange
}: MemberTableProps) {
  const [editingMember, setEditingMember] = useState<Member & { membership_cards: MembershipCard[] } | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const handleEditClick = (member: Member & { membership_cards: MembershipCard[] }) => {
    onEdit(member);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingMember(null);
  };

  const handleMemberUpdated = () => {
    setIsModalOpen(false);
    setEditingMember(null);
    onMemberUpdated();
  };

  const handleDeleteMember = async (memberId: string) => {
    onDelete(memberId);
  };

  // 分页控件
  const Pagination = () => {
    if (totalPages <= 1) return null;
    
    return (
      <div className="flex justify-center mt-4 space-x-2">
        {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
          <button
            key={page}
            onClick={() => onPageChange(page)}
            className={`px-3 py-1 rounded ${
              currentPage === page
                ? 'bg-blue-500 text-white'
                : 'bg-gray-200 hover:bg-gray-300'
            }`}
          >
            {page}
          </button>
        ))}
      </div>
    );
  };

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              姓名
            </th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              邮箱
            </th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              到期状态
            </th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              会员卡
            </th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              操作
            </th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {members.map((member) => (
            <tr key={member.id}>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm font-medium text-gray-900">{member.name}</div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm text-gray-500">{member.email || '-'}</div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm">
                  {member.membership_cards && member.membership_cards.length > 0 ? (
                    (() => {
                      const now = new Date();
                      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // 今天0点
                      
                      // 检查是否有有效的卡（未过期）
                      const hasValidCard = member.membership_cards.some(card => {
                        const validUntil = card.valid_until ? new Date(card.valid_until) : null;
                        // 如果卡没有有效期限制或有效期在今天及以后，则认为有效
                        return !validUntil || validUntil >= today;
                      });

                      // 如果所有卡都过期了（没有有效卡），才显示"已过期"
                      if (!hasValidCard && member.membership_cards.length > 0) {
                        return (
                          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
                            已过期 Expired
                          </span>
                        );
                      }

                      // 检查是否有即将过期的卡（7天内）
                      const sevenDaysFromNow = new Date();
                      sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
                      
                      const hasUpcomingExpiryCard = member.membership_cards.some(card => {
                        if (!card.valid_until) return false;
                        
                        const now = new Date();
                        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                        const validUntilDate = new Date(card.valid_until);
                        const validUntilDay = new Date(validUntilDate.getFullYear(), validUntilDate.getMonth(), validUntilDate.getDate());
                        
                        // 剩余天数计算
                        const daysLeft = Math.ceil((validUntilDay.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
                        
                        // 严格检查是否在0-7天范围内（包括当天）
                        return daysLeft >= 0 && daysLeft <= 7;
                      });

                      // 如果有即将过期的卡，显示"即将到期"
                      if (hasUpcomingExpiryCard) {
                        return (
                          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">
                            即将到期 Expiring soon
                          </span>
                        );
                      }
                      
                      // 检查是否有课时不足的卡（剩余课时<=2）
                      const hasLowClassesCard = member.membership_cards.some(card => {
                        // 月卡不考虑剩余课时
                        const isMonthlyCard = 
                          card.card_category === '月卡' || 
                          card.card_category === 'monthly';
                          
                        if (isMonthlyCard) {
                          return false; // 月卡不基于课时判断是否不足
                        }
                        
                        // 其他卡类型正常判断剩余课时
                        // 如果是团课，检查团课剩余课时
                        const hasLowGroupSessions = 
                          (card.card_type === '团课' || card.card_type === 'class' || card.card_type === 'group') && 
                          typeof card.remaining_group_sessions === 'number' && 
                          card.remaining_group_sessions <= 2;
                        
                        // 如果是私教课，检查私教课剩余课时
                        const hasLowPrivateSessions = 
                          (card.card_type === '私教课' || card.card_type === 'private') && 
                          typeof card.remaining_private_sessions === 'number' && 
                          card.remaining_private_sessions <= 2;
                          
                        // 如果是儿童团课，检查儿童团课剩余课时
                        const hasLowKidsSessions = 
                          (card.card_type === '儿童团课' || card.card_type === 'kids_group' || card.card_type === 'kids') && 
                          typeof card.remaining_kids_sessions === 'number' && 
                          card.remaining_kids_sessions <= 2;
                          
                        // 任何一种课时不足都判定为课时不足
                        return hasLowGroupSessions || hasLowPrivateSessions || hasLowKidsSessions;
                      });
                      
                      // 如果有课时不足的卡，显示"课时不足"
                      if (hasLowClassesCard) {
                        return (
                          <span className="px-2 py-1 text-xs font-semibold rounded-full bg-orange-100 text-orange-800">
                            课时不足 Low Classes
                          </span>
                        );
                      }

                      // 否则显示"正常"
                      return (
                        <span className="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                          正常 Active
                        </span>
                      );
                    })()
                  ) : (
                    <span className="px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800">
                      无会员卡 No Card
                    </span>
                  )}
                </div>
              </td>
              <td className="px-6 py-4">
                <div className="text-sm text-gray-900">
                  {member.membership_cards && member.membership_cards.length > 0 ? (
                    <ul className="list-disc pl-5">
                      {member.membership_cards.map((card) => (
                        <li key={card.id} className="mb-2">
                          {/* 使用formatCardInfo函数替代直接调用多个格式化函数 */}
                          {formatCardInfo(card)}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <span className="text-gray-500">无会员卡</span>
                  )}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                <button
                  onClick={() => handleEditClick(member)}
                  className="text-indigo-600 hover:text-indigo-900 mr-4"
                >
                  编辑
                </button>
                <button
                  onClick={() => handleDeleteMember(member.id)}
                  className="text-red-600 hover:text-red-900"
                >
                  删除
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <Pagination />
    </div>
  );
}