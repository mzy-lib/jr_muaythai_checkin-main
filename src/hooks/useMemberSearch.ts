import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Member, CardType, CardSubtype } from '../types/database';
import { QueryCache, createCacheKey } from '../utils/cacheUtils';
import { handleSupabaseError } from '../utils/fetchUtils';
import { normalizeNameForComparison } from '../utils/memberUtils';

interface SearchParams {
  searchTerm?: string;
  cardType?: CardType | 'no_card' | '团课' | '私教课' | 'all_cards' | '';
  cardSubtype?: CardSubtype | string | '';
  expiryStatus?: 'active' | 'upcoming' | 'expired' | 'low_classes' | '';
  page?: number;
  pageSize?: number;
}

interface SearchResult {
  members: Member[];
  totalCount: number;
  currentPage: number;
  totalPages: number;
}

const memberCache = new QueryCache<{
  members: Member[];
  totalCount: number;
}>();

// 修改卡类型映射函数，添加儿童团课
const mapCardTypeToDbValues = (cardType: string): string[] => {
  // 定义映射关系
  const typeMap: Record<string, string[]> = {
    '团课': ['团课', 'class', 'group'],
    'class': ['团课', 'class', 'group'],
    '私教课': ['私教课', 'private', '私教'],
    'private': ['私教课', 'private', '私教'],
    '月卡': ['月卡', 'monthly'],
    'monthly': ['月卡', 'monthly'],
    '儿童团课': ['儿童团课', 'kids_group', 'kids'],
    'kids_group': ['儿童团课', 'kids_group', 'kids'],
    'kids': ['儿童团课', 'kids_group', 'kids']
  };
  
  return typeMap[cardType] || [cardType];
};

// 添加卡子类型映射函数，确保同时支持中英文卡子类型
const mapCardSubtypeToDbValues = (cardSubtype: string, cardType?: string): string[] => {
  // 基础映射关系
  const subtypeMap: Record<string, string[]> = {
    // 通用映射 - 适用于所有卡类型
    '10次卡': ['10次卡', 'ten_classes', 'ten_private', 'group_ten_class'],
    
    // 团课卡子类型专用映射
    'ten_classes': ['10次卡', 'ten_classes', 'group_ten_class'],
    '单次卡': ['单次卡', 'single_class', 'single_private'],
    'single_class': ['单次卡', 'single_class'],
    '两次卡': ['两次卡', 'two_classes'],
    'two_classes': ['两次卡', 'two_classes'],
    
    // 私教卡子类型专用映射
    '10次私教': ['10次私教', '10次卡', 'ten_private'],
    'ten_private': ['10次私教', '10次卡', 'ten_private'],
    '单次私教': ['单次私教', '单次卡', 'single_private'],
    'single_private': ['单次私教', '单次卡', 'single_private'],
    
    // 月卡子类型专用映射
    '单次月卡': ['单次月卡', 'single_monthly'],
    'single_monthly': ['单次月卡', 'single_monthly'],
    '双次月卡': ['双次月卡', 'double_monthly'],
    'double_monthly': ['双次月卡', 'double_monthly']
  };
  
  // 如果提供了卡类型，可以进一步优化映射
  if (cardType) {
    // 针对不同卡类型的特定映射
    if ((cardType === '团课' || cardType === 'class' || cardType === 'group') && cardSubtype === '10次卡') {
      return ['10次卡', 'ten_classes', 'group_ten_class'];
    }
    
    if ((cardType === '私教课' || cardType === 'private') && cardSubtype === '10次卡') {
      return ['10次卡', 'ten_private', '10次私教'];
    }
  }
  
  return subtypeMap[cardSubtype] || [cardSubtype];
};

export function useMemberSearch(defaultPageSize: number = 10) {
  const [result, setResult] = useState<SearchResult>({
    members: [],
    totalCount: 0,
    currentPage: 1,
    totalPages: 1
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const searchMembers = async (params: SearchParams = {}) => {
    try {
      setLoading(true);
      setError(null);

      const {
        searchTerm = '',
        cardType = '',
        cardSubtype = '',
        expiryStatus = '',
        page = 1,
        pageSize = defaultPageSize
      } = params;

      // 计算分页范围
      const start = (page - 1) * pageSize;
      const end = start + pageSize - 1;

      console.log('搜索条件:', { searchTerm, cardType, cardSubtype, expiryStatus, page, pageSize });

      // 处理"无会员卡"筛选的情况
      if (cardType === 'no_card') {
        try {
          console.log('执行无会员卡筛选查询');
          // 查找所有会员ID
          const { data: allMembersData, error: allMembersError } = await supabase
            .from('members')
            .select('id');
          
          if (allMembersError) throw allMembersError;
          const allMemberIds = allMembersData.map(m => m.id);
          console.log(`找到 ${allMemberIds.length} 个会员`);
          
          if (allMemberIds.length === 0) {
            setResult({
              members: [],
              totalCount: 0,
              currentPage: page,
              totalPages: 1
            });
            setLoading(false);
            return {
              members: [],
              totalCount: 0,
              currentPage: page,
              totalPages: 1
            };
          }
          
          // 查找有会员卡的会员ID
          const { data: membersWithCardsData, error: membersWithCardsError } = await supabase
            .from('membership_cards')
            .select('member_id')
            .order('member_id');
            
          if (membersWithCardsError) throw membersWithCardsError;
          
          // 转换为Set便于快速查找
          const membersWithCardsSet = new Set(membersWithCardsData.map(card => card.member_id));
          console.log(`找到 ${membersWithCardsSet.size} 个有会员卡的会员`);
          
          // 找出没有会员卡的会员ID
          const membersWithoutCardsIds = allMemberIds.filter(id => !membersWithCardsSet.has(id));
          console.log(`计算得到 ${membersWithoutCardsIds.length} 个没有会员卡的会员`);
          
          if (membersWithoutCardsIds.length === 0) {
            setResult({
              members: [],
              totalCount: 0,
              currentPage: page,
              totalPages: 1
            });
            setLoading(false);
            return {
              members: [],
              totalCount: 0,
              currentPage: page,
              totalPages: 1
            };
          }
          
          // 构建用于无卡会员的查询
          let noCardQuery = supabase
            .from('members')
            .select(`
              *,
              membership_cards (
                id,
                card_type,
                card_category,
                card_subtype,
                trainer_type,
                valid_until,
                remaining_group_sessions,
                remaining_private_sessions,
                remaining_kids_sessions
              )
            `, { count: 'exact' })
            .in('id', membersWithoutCardsIds);
          
          // 应用搜索条件
          if (searchTerm) {
            noCardQuery = noCardQuery.or(`name.ilike.%${searchTerm}%,email.ilike.%${searchTerm}%,phone.ilike.%${searchTerm}%`);
          }
          
          // 执行查询并应用分页
          const { data, error: fetchError, count } = await noCardQuery
            .order('id', { ascending: false })
            .range(start, end);
          
          if (fetchError) throw fetchError;
          
          // 更新结果
          const totalCount = count || 0;
          const totalPages = Math.ceil(totalCount / pageSize);
          
          setResult({
            members: data || [],
            totalCount,
            currentPage: page,
            totalPages
          });
          
          setLoading(false);
          return {
            members: data || [],
            totalCount,
            currentPage: page,
            totalPages
          };
        } catch (err) {
          console.error('无会员卡筛选查询失败:', err);
          setError('搜索无会员卡会员失败，请重试');
          setLoading(false);
          return {
            members: [],
            totalCount: 0,
            currentPage: 1,
            totalPages: 1
          };
        }
      }

      // 基础查询（处理正常情况）
      let query = supabase
        .from('members')
        .select(`
          *,
          membership_cards (
            id,
            card_type,
            card_category,
            card_subtype,
            trainer_type,
            valid_until,
            remaining_group_sessions,
            remaining_private_sessions,
            remaining_kids_sessions
          )
        `, { count: 'exact' });

      // 搜索条件
      if (searchTerm) {
        query = query.or(`name.ilike.%${searchTerm}%,email.ilike.%${searchTerm}%,phone.ilike.%${searchTerm}%`);
      }

      // 按会员卡类型和子类型筛选的特殊处理
      if (cardType && cardType !== 'no_card' && cardType !== 'all_cards') {
        console.log('执行会员卡类型筛选查询:', cardType);
        const cardTypeValues = mapCardTypeToDbValues(cardType);
        
        // 查找符合条件的会员卡的会员ID
        let cardQuery = supabase.from('membership_cards').select('member_id');
        
        // 添加卡类型条件
        if (cardTypeValues.length > 0) {
          cardQuery = cardQuery.in('card_type', cardTypeValues);
        }
        
        // 如果还有子类型条件，也添加上
        if (cardSubtype) {
          const cardSubtypeValues = mapCardSubtypeToDbValues(cardSubtype, cardType);
          if (cardSubtypeValues.length > 0) {
            cardQuery = cardQuery.in('card_subtype', cardSubtypeValues);
          }
        }
        
        const { data: cardData, error: cardError } = await cardQuery;
        
        if (cardError) {
          console.error('查询会员卡失败:', cardError);
          throw cardError;
        }
        
        // 获取符合条件的会员ID
        const memberIdsWithMatchingCards = [...new Set(cardData.map(card => card.member_id))];
        console.log(`找到 ${memberIdsWithMatchingCards.length} 个有匹配会员卡的会员`);
        
        if (memberIdsWithMatchingCards.length === 0) {
          // 如果没有找到符合条件的会员，直接返回空结果
          setResult({
            members: [],
            totalCount: 0,
            currentPage: page,
            totalPages: 1
          });
          setLoading(false);
          return {
            members: [],
            totalCount: 0,
            currentPage: page,
            totalPages: 1
          };
        }
        
        // 添加会员ID条件到主查询
        query = query.in('id', memberIdsWithMatchingCards);
      }

      // 到期状态筛选
      if (expiryStatus) {
        // 这里的逻辑保持不变，因为它处理的是membership_cards的属性，而不是成员的属性
        // 但我们需要改变查询方式，使用类似上面卡类型筛选的方法
        try {
          const today = new Date().toISOString().split('T')[0];
          const sevenDaysLater = new Date();
          sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);
          const sevenDaysLaterStr = sevenDaysLater.toISOString().split('T')[0];
          
          let expiryQuery = supabase.from('membership_cards').select('member_id');
          
          if (expiryStatus === 'low_classes') {
            // 课时不足：任何卡的团课、私教课或儿童团课剩余次数<=2
            // 这里需要更复杂的逻辑，类似于"已过期"的处理方式
            // 先查询所有会员卡，后续通过二次处理筛选出有课时不足卡的会员
            const { data: allCards, error: allCardsError } = await supabase
              .from('membership_cards')
              .select('member_id, card_type, card_category, remaining_group_sessions, remaining_private_sessions, remaining_kids_sessions');
            
            if (allCardsError) {
              console.error('查询所有会员卡失败:', allCardsError);
              throw allCardsError;
            }
            
            // 按会员分组会员卡
            const memberCardsMap = new Map<string, Array<any>>();
            allCards.forEach(card => {
              if (!memberCardsMap.has(card.member_id)) {
                memberCardsMap.set(card.member_id, []);
              }
              memberCardsMap.get(card.member_id)!.push(card);
            });
            
            // 找出有课时不足卡的会员
            const lowClassesMemberIds: string[] = [];
            
            memberCardsMap.forEach((cards, memberId) => {
              // 检查该会员是否有任何一张课时不足的卡
              const hasLowClassesCard = cards.some(card => {
                // 月卡不考虑课时不足
                const isMonthlyCard = 
                  card.card_category === '月卡' || 
                  card.card_category === 'monthly';
                  
                if (isMonthlyCard) {
                  return false;
                }
                
                // 根据卡类型检查对应的课时是否不足
                const hasLowGroupSessions = 
                  (card.card_type === '团课' || card.card_type === 'class' || card.card_type === 'group') && 
                  typeof card.remaining_group_sessions === 'number' && 
                  card.remaining_group_sessions <= 2;
                
                const hasLowPrivateSessions = 
                  (card.card_type === '私教课' || card.card_type === 'private') && 
                  typeof card.remaining_private_sessions === 'number' && 
                  card.remaining_private_sessions <= 2;
                  
                const hasLowKidsSessions = 
                  (card.card_type === '儿童团课' || card.card_type === 'kids_group' || card.card_type === 'kids') && 
                  typeof card.remaining_kids_sessions === 'number' && 
                  card.remaining_kids_sessions <= 2;
                  
                return hasLowGroupSessions || hasLowPrivateSessions || hasLowKidsSessions;
              });
              
              // 如果有课时不足的卡，添加到结果中
              if (hasLowClassesCard) {
                lowClassesMemberIds.push(memberId);
              }
            });
            
            console.log(`找到 ${lowClassesMemberIds.length} 个有课时不足卡的会员`);
            
            // 如果找不到会员，直接返回空结果
            if (lowClassesMemberIds.length === 0) {
              setResult({
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              });
              setLoading(false);
              return {
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              };
            }
            
            // 使用处理后的会员ID列表继续查询
            query = query.in('id', lowClassesMemberIds);
          } else if (expiryStatus === 'expired') {
            // 已过期：有效期早于今天
            // 这里先查询所有会员卡，后续通过二次处理筛选出所有卡都过期的会员
            const { data: allCards, error: allCardsError } = await supabase
              .from('membership_cards')
              .select('member_id, valid_until');
            
            if (allCardsError) {
              console.error('查询所有会员卡失败:', allCardsError);
              throw allCardsError;
            }
            
            // 按会员分组会员卡
            const memberCardsMap = new Map<string, Array<{member_id: string, valid_until: string | null}>>();
            allCards.forEach(card => {
              if (!memberCardsMap.has(card.member_id)) {
                memberCardsMap.set(card.member_id, []);
              }
              memberCardsMap.get(card.member_id)!.push(card);
            });
            
            // 找出所有卡都过期的会员
            const allExpiredMemberIds: string[] = [];
            
            memberCardsMap.forEach((cards, memberId) => {
              // 检查该会员是否有任何一张有效的卡
              const hasValidCard = cards.some(card => {
                // 如果卡没有有效期限制或有效期晚于今天，则认为有效
                return !card.valid_until || card.valid_until >= today;
              });
              
              // 如果所有卡都过期了（没有有效卡），则添加到结果中
              if (!hasValidCard && cards.length > 0) {
                allExpiredMemberIds.push(memberId);
              }
            });
            
            console.log(`找到 ${allExpiredMemberIds.length} 个所有卡都过期的会员`);
            
            // 如果找不到会员，直接返回空结果
            if (allExpiredMemberIds.length === 0) {
              setResult({
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              });
              setLoading(false);
              return {
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              };
            }
            
            // 使用处理后的会员ID列表继续查询
            query = query.in('id', allExpiredMemberIds);
          } else if (expiryStatus === 'upcoming') {
            // 即将到期：有效期在今天到7天后之间
            const today = new Date().toISOString().split('T')[0];
            const sevenDaysLater = new Date();
            sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);
            const sevenDaysLaterStr = sevenDaysLater.toISOString().split('T')[0];
            
            expiryQuery = expiryQuery.gte('valid_until', today).lte('valid_until', sevenDaysLaterStr);
            
            const { data: expiryData, error: expiryError } = await expiryQuery;
            
            if (expiryError) {
              console.error('查询到期状态失败:', expiryError);
              throw expiryError;
            }
            
            // 获取符合条件的会员ID
            const memberIdsWithMatchingExpiry = [...new Set(expiryData.map((card: {member_id: string}) => card.member_id))];
            console.log(`找到 ${memberIdsWithMatchingExpiry.length} 个即将到期的会员`);
            
            if (memberIdsWithMatchingExpiry.length === 0) {
              // 如果没有找到符合条件的会员，直接返回空结果
              setResult({
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              });
              setLoading(false);
              return {
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              };
            }
            
            // 添加会员ID条件到主查询
            query = query.in('id', memberIdsWithMatchingExpiry);
          } else if (expiryStatus === 'active') {
            // 有效：状态正常的会员
            // 与前面的筛选方式保持一致，先获取所有会员卡信息，然后进行复杂逻辑处理
            const { data: allCards, error: allCardsError } = await supabase
              .from('membership_cards')
              .select('member_id, card_type, card_category, valid_until, remaining_group_sessions, remaining_private_sessions, remaining_kids_sessions');
            
            if (allCardsError) {
              console.error('查询所有会员卡失败:', allCardsError);
              throw allCardsError;
            }
            
            // 按会员分组会员卡
            const memberCardsMap = new Map<string, Array<any>>();
            allCards.forEach(card => {
              if (!memberCardsMap.has(card.member_id)) {
                memberCardsMap.set(card.member_id, []);
              }
              memberCardsMap.get(card.member_id)!.push(card);
            });
            
            // 找出有正常卡的会员
            const today = new Date().toISOString().split('T')[0];
            const sevenDaysLater = new Date();
            sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);
            const sevenDaysLaterStr = sevenDaysLater.toISOString().split('T')[0];
            
            const activeMemberIds: string[] = [];
            
            memberCardsMap.forEach((cards, memberId) => {
              // 检查该会员是否有至少一张完全正常的卡
              const hasActiveCard = cards.some(card => {
                // 检查有效期 - 无有效期或有效期在7天后
                const hasValidExpiry = !card.valid_until || card.valid_until > sevenDaysLaterStr;
                
                // 检查剩余课时 - 根据卡类型检查对应的课时是否足够
                let hasEnoughSessions = true;
                
                // 月卡不考虑课时
                const isMonthlyCard = card.card_category === '月卡' || card.card_category === 'monthly';
                if (!isMonthlyCard) {
                  // 判断团课卡剩余课时
                  if ((card.card_type === '团课' || card.card_type === 'class' || card.card_type === 'group') && 
                      typeof card.remaining_group_sessions === 'number') {
                    hasEnoughSessions = hasEnoughSessions && card.remaining_group_sessions > 2;
                  }
                  
                  // 判断私教卡剩余课时
                  if ((card.card_type === '私教课' || card.card_type === 'private') && 
                      typeof card.remaining_private_sessions === 'number') {
                    hasEnoughSessions = hasEnoughSessions && card.remaining_private_sessions > 2;
                  }
                  
                  // 判断儿童团课卡剩余课时
                  if ((card.card_type === '儿童团课' || card.card_type === 'kids_group' || card.card_type === 'kids') && 
                      typeof card.remaining_kids_sessions === 'number') {
                    hasEnoughSessions = hasEnoughSessions && card.remaining_kids_sessions > 2;
                  }
                }
                
                return hasValidExpiry && hasEnoughSessions;
              });
              
              // 如果有正常的卡，添加到结果中
              if (hasActiveCard) {
                activeMemberIds.push(memberId);
              }
            });
            
            console.log(`找到 ${activeMemberIds.length} 个正常状态的会员`);
            
            // 如果找不到会员，直接返回空结果
            if (activeMemberIds.length === 0) {
              setResult({
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              });
              setLoading(false);
              return {
                members: [],
                totalCount: 0,
                currentPage: page,
                totalPages: 1
              };
            }
            
            // 使用处理后的会员ID列表继续查询
            query = query.in('id', activeMemberIds);
          }
        } catch (err) {
          console.error('到期状态筛选查询失败:', err);
        }
      }

      // 执行查询
      const { data, error: fetchError, count } = await query
        .order('id', { ascending: false })
        .range(start, end);

      if (fetchError) throw fetchError;

      // 更新结果
      const totalCount = count || 0;
      const totalPages = Math.ceil(totalCount / pageSize);

      setResult({
        members: data || [],
        totalCount,
        currentPage: page,
        totalPages
      });

      return {
        members: data || [],
        totalCount,
        currentPage: page,
        totalPages
      };
    } catch (err) {
      console.error('搜索会员失败:', err);
      setError('搜索会员失败，请重试');
      return {
        members: [],
        totalCount: 0,
        currentPage: 1,
        totalPages: 1
      };
    } finally {
      setLoading(false);
    }
  };

  const deleteMember = async (memberId: string) => {
    try {
      setLoading(true);

      // 1. 先获取该会员的所有会员卡ID
      const { data: memberCards, error: cardsQueryError } = await supabase
        .from('membership_cards')
        .select('id')
        .eq('member_id', memberId);

      if (cardsQueryError) {
        console.error('获取会员卡失败:', cardsQueryError);
        throw new Error(`获取会员卡失败: ${cardsQueryError.message}`);
      }

      const cardIds = memberCards?.map(card => card.id) || [];
      console.log('要删除的会员卡IDs:', cardIds);

      // 2. 删除所有相关的签到记录
      // 2.1 删除按member_id关联的签到记录
      const { error: memberCheckInsError } = await supabase
        .from('check_ins')
        .delete()
        .eq('member_id', memberId);

      if (memberCheckInsError) {
        console.error('删除会员签到记录失败:', memberCheckInsError);
        throw new Error(`删除会员签到记录失败: ${memberCheckInsError.message}`);
      }

      // 2.2 删除按card_id关联的签到记录
      if (cardIds.length > 0) {
        // 先检查是否还有相关的签到记录
        const { data: remainingCheckIns, error: checkError } = await supabase
          .from('check_ins')
          .select('id, card_id')
          .in('card_id', cardIds);

        if (checkError) {
          console.error('检查剩余签到记录失败:', checkError);
          throw new Error(`检查剩余签到记录失败: ${checkError.message}`);
        }

        console.log('剩余的签到记录:', remainingCheckIns);

        if (remainingCheckIns && remainingCheckIns.length > 0) {
          const { error: cardCheckInsError } = await supabase
            .from('check_ins')
            .delete()
            .in('card_id', cardIds);

          if (cardCheckInsError) {
            console.error('删除会员卡签到记录失败:', cardCheckInsError);
            throw new Error(`删除会员卡签到记录失败: ${cardCheckInsError.message}`);
          }
        }
      }

      // 3. 删除会员卡
      const { error: cardsError } = await supabase
        .from('membership_cards')
        .delete()
        .eq('member_id', memberId);

      if (cardsError) {
        console.error('删除会员卡失败:', cardsError);
        throw new Error(`删除会员卡失败: ${cardsError.message}`);
      }

      // 4. 删除会员
      const { error: memberError } = await supabase
        .from('members')
        .delete()
        .eq('id', memberId);

      if (memberError) {
        console.error('删除会员失败:', memberError);
        throw new Error(`删除会员失败: ${memberError.message}`);
      }

      // 更新本地状态
      setResult(prevResult => ({
        ...prevResult,
        members: prevResult.members.filter(m => m.id !== memberId),
        totalCount: Math.max(0, prevResult.totalCount - 1),
        totalPages: Math.ceil((prevResult.totalCount - 1) / defaultPageSize)
      }));

      // 如果当前页变空且不是第一页，则回到上一页
      if (result.members.length === 1 && result.currentPage > 1) {
        await searchMembers({ page: result.currentPage - 1 });
      } else {
        // 否则刷新当前页
        await searchMembers({ page: result.currentPage });
      }

      return { success: true };
    } catch (error) {
      console.error('Delete error:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const updateMember = async (memberId: string, updates: Partial<Member>) => {
    try {
      setLoading(true);

      const { error } = await supabase
        .from('members')
        .update(updates)
        .eq('id', memberId);

      if (error) throw error;

      // 更新本地状态
      setResult(prevResult => ({
        ...prevResult,
        members: prevResult.members.map(member =>
          member.id === memberId ? { ...member, ...updates } : member
        )
      }));

      return { success: true };
    } catch (error) {
      console.error('Update error:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    searchMembers();
  }, []);

  return {
    members: result.members,
    totalCount: result.totalCount,
    currentPage: result.currentPage,
    totalPages: result.totalPages,
    loading,
    error,
    searchMembers,
    deleteMember,
    updateMember
  };
}