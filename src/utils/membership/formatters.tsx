import { MembershipType } from '../../types/database';
import { Database } from '../../types/database';
import { formatDate } from '../dateUtils';
import type { MembershipCard } from '../../types/database';

export function formatMembershipType(type: MembershipType): string {
  const formats: Record<MembershipType, string> = {
    'single_class': '单次卡 Single Class',
    'two_classes': '两次卡 Two Classes',
    'ten_classes': '10次卡 Ten Classes',
    'single_monthly': '单次月卡 Single Monthly',
    'double_monthly': '双次月卡 Double Monthly'
  };
  
  return formats[type] || type;
}

export function isMonthlyMembership(type: MembershipType | null | undefined): boolean {
  return type === 'single_monthly' || type === 'double_monthly';
}

/**
 * 获取会员卡的完整名称（中文）
 */
export function getFullCardName(card: MembershipCard): string {
  if (!card) return '无卡';

  let name = '';
  
  // 标准化卡类型
  const cardType = standardizeCardType(card.card_type ?? null);
  const cardCategory = standardizeCardCategory(card.card_category ?? null);
  const cardSubtype = standardizeCardSubtype(card.card_subtype ?? null);
  
  if (cardType === '团课') {
    if (cardCategory === '课时卡') {
      name = `团课${cardSubtype}`;
    } else if (cardCategory === '月卡') {
      name = `团课${cardSubtype}`;
    }
  } else if (cardType === '私教课') {
    name = `私教${cardSubtype}`;
    if (card.trainer_type) {
      name += ` (${card.trainer_type === 'jr' ? 'JR教练' : '高级教练'})`;
    }
  }
  
  return name || '未知卡类型';
}

/**
 * 格式化会员卡类型（中文）
 */
export function formatCardType(card: MembershipCard): string {
  if (!card) return '无卡';
  
  console.log('格式化会员卡:', card); // 添加日志，查看卡信息
  
  // 直接检查card.card_type是否已经是中文
  if (card.card_type === '团课' || card.card_type === '私教课') {
    let name = card.card_type;
    
    // 添加子类型
    if (card.card_subtype) {
      name += ' ' + card.card_subtype;
    }
    
    // 添加教练类型
    if (card.card_type === '私教课' && card.trainer_type) {
      name += ` (${card.trainer_type === 'jr' ? 'JR教练' : '高级教练'})`;
    }
    
    return name;
  }
  
  // 如果不是中文，则进行标准化
  const cardType = standardizeCardType(card.card_type ?? null);
  const cardCategory = standardizeCardCategory(card.card_category ?? null);
  const cardSubtype = standardizeCardSubtype(card.card_subtype ?? null);
  
  let name = '';
  
  if (cardType === '团课') {
    if (cardCategory === '课时卡') {
      name = `团课 ${cardSubtype}`;
    } else if (cardCategory === '月卡') {
      name = `团课 ${cardSubtype}`;
    }
  } else if (cardType === '私教课') {
    name = `私教 ${cardSubtype}`;
    if (card.trainer_type) {
      name += ` (${card.trainer_type === 'jr' ? 'JR教练' : '高级教练'})`;
    }
  }
  
  return name || '未知卡类型';
}

/**
 * 格式化会员卡有效期
 */
export function formatCardValidity(card: MembershipCard): string {
  if (!card) return '';
  
  console.log('格式化会员卡有效期:', card); // 添加日志，查看卡信息
  
  if (!card.valid_until) {
    return '无到期日';
  }
  
  const validUntil = new Date(card.valid_until);
  const now = new Date();
  
  // 检查卡是否已过期
  if (validUntil < now) {
    return `已过期 (${formatDate(card.valid_until)})`;
  }
  
  // 计算剩余天数
  const diffTime = validUntil.getTime() - now.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  if (diffDays <= 7) {
    return `即将到期 (${formatDate(card.valid_until)})`;
  }
  
  return `有效期至 ${formatDate(card.valid_until)}`;
}

/**
 * 格式化剩余课时
 */
export function formatRemainingClasses(card: MembershipCard): string {
  if (!card) return '';
  
  console.log('格式化剩余课时:', card); // 添加日志，查看卡信息
  
  const cardType = card.card_type ?? '';
  
  if (cardType === '团课') {
    if (card.remaining_group_sessions === null || card.remaining_group_sessions === undefined) {
      return '课时未设置';
    }
    return `剩余 ${card.remaining_group_sessions} 节团课`;
  } else if (cardType === '私教课') {
    if (card.remaining_private_sessions === null || card.remaining_private_sessions === undefined) {
      return '课时未设置';
    }
    return `剩余 ${card.remaining_private_sessions} 节私教课`;
  }
  
  // 如果card_type不是中文，尝试标准化
  const standardizedType = standardizeCardType(cardType);
  
  if (standardizedType === '团课') {
    if (card.remaining_group_sessions === null || card.remaining_group_sessions === undefined) {
      return '课时未设置';
    }
    return `剩余 ${card.remaining_group_sessions} 节团课`;
  } else if (standardizedType === '私教课') {
    if (card.remaining_private_sessions === null || card.remaining_private_sessions === undefined) {
      return '课时未设置';
    }
    return `剩余 ${card.remaining_private_sessions} 节私教课`;
  }
  
  return '';
}

/**
 * 标准化卡类型
 */
function standardizeCardType(cardType: string | null): string {
  if (!cardType) return '';
  
  const lowerType = cardType.toLowerCase();
  
  // 先检查是否为儿童团课
  if (lowerType.includes('kids') || lowerType.includes('儿童')) {
    return '儿童团课';
  } else if (lowerType === 'class' || lowerType === 'group' || lowerType.includes('团课')) {
    return '团课';
  } else if (lowerType === 'private' || lowerType.includes('私教')) {
    return '私教课';
  }
  
  return cardType;
}

/**
 * 标准化卡类别
 */
function standardizeCardCategory(cardCategory: string | null): string {
  if (!cardCategory) return '';
  
  const lowerCategory = cardCategory.toLowerCase();
  
  if (lowerCategory === 'session' || lowerCategory === 'sessions' || lowerCategory.includes('课时')) {
    return '课时卡';
  } else if (lowerCategory === 'monthly' || lowerCategory.includes('月')) {
    return '月卡';
  }
  
  return cardCategory;
}

/**
 * 标准化卡子类型
 */
function standardizeCardSubtype(cardSubtype: string | null): string {
  if (!cardSubtype) return '';
  
  const lowerSubtype = cardSubtype.toLowerCase();
  
  if (lowerSubtype.includes('single') && !lowerSubtype.includes('monthly')) {
    return '单次卡';
  } else if (lowerSubtype.includes('two') || lowerSubtype.includes('double') && !lowerSubtype.includes('monthly')) {
    return '两次卡';
  } else if (lowerSubtype.includes('ten') || lowerSubtype.includes('10')) {
    return '10次卡';
  } else if (lowerSubtype.includes('single') && lowerSubtype.includes('monthly')) {
    return '单次月卡';
  } else if (lowerSubtype.includes('double') && lowerSubtype.includes('monthly')) {
    return '双次月卡';
  }
  
  return cardSubtype;
}

// 卡类型映射
export function getCardTypeDisplay(type: string | null): string {
  if (!type) return '未知';
  if (type === 'kids_group' || type.toLowerCase().includes('kids') || type.includes('儿童')) return '儿童团课';
  if (type === 'class' || type === 'group') return '团课';
  if (type === 'private' || type === '私教') return '私教课';
  return type;
}

// 卡类别映射
export function getCardCategoryDisplay(category: string | null): string {
  if (!category) return '';
  if (category === 'group') return '课时卡';
  if (category === 'private') return '私教';
  if (category === 'monthly') return '月卡';
  return category;
}

// 卡子类型映射
export function getCardSubtypeDisplay(subtype: string | null): string {
  if (!subtype) return '';
  if (subtype === 'ten_classes' || subtype === 'group_ten_class') return '10次卡';
  if (subtype === 'single_class') return '单次卡';
  if (subtype === 'two_classes') return '两次卡';
  if (subtype === 'ten_private') return '10次私教';
  if (subtype === 'single_private') return '单次私教';
  if (subtype === 'single_monthly') return '单次月卡';
  if (subtype === 'double_monthly') return '双次月卡';
  return subtype;
}

// 教练类型映射
export function getTrainerTypeDisplay(type: string | null): string {
  if (!type) return '';
  if (type === 'jr') return 'JR教练';
  if (type === 'senior') return '高级教练';
  return type;
}

// 统一格式化会员卡信息
import React from 'react';

export function formatCardInfo(card: any, asString = false): string | React.ReactNode {
  // 添加调试日志
  console.log('Card data:', card);
  
  // 获取标准化的卡类型，确保一致性
  const cardType = standardizeCardType(card.card_type ?? null);
  const type = cardType; // 直接使用标准化的卡类型
  const category = getCardCategoryDisplay(card.card_category ?? null);
  
  // 尝试获取或推断子类型
  let subtype = '';
  if (card.card_subtype) {
    // 如果有明确的子类型，使用它
    subtype = getCardSubtypeDisplay(card.card_subtype);
  } else {
    // 如果没有子类型，尝试根据其他信息推断
    if (type === '团课') {
      if (category === '月卡' || card.card_category?.toLowerCase() === 'monthly') {
        // 月卡默认为单次月卡，因为更常见
        subtype = '单次月卡';
        
        // 尝试从卡的名称或其他信息中推断是否是双次月卡
        const cardName = card.name || '';
        if (cardName.includes('双') || cardName.includes('double') || cardName.includes('两次')) {
          subtype = '双次月卡';
        }
      } else if (category === '课时卡' || card.card_category?.toLowerCase() === 'group') {
        // 对课时卡，根据剩余课时推断
        const remaining = card.remaining_group_sessions ?? 0;
        
        if (remaining === 1) {
          subtype = '单次卡';
        } else if (remaining === 2) {
          subtype = '两次卡';
        } else if (remaining >= 10) {
          subtype = '10次卡';
        }
      }
    } else if (type === '私教课') {
      // 对私教卡，根据剩余课时推断
      const remaining = card.remaining_private_sessions ?? 0;
      
      if (remaining === 1) {
        subtype = '单次卡';
      } else if (remaining >= 10) {
        subtype = '10次卡';
      }
    }
  }
  
  const trainer = card.trainer_type ? `（${getTrainerTypeDisplay(card.trainer_type ?? null)}）` : '';
  
  // 构建显示的主要信息，确保包含子类型
  let main = [type, category, subtype].filter(Boolean).join(' ');
  console.log('Formatted result:', main);
  
  // 更好地处理不同类型卡的剩余次数显示
  let remain = '';
  
  // 关键修改：使用标准化后的cardType并调整判断顺序
  const isKidsCard = cardType === '儿童团课';
  const isGroupCard = cardType === '团课';
  const isPrivateCard = cardType === '私教课';
  const isMonthlyCard = card.card_category === '月卡' || card.card_category?.toLowerCase() === 'monthly';
  
  if (isMonthlyCard) {
    // 月卡显示单次/双次而不是剩余课时
    const monthlyType = subtype.includes('双次') ? '双次' : '单次';
    remain = `剩余团课: ${monthlyType}`;
  } else if (isKidsCard) { // 关键：将儿童团课检查移到前面
    remain = `剩余儿童团课: ${card.remaining_kids_sessions ?? '未设置'}`;
  } else if (isGroupCard) {
    remain = `剩余团课: ${card.remaining_group_sessions ?? '未设置'}`;
  } else if (isPrivateCard) {
    remain = `剩余私教: ${card.remaining_private_sessions ?? '未设置'}`;
  } else {
    remain = `剩余课时: ${card.remaining_group_sessions ?? card.remaining_private_sessions ?? card.remaining_kids_sessions ?? '未设置'}`;
  }
  
  const valid = card.valid_until ? `有效期至: ${new Date(card.valid_until).toLocaleDateString('zh-CN')}` : '无有效期限制';
  
  if (asString) {
    return [main + trainer, remain, valid].join(' | ');
  }
  
  return (
    <div>
      <div className="font-medium">{main}{trainer}</div>
      <div className="text-xs text-gray-500 mt-1">{remain} | {valid}</div>
    </div>
  );
}