import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface CardStat {
  cardType: string;
  count: number;
}

// 卡类型映射函数，与EditMemberModal.tsx保持一致
const getCardTypeDisplay = (type: string | null): string => {
  if (!type) return '未知';
  if (type === 'class') return '团课';
  if (type === 'private') return '私教课';
  return type; // 返回原值，以防已经是中文
};

// 卡类别映射函数，与EditMemberModal.tsx保持一致
const getCardCategoryDisplay = (category: string | null): string => {
  if (!category) return '';
  if (category === 'group') return '课时卡';
  if (category === 'private') return '私教';
  if (category === 'monthly') return '月卡';
  return category; // 返回原值，以防已经是中文
};

// 卡子类型映射函数，与EditMemberModal.tsx保持一致
const getCardSubtypeDisplay = (subtype: string | null): string => {
  if (!subtype) return '';
  
  // 团课卡子类型
  if (subtype === 'ten_classes' || subtype === 'group_ten_class') return '10次卡';
  if (subtype === 'single_class') return '单次卡';
  if (subtype === 'two_classes') return '两次卡';
  
  // 私教卡子类型
  if (subtype === 'ten_private') return '10次私教';
  if (subtype === 'single_private') return '单次私教';
  
  // 月卡子类型
  if (subtype === 'single_monthly') return '单次月卡';
  if (subtype === 'double_monthly') return '双次月卡';
  
  return subtype; // 返回原值，以防已经是中文
};

export const useMembershipCardStats = () => {
  const [cardStats, setCardStats] = useState<CardStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const fetchCardStats = async () => {
      try {
        setLoading(true);
        
        // 获取会员卡类型分布
        const { data, error: fetchError } = await supabase
          .from('membership_cards')
          .select('card_type, card_category, card_subtype');

        if (fetchError) throw fetchError;

        // 处理数据分组
        const cardTypeMap = new Map<string, number>();
        
        data?.forEach(card => {
          // 首先将数据库中的英文值转换为中文显示值
          const displayCardType = getCardTypeDisplay(card.card_type);
          const displayCardCategory = getCardCategoryDisplay(card.card_category);
          const displayCardSubtype = getCardSubtypeDisplay(card.card_subtype);
          
          let cardTypeLabel = '';
          
          // 根据卡类型、类别和子类型生成标签
          if (displayCardType === '团课') {
            if (displayCardCategory === '课时卡') {
              // 团课课时卡：单次卡、两次卡、10次卡
              if (displayCardSubtype === '单次卡') {
                cardTypeLabel = '团课-单次卡';
              } else if (displayCardSubtype === '两次卡') {
                cardTypeLabel = '团课-两次卡';
              } else if (displayCardSubtype === '10次卡') {
                cardTypeLabel = '团课-10次卡';
              } else {
                cardTypeLabel = `团课-${displayCardSubtype || '其他'}`;
              }
            } else if (displayCardCategory === '月卡') {
              // 团课月卡：单次月卡、双次月卡
              if (displayCardSubtype === '单次月卡') {
                cardTypeLabel = '团课-单次月卡';
              } else if (displayCardSubtype === '双次月卡') {
                cardTypeLabel = '团课-双次月卡';
              } else {
                cardTypeLabel = `团课-${displayCardSubtype || '其他月卡'}`;
              }
            } else {
              // 其他团课卡
              cardTypeLabel = `团课-${displayCardSubtype || '其他'}`;
            }
          } else if (displayCardType === '私教课') {
            // 私教课：单次卡、10次卡
            if (displayCardSubtype === '单次卡' || displayCardSubtype === '单次私教') {
                cardTypeLabel = '私教-单次卡';
            } else if (displayCardSubtype === '10次卡' || displayCardSubtype === '10次私教') {
                cardTypeLabel = '私教-10次卡';
            } else {
                cardTypeLabel = `私教-${displayCardSubtype || '其他'}`;
            }
          } else if (displayCardType === '儿童团课') {
            // 儿童团课卡
            cardTypeLabel = '儿童团课-10次卡';
          } else {
            // 其他类型卡
            cardTypeLabel = `${displayCardType || '未知'}-${displayCardSubtype || '其他'}`;
          }
          
          // 更新计数
          cardTypeMap.set(
            cardTypeLabel, 
            (cardTypeMap.get(cardTypeLabel) || 0) + 1
          );
        });
        
        // 转换为数组并排序
        const statsArray: CardStat[] = Array.from(cardTypeMap.entries())
          .map(([cardType, count]) => ({ cardType, count }))
          .sort((a, b) => b.count - a.count);
        
        setCardStats(statsArray);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchCardStats();
  }, []);

  return { cardStats, loading, error };
}; 