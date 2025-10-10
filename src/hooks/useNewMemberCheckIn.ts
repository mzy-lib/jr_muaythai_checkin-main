import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { CheckInFormData, DatabaseError } from '../types/database';
import { CheckInResult } from '../types/checkIn';
import { formatTimeSlot } from '../utils/dateUtils';
import { messages } from '../utils/messageUtils';
import { validateNewMemberForm } from '../utils/validation/formValidation';
import { findMemberForCheckIn } from '../utils/member/search';
import { debugMemberSearch } from '../utils/debug/memberSearch';

export function useNewMemberCheckIn() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleError = (error: DatabaseError) => {
    console.error('Check-in error:', error);
    console.error('Error details:', {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });
    
    let errorMessage = messages.error;
    
    if (error.message) {
      if (error.code === 'PGRST202') {
        errorMessage = messages.databaseError;
      } else if (error.hint === 'invalid_name') {
        errorMessage = messages.validation.invalidName;
      } else if (error.hint === 'member_exists') {
        errorMessage = messages.memberExists;
      } else if (error.hint === 'email_exists') {
        errorMessage = messages.validation.emailExists;
      } else if (error.hint === 'time_slot_required') {
        errorMessage = '请选择有效的时间段';
      } else if (error.hint === 'invalid_time_slot_format') {
        errorMessage = '无效的时间段格式';
      } else if (error.hint === 'invalid_time_slot') {
        errorMessage = '无效的团课时段';
      } else {
        errorMessage = error.message;
      }
    }
    
    setError(errorMessage);
    return errorMessage;
  };

  const submitNewMemberCheckIn = async (formData: CheckInFormData): Promise<CheckInResult> => {
    setLoading(true);
    setError(null);

    try {
      console.log('提交新会员签到:', formData);

      // 格式化时间段
      const timeSlot = formatTimeSlot(formData.timeSlot);
      const isPrivate = formData.courseType === 'private';
      
      // 确定class_type参数
      const classType = formData.courseType === 'kids_group' ? 'kids group' : // 儿童团课
                       formData.courseType === 'private' ? 'private' :      // 私教课
                       timeSlot.includes('9:00') || timeSlot.includes('09:00') || timeSlot.includes('10:30') ? 'morning' : 'evening';
      
      // 调用后端函数注册新会员
      const { data, error } = await supabase.rpc('register_new_member', {
        p_name: formData.name.trim(),
        p_email: formData.email.trim(),
        p_class_type: classType,
        p_is_private: isPrivate,
        p_trainer_id: isPrivate ? formData.trainerId : null,
        p_time_slot: timeSlot,
        p_is_1v2: isPrivate ? formData.is1v2 : false
      });

      if (error) {
        console.error('新会员签到错误:', error);
        
        // 处理特定错误
        if (error.message.includes('already registered') || error.hint === 'member_exists') {
          return {
            success: false,
            message: '该姓名已被注册。This name is already registered.',
            existingMember: true
          };
        }
        
        if (error.hint === 'email_exists') {
          return {
            success: false,
            message: '该邮箱已被注册。This email is already registered.',
            existingMember: true
          };
        }

        throw new Error(error.message);
      }

      console.log('新会员签到成功:', data);
      
      return {
        success: true,
        message: '签到成功！Check-in successful!',
        isNewMember: true,
        isExtra: true
      };
    } catch (err) {
      console.error('新会员签到处理错误:', err);
      
      const errorMessage = err instanceof Error 
        ? err.message 
        : '签到失败，请重试。Check-in failed, please try again.';
      
      setError(errorMessage);
      
      return {
        success: false,
        message: errorMessage
      };
    } finally {
      setLoading(false);
    }
  };

  return {
    submitNewMemberCheckIn,
    loading,
    error
  };
}