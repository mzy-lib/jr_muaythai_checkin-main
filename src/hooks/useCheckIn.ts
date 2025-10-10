import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { CheckInFormData } from '../types/database';
import { messages } from '../utils/messageUtils';
import { findMemberForCheckIn } from '../utils/member/search';
import { checkInLogger } from '../utils/logger/checkIn';
import { logger } from '../utils/logger/core';
import { validateMembershipCard } from '../utils/validation/membershipCardValidation';

interface CheckInResult {
  success: boolean;
  isExtra?: boolean;
  message: string;
  isDuplicate?: boolean;
  isNewMember?: boolean;
  courseType: string;
  needsEmailVerification?: boolean;
  existingMember?: boolean;
}

export function useCheckIn() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 根据时间段确定课程类型
  const getClassTypeFromTimeSlot = (timeSlot: string): 'morning' | 'evening' => {
    console.log('转换时间段:', timeSlot);
    
    // 精确匹配常见时间格式
    if (timeSlot === '9:00-10:30' || timeSlot === '09:00-10:30') {
      return 'morning';
    } else if (timeSlot === '17:00-18:30') {
      return 'evening';
    } else if (timeSlot === '10:30-12:00') {
      // 添加对儿童团课时间段的支持
      return 'morning';
    }
    
    // 模糊匹配以增强鲁棒性
    if (timeSlot.includes('9:') || timeSlot.includes('09:') || 
        timeSlot.includes('10:') || timeSlot.includes('11:') ||
        timeSlot.toLowerCase().includes('morning') || 
        timeSlot.includes('上午')) {
      return 'morning';
    }
    
    // 默认返回evening
    return 'evening';
  };

  const submitCheckIn = async (formData: CheckInFormData): Promise<CheckInResult> => {
    let result;
    
    try {
      setLoading(true);
      setError(null);

      logger.info('开始签到流程', { 
        name: formData.name, 
        email: formData.email,
        timeSlot: formData.timeSlot,
        courseType: formData.courseType
      });

      // Find member
      result = await findMemberForCheckIn({
        name: formData.name,
        email: formData.email
      });

      logger.info('会员搜索结果', {
        result,
        is_new: result.is_new,
        member_id: result.member_id
      });

      // 如果需要邮箱验证
      if (result.needs_email) {
        return {
          success: false,
          message: '发现多个同名会员，请输入邮箱以验证身份。\nMultiple members found with the same name, please enter email to verify.',
          needsEmailVerification: true,
          courseType: formData.courseType
        };
      }

      // 验证私教课必填参数
      if (formData.courseType === 'private') {
        if (!formData.trainerId) {
          throw new Error('私教课签到需要选择教练');
        }
        if (formData.is1v2 === undefined) {
          throw new Error('私教课签到需要指定是否为1v2课程');
        }
      }

      // 新会员处理 - 如果没有member_id，表示是新会员，需要注册
      if (!result.member_id) {
        logger.info('检测到新会员，开始注册流程', {
          name: formData.name,
          email: formData.email,
          courseType: formData.courseType,
          timeSlot: formData.timeSlot
        });
        
        // 验证时间段
        if (!formData.timeSlot) {
          throw new Error('签到时需要选择时间段');
        }
        
        // 验证教练ID格式(如果是私教课)
        if (formData.courseType === 'private' && formData.trainerId && 
            !formData.trainerId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
          logger.error('无效的trainer_id格式', { trainer_id: formData.trainerId });
          throw new Error('无效的教练ID格式');
        }
        
        // 构造register_new_member参数
        const registerParams = {
          p_name: formData.name,
          p_email: formData.email || '',  // 确保email不为null
          p_class_type: formData.courseType === 'kids_group' ? 'kids_group' : // 儿童团课
                       formData.courseType === 'private' ? 'private' :      // 私教课
                       getClassTypeFromTimeSlot(formData.timeSlot),         // 普通团课
          p_is_private: formData.courseType === 'private',
          p_trainer_id: formData.courseType === 'private' ? formData.trainerId : null,
          p_time_slot: formData.timeSlot,
          p_is_1v2: formData.courseType === 'private' ? !!formData.is1v2 : false
        };
        
        logger.info('调用register_new_member注册新会员', registerParams);
        
        const { data: registerResult, error: registerError } = await supabase.rpc(
          'register_new_member',
          registerParams
        );
        
        if (registerError) {
          logger.error('新会员注册失败', { 
            error: registerError,
            params: registerParams
          });
          throw new Error(registerError.message || '新会员注册失败');
        }
        
        if (!registerResult || !registerResult.success) {
          logger.error('新会员注册返回数据无效', { registerResult });
          throw new Error('新会员注册失败，返回数据无效');
        }
        
        logger.info('新会员注册成功', registerResult);
        
        return {
          success: true,
          isNewMember: true,
          isExtra: true, // 新会员默认为额外签到
          message: '签到成功！Check-in successful!',
          courseType: formData.courseType
        };
      }

      let validCardId = null;
      if (!result.is_new) {
        // 获取会员的有效卡
        const { data: cards } = await supabase
          .from('membership_cards')
          .select('*')
          .eq('member_id', result.member_id)
          .gte('valid_until', new Date().toISOString().split('T')[0])
          .order('valid_until', { ascending: true });

        // 根据课程类型筛选合适的卡
        const validCard = cards?.find(card => {
          if (formData.courseType === 'private') {
            // 兼容私教课不同类型名称: "private"或"私教课"
            return (card.card_type === 'private' || card.card_type === '私教课') && 
                   card.remaining_private_sessions > 0;
          } else if (formData.courseType === 'kids_group') {
            return card.card_type === '儿童团课' && card.remaining_kids_sessions > 0;
          } else {
            // 兼容团课不同类型名称: "group"或"class"或"团课" 
            return (card.card_type === 'group' || card.card_type === 'class' || card.card_type === '团课') && (
              (card.card_category === 'session' && card.remaining_group_sessions > 0) ||
              card.card_category === 'monthly'
            );
          }
        });

        if (validCard) {
          const cardValidation = await validateMembershipCard(
            validCard.id,
            result.member_id,
            formData.courseType
          );
          if (cardValidation.isValid) {
            validCardId = cardValidation.cardId;
          }
        }
      }

      // 验证member_id格式
      if (!result.member_id?.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
        logger.error('无效的member_id格式', { member_id: result.member_id });
        throw new Error('无效的会员ID格式');
      }

      // 验证trainer_id格式(如果存在)
      if (formData.courseType === 'private' && formData.trainerId && 
          !formData.trainerId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
        logger.error('无效的trainer_id格式', { trainer_id: formData.trainerId });
        throw new Error('无效的教练ID格式');
      }

      // 验证card_id格式(如果存在)
      if (validCardId && !validCardId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
        logger.error('无效的card_id格式', { card_id: validCardId });
        throw new Error('无效的会员卡ID格式');
      }

      // 根据课程类型和时间段确定class_type
      let classType: 'morning' | 'evening' | 'private' | 'kids group';
      if (formData.courseType === 'private') {
        classType = 'private';
      } else if (formData.courseType === 'kids_group') {
        classType = 'kids group';
        // 确保儿童团课时间段正确
        if (formData.timeSlot !== '10:30-12:00') {
          logger.error('无效的儿童团课时间段', { timeSlot: formData.timeSlot });
          throw new Error('无效的儿童团课时段。Invalid kids group class time slot.');
        }
      } else {
        classType = getClassTypeFromTimeSlot(formData.timeSlot);
      }

      // 验证日期格式
      const checkInDate = new Date().toISOString().split('T')[0];
      if (!checkInDate.match(/^\d{4}-\d{2}-\d{2}$/)) {
        logger.error('无效的日期格式', { checkInDate });
        throw new Error('无效的日期格式');
      }

      logger.info('参数验证通过', {
        member_id: result.member_id,
        trainer_id: formData.trainerId,
        card_id: validCardId,
        class_type: classType,
        check_in_date: checkInDate,
        time_slot: formData.timeSlot,
        is_1v2: formData.is1v2
      });

      // 构造RPC调用参数
      const rpcParams = {
        p_member_id: result.member_id,
        p_name: formData.name,
        p_email: formData.email || null,
        p_card_id: validCardId,
        p_class_type: classType,
        p_check_in_date: checkInDate,
        p_time_slot: formData.timeSlot || null,
        p_trainer_id: formData.courseType === 'private' ? formData.trainerId : null,
        p_is_1v2: formData.courseType === 'private' ? !!formData.is1v2 : false
      };

      logger.info('准备调用handle_check_in', rpcParams);

      try {
        const response = await supabase.rpc(
          'handle_check_in',
          rpcParams
        );
        
        logger.info('handle_check_in原始响应', response);
        
        const { data: checkInResult, error: checkInError } = response;
        
        if (checkInError) {
          logger.error('签到错误', { 
            error: checkInError,
            code: checkInError.code,
            hint: checkInError.hint,
            details: checkInError.details,
            message: checkInError.message,
            params: rpcParams
          });
          
          // 当检测到重复签到时
          if (checkInError.message?.includes('今天已经在这个时段签到过了')) {
            return {
              success: true,  // 将成功标志设为true，因为这是允许的行为
              isDuplicate: true,
              message: '您今天已在此时段签到，此次为重复签到。课时将被再次扣除。',
              courseType: formData.courseType
            };
          }

          return {
            success: false,
            message: checkInError.message || messages.checkIn.error,
            courseType: formData.courseType
          };
        }

        // Ensure checkInResult exists
        if (!checkInResult) {
          logger.error('签到结果为空', { params: rpcParams });
          return {
            success: false,
            message: messages.checkIn.error,
            courseType: formData.courseType
          };
        }

        // 检查返回的JSON格式
        logger.info('签到返回结果', {
          rawResult: checkInResult,
          resultType: typeof checkInResult,
          hasSuccess: typeof checkInResult === 'object' && 'success' in checkInResult,
          hasMessage: typeof checkInResult === 'object' && 'message' in checkInResult
        });

        // 安全检查checkInResult的格式
        try {
          if (typeof checkInResult !== 'object' || checkInResult === null) {
            logger.error('签到结果格式无效，不是对象', { checkInResult });
            return {
              success: false,
              message: '签到结果格式无效',
              courseType: formData.courseType
            };
          }

          if (!('success' in checkInResult)) {
            logger.error('签到结果无效，缺少success字段', { checkInResult });
            return {
              success: false,
              message: '签到结果格式无效，缺少必要字段',
              courseType: formData.courseType
            };
          }

          if (!checkInResult.success) {
            logger.error('签到结果显示失败', { checkInResult });
            return {
              success: false,
              message: checkInResult.message || messages.checkIn.error,
              courseType: formData.courseType
            };
          }

          // 正常处理成功结果
          logger.info('签到成功', { 
            checkInResult,
            isExtra: checkInResult.isExtra,
            isNewMember: checkInResult.isNewMember,
            member_id: result.member_id
          });

          // Return result based on checkInResult
          const finalResult = {
            success: true,
            isExtra: checkInResult.isExtra,
            isNewMember: checkInResult.isNewMember,
            isDuplicate: false,
            courseType: formData.courseType,
            message: checkInResult.message || (checkInResult.isExtra 
              ? (formData.courseType === 'private' 
                 ? messages.checkIn.extraCheckInPrivate 
                 : formData.courseType === 'kids_group'
                   ? '儿童团课额外签到成功！\nKids group class extra check-in successful!'
                   : messages.checkIn.extraCheckInGroup)
              : formData.courseType === 'private'
                ? '私教课签到成功！课时已扣除。\nPrivate class check-in successful! Session deducted.'
                : formData.courseType === 'kids_group'
                  ? '儿童团课签到成功！课时已扣除。\nKids group class check-in successful! Session deducted.'
                  : messages.checkIn.success)
          };

          logger.info('签到结果', finalResult);
          return finalResult;
        } catch (unexpectedError) {
          // 捕获处理签到结果时的任何意外错误
          logger.error('处理签到结果时发生意外错误', { 
            unexpectedError, 
            checkInResult,
            params: rpcParams 
          });
          return {
            success: false,
            message: '处理签到结果时发生错误',
            courseType: formData.courseType
          };
        }
      } catch (apiError) {
        logger.error('调用handle_check_in API异常', apiError);
        return {
          success: false,
          message: '签到服务暂时不可用，请稍后再试',
          courseType: formData.courseType
        };
      }

    } catch (err) {
      const errorDetails = {
        error: err instanceof Error ? err.message : 'Unknown error',
        name: formData.name,
        timeSlot: formData.timeSlot,
        courseType: formData.courseType,
        trainerId: formData.trainerId,
        is1v2: formData.is1v2,
        stack: err instanceof Error ? err.stack : undefined,
        fullError: JSON.stringify(err, Object.getOwnPropertyNames(err))
      };
      
      console.error('签到失败', errorDetails);
      logger.error('签到失败', errorDetails);
      
      let errorMessage: string;
      if (err instanceof Error) {
        errorMessage = err.message;
      } else if (typeof err === 'object' && err !== null) {
        errorMessage = (err as any).message || messages.checkIn.error;
      } else {
        errorMessage = messages.checkIn.error;
      }
      
      setError(errorMessage);
      
      // 返回标准格式的CheckInResult对象
      return {
        success: false,
        message: errorMessage,
        isNewMember: result?.is_new,
        isExtra: true,
        courseType: formData.courseType
      };
    } finally {
      setLoading(false);
    }
  };

  const checkIn = async (data: CheckInFormData) => {
    try {
      // 确保API请求中包含kids_group类型处理
      const response = await fetch('/api/check-in', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...data,
          // 儿童团课时段固定为10:30-12:00
          timeSlot: data.courseType === 'kids_group' ? '10:30-12:00' : data.timeSlot
        })
      });
      
      return await response.json();
    } catch (error) {
      console.error('签到失败:', error);
      return { success: false, error: '签到请求失败' };
    }
  };

  return {
    submitCheckIn,
    loading,
    error
  };
}