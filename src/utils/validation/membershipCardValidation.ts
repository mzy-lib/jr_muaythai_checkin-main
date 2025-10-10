import { supabase } from '../../lib/supabase';
import { logger } from '../logger/core';

interface ValidateCardResult {
  isValid: boolean;
  cardId: string | null;
  reason?: string;
  details?: any;
}

/**
 * 验证会员卡
 * @param cardId 会员卡ID
 * @param memberId 会员ID
 * @param courseType 课程类型 ('private' | 'group' | 'kids_group')
 * @returns 验证结果
 */
export async function validateMembershipCard(
  cardId: string,
  memberId: string,
  courseType: 'private' | 'group' | 'kids_group'
): Promise<ValidateCardResult> {
  try {
    logger.info('开始验证会员卡', {
      cardId,
      memberId,
      courseType
    });

    // 调用数据库函数验证会员卡
    const { data: result, error } = await supabase.rpc(
      'check_card_validity',
      {
        p_card_id: cardId,
        p_member_id: memberId,
        p_class_type: courseType,
        p_check_in_date: new Date().toISOString().split('T')[0]
      }
    );

    if (error) {
      logger.error('会员卡验证失败', {
        error,
        cardId,
        memberId,
        courseType
      });
      return {
        isValid: false,
        cardId: null,
        reason: error.message
      };
    }

    if (!result || !result.is_valid) {
      logger.info('会员卡无效', {
        result,
        cardId,
        memberId,
        courseType
      });
      return {
        isValid: false,
        cardId: null,
        reason: result?.reason || '会员卡无效',
        details: result?.details
      };
    }

    logger.info('会员卡验证成功', {
      result,
      cardId,
      memberId,
      courseType
    });

    return {
      isValid: true,
      cardId: result.card_info?.card_id || null,
      details: result.card_info
    };
  } catch (err) {
    logger.error('会员卡验证异常', {
      error: err,
      cardId,
      memberId,
      courseType
    });
    return {
      isValid: false,
      cardId: null,
      reason: err instanceof Error ? err.message : '会员卡验证失败'
    };
  }
} 