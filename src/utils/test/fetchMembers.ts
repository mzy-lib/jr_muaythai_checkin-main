import { supabase } from '../../lib/supabase';

/**
 * 查询会员数据
 */
export async function checkMembersData() {
  try {
    // 查询会员总数
    const { count: membersCount, error: countError } = await supabase
      .from('members')
      .select('*', { count: 'exact', head: true });

    if (countError) {
      console.error('获取会员总数失败:', countError);
      return;
    }

    console.log(`数据库中共有 ${membersCount} 个会员`);

    // 查询部分会员数据
    const { data: membersData, error: membersError } = await supabase
      .from('members')
      .select('id, name, email, phone')
      .order('created_at', { ascending: false })
      .limit(10);

    if (membersError) {
      console.error('获取会员数据失败:', membersError);
      return;
    }

    console.log('最近添加的10个会员:', membersData);

    // 查询会员卡总数
    const { count: cardsCount, error: cardsCountError } = await supabase
      .from('membership_cards')
      .select('*', { count: 'exact', head: true });

    if (cardsCountError) {
      console.error('获取会员卡总数失败:', cardsCountError);
      return;
    }

    console.log(`数据库中共有 ${cardsCount} 张会员卡`);

    // 查询同一会员拥有多张会员卡的情况
    const { data: duplicateCards, error: duplicateError } = await supabase
      .from('membership_cards')
      .select(`
        member_id,
        card_type,
        card_subtype,
        members!inner(name, email)
      `)
      .order('member_id');

    if (duplicateError) {
      console.error('获取会员卡数据失败:', duplicateError);
      return;
    }

    // 分析每个会员的卡片情况
    const memberCards = {};
    duplicateCards.forEach(card => {
      const memberId = card.member_id;
      if (!memberCards[memberId]) {
        memberCards[memberId] = {
          name: card.members.name,
          email: card.members.email,
          cards: []
        };
      }
      memberCards[memberId].cards.push({
        card_type: card.card_type,
        card_subtype: card.card_subtype
      });
    });

    // 筛选出拥有相同类型和子类型卡片的会员
    const membersWithDuplicateCards = Object.entries(memberCards)
      .filter(([_, data]) => {
        const cards = data.cards;
        // 检查是否有重复的卡类型和子类型
        const cardSignatures = new Set();
        for (const card of cards) {
          const signature = `${card.card_type}|${card.card_subtype}`;
          if (cardSignatures.has(signature)) {
            return true;
          }
          cardSignatures.add(signature);
        }
        return false;
      })
      .map(([memberId, data]) => ({
        memberId,
        ...data
      }));

    if (membersWithDuplicateCards.length > 0) {
      console.log('拥有重复类型和子类型会员卡的会员:', membersWithDuplicateCards);
    } else {
      console.log('没有发现会员拥有完全相同类型和子类型的会员卡');
    }

    return {
      membersCount,
      cardsCount,
      membersWithDuplicateCards
    };
  } catch (error) {
    console.error('数据查询出错:', error);
  }
} 