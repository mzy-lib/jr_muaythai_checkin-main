import { MembershipCard } from '../../types/database';

// 根据卡类型和剩余次数获取显示文本
export function getRemainingClassesText(card: MembershipCard): string {
  if (card.card_type === '团课' || card.card_type === 'group') {
    return `剩余团课：${card.remaining_group_sessions || 0}次`;
  } else if (card.card_type === 'kids_group' || card.card_type === '儿童团课') {
    return `剩余儿童团课：${card.remaining_group_sessions || 0}次`;
  } else if (card.card_type === '私教' || card.card_type === 'private') {
    return `剩余私教：${card.remaining_private_sessions || 0}次`;
  } else {
    return '未知卡类型';
  }
}

// 获取剩余课时的数值
export function getRemainingClasses(card: MembershipCard): string {
  if (card.card_type === '团课' || card.card_type === 'group' || 
      card.card_type === 'kids_group' || card.card_type === '儿童团课') {
    return `${card.remaining_group_sessions || 0}次`;
  } else if (card.card_type === '私教' || card.card_type === 'private') {
    return `${card.remaining_private_sessions || 0}次`;
  } else {
    return '0次';
  }
} 