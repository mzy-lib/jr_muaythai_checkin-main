import React from 'react';
import { Member, MembershipCard } from '../../types/database';
import { User, CreditCard, Calendar } from 'lucide-react';
import { formatDate } from '../../utils/dateUtils';

// 卡类型映射 (与EditMemberModal.tsx一致)
const getCardTypeDisplay = (type: string | null | undefined): string => {
  if (!type) return '未知 Unknown';
  if (type === 'class') return '团课 Group Class';
  if (type === 'private') return '私教课 Private Class';
  if (type === '团课') return '团课 Group Class';
  if (type === '私教课') return '私教课 Private Class';
  return type; // 返回原值
};

// 卡类别映射 (与EditMemberModal.tsx一致)
const getCardCategoryDisplay = (category: string | null | undefined): string => {
  if (!category) return '';
  if (category === 'group') return '课时卡 Session';
  if (category === 'private') return '私教 Private';
  if (category === 'monthly') return '月卡 Monthly';
  if (category === '课时卡') return '课时卡 Session';
  if (category === '私教') return '私教 Private';
  if (category === '月卡') return '月卡 Monthly';
  return category; // 返回原值
};

// 卡子类型映射 (与EditMemberModal.tsx一致)
const getCardSubtypeDisplay = (subtype: string | null | undefined): string => {
  if (!subtype) return '';
  
  // 团课卡子类型
  if (subtype === 'ten_classes' || subtype === 'group_ten_class') return '10次卡 Ten Classes';
  if (subtype === 'single_class') return '单次卡 Single Class';
  if (subtype === 'two_classes') return '两次卡 Two Classes';
  
  // 私教卡子类型
  if (subtype === 'ten_private') return '10次私教 Ten Private';
  if (subtype === 'single_private') return '单次私教 Single Private';
  
  // 月卡子类型
  if (subtype === 'single_monthly') return '单次月卡 Single Monthly';
  if (subtype === 'double_monthly') return '双次月卡 Double Monthly';
  
  // 中文类型也添加英文翻译
  if (subtype === '10次卡') return '10次卡 Ten Classes';
  if (subtype === '单次卡') return '单次卡 Single Class';
  if (subtype === '两次卡') return '两次卡 Two Classes';
  if (subtype === '10次私教') return '10次私教 Ten Private';
  if (subtype === '单次私教') return '单次私教 Single Private';
  if (subtype === '单次月卡') return '单次月卡 Single Monthly';
  if (subtype === '双次月卡') return '双次月卡 Double Monthly';
  
  return subtype; // 返回原值
};

// 教练类型映射 (与EditMemberModal.tsx一致)
const getTrainerTypeDisplay = (type: string | null | undefined): string => {
  if (!type) return '';
  if (type === 'jr') return 'JR教练 (JR)';
  if (type === 'senior') return '高级教练 (Senior)';
  return type;
};

interface Props {
  member: Member & { membership_cards?: MembershipCard[] };
}

export default function MemberProfile({ member }: Props) {
  const getCardDetails = (card: MembershipCard) => {
    // 使用与EditMemberModal相同的方式格式化卡名称
    const cardType = getCardTypeDisplay(card.card_type);
    const cardCategory = getCardCategoryDisplay(card.card_category);
    const cardSubtype = getCardSubtypeDisplay(card.card_subtype);
    
    const formattedCardName = `${cardType} ${cardCategory} ${cardSubtype}`.trim();
    const trainerInfo = card.trainer_type ? ` (${getTrainerTypeDisplay(card.trainer_type)})` : '';
    const fullCardName = `${formattedCardName}${trainerInfo}`;

    // 根据卡类型获取剩余课时
    const isPrivateCard = card.card_type === '私教课' || 
                         (card.card_type?.toLowerCase() === 'private');
    const remaining = isPrivateCard
      ? card.remaining_private_sessions 
      : card.remaining_group_sessions;

    return (
      <div key={card.id} className="bg-white p-4 rounded-lg shadow-sm">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <CreditCard className="w-5 h-5 text-[#4285F4]" />
            <div>
              <h4 className="font-medium text-gray-900">{fullCardName}</h4>
              {card.valid_until && (
                <p className="text-sm text-gray-500">
                  到期日期 Expiry: {formatDate(card.valid_until)}
                </p>
              )}
            </div>
          </div>
          {remaining !== null && remaining !== undefined && (
            <div className="text-right">
              <p className="text-sm text-gray-500">剩余课时 Remaining</p>
              <p className={`font-medium ${remaining <= 2 ? 'text-orange-600' : 'text-gray-900'}`}>
                {remaining}
              </p>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="max-w-3xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <div className="space-y-6">
        {/* 基本信息 */}
        <div className="bg-white p-6 rounded-lg shadow-sm">
          <div className="flex items-center space-x-3 mb-4">
            <User className="w-5 h-5 text-[#4285F4]" />
            <h3 className="text-lg font-medium">个人信息 Personal Info</h3>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-500">姓名 Name</p>
              <p className="font-medium">{member.name}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">邮箱 Email</p>
              <p className="font-medium">{member.email || '-'}</p>
            </div>
          </div>
        </div>

        {/* 会员卡信息 */}
        <div className="bg-white p-6 rounded-lg shadow-sm">
          <div className="flex items-center space-x-3 mb-4">
            <Calendar className="w-5 h-5 text-[#4285F4]" />
            <h3 className="text-lg font-medium">会员卡信息 Membership Cards</h3>
          </div>
          <div className="space-y-4">
            {member.membership_cards?.length ? (
              member.membership_cards.map(card => getCardDetails(card))
            ) : (
              <p className="text-gray-500">暂无会员卡 No membership cards</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}