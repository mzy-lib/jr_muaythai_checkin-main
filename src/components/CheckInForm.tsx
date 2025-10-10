import React, { useState, useEffect } from 'react';
import { CheckInFormData } from '../types/database';
import { validateCheckInForm } from '../utils/validation/formValidation';
import EmailVerification from './member/EmailVerification';
import CheckInFormFields from './member/CheckInFormFields';
import PrivateClassFields from './member/PrivateClassFields';
import { CheckInResult } from '../types/checkIn';

interface Props {
  onSubmit: (data: CheckInFormData) => Promise<CheckInResult>;
  courseType: 'group' | 'private' | 'kids_group';
  isNewMember?: boolean;
  requireEmail?: boolean;
  useCachedInfo?: boolean;
}

export default function CheckInForm({ onSubmit, courseType, isNewMember = false, requireEmail = true, useCachedInfo = false }: Props) {
  const [formData, setFormData] = useState<CheckInFormData>(() => ({
    name: '',
    email: '',
    timeSlot: courseType === 'kids_group' ? '10:30-12:00' : '',
    courseType,
    trainerId: '',
    is1v2: false
  }));
  const [needsEmailVerification, setNeedsEmailVerification] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (useCachedInfo) {
      const cachedUserInfo = localStorage.getItem('lastCheckinUser');
      if (cachedUserInfo) {
        try {
          const { name: cachedName, email: cachedEmail } = JSON.parse(cachedUserInfo);
          setFormData(prev => ({ ...prev, name: cachedName || '', email: cachedEmail || '' }));
        } catch (e) {
          console.error('Failed to parse cached user info:', e);
        }
      }
    }
    
    // 确保儿童团课的时间段始终为10:30-12:00
    if (courseType === 'kids_group') {
      setFormData(prev => ({ ...prev, timeSlot: '10:30-12:00' }));
    }
  }, [useCachedInfo, courseType]);

  function getCurrentTimeSlot(): string {
    const hour = new Date().getHours();
    if (hour < 12) {
      return '上午 Morning';
    } else if (hour < 18) {
      return '下午 Afternoon';
    } else {
      return '晚上 Evening';
    }
  }

  const handleFieldChange = (field: string, value: string | boolean) => {
    // 如果是儿童团课且尝试更改timeSlot，则忽略更改
    if (courseType === 'kids_group' && field === 'timeSlot') {
      return;
    }
    
    setFormData(prev => ({ ...prev, [field]: value }));
    setError('');
    if (needsEmailVerification) {
      setNeedsEmailVerification(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    // 标准化课程类型确保匹配数据库枚举值
    const standardizedCourseType = courseType === 'kids_group' 
      ? 'kids_group' // 确保使用枚举中存在的值
      : courseType === 'group' 
        ? (new Date().getHours() < 12 ? 'morning' : 'evening') 
        : courseType;
    
    // 确保儿童团课在提交时使用正确的时间段和类型
    const finalFormData = {
      ...formData,
      courseType: standardizedCourseType,
      timeSlot: courseType === 'kids_group' ? '10:30-12:00' : formData.timeSlot
    };
    
    try {
      const result = await onSubmit(finalFormData);
      console.log('签到结果:', result);
      
      if (!result) {
        throw new Error('签到返回结果为空');
      }
      
      if (result.success) {
        try {
          localStorage.setItem('lastCheckinUser', JSON.stringify({
            name: formData.name,
            email: formData.email
          }));
        } catch (e) {
          console.error('保存用户信息失败:', e);
        }
        
        if (result.isDuplicate) {
          setError(result.message || '今天已经在此时段签到过，此次为重复签到。');
        } else {
          setError('');
        }
      } else if (result.needsEmailVerification) {
        setNeedsEmailVerification(true);
        setError('');
      } else {
        setError(result.message || '签到失败。Check-in failed.');
      }
    } catch (error) {
      console.error('表单提交错误:', { 
        error, 
        errorMessage: error instanceof Error ? error.message : '未知错误',
        formData: finalFormData 
      });
      setError(error instanceof Error ? error.message : '签到失败，请重试');
    } finally {
      setLoading(false);
    }
  };

  const handleEmailVerification = async (email: string) => {
    setFormData(prev => ({ ...prev, email }));
    try {
      // 标准化课程类型
      const standardizedCourseType = courseType === 'kids_group' 
        ? 'kids_group'
        : courseType === 'group' 
          ? (new Date().getHours() < 12 ? 'morning' : 'evening')
          : courseType;
        
      // 确保使用标准化的课程类型
      const result = await onSubmit({
        ...formData,
        email,
        courseType: standardizedCourseType,
        timeSlot: courseType === 'kids_group' ? '10:30-12:00' : formData.timeSlot,
        trainerId: courseType === 'private' ? formData.trainerId : '',
        is1v2: courseType === 'private' ? formData.is1v2 : false
      });

      if (!result || !result.success) {
        setError(result?.message || '邮箱验证失败。Email verification failed.');
        if (result?.needsEmailVerification) {
          setNeedsEmailVerification(true);
        }
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : '邮箱验证失败，请重试。Email verification failed, please try again.';
      setError(errorMessage);
      setNeedsEmailVerification(true);
    }
  };

  if (needsEmailVerification) {
    return (
      <EmailVerification
        memberName={formData.name.trim()}
        onSubmit={handleEmailVerification}
        onCancel={() => {
          setNeedsEmailVerification(false);
          setFormData(prev => ({ ...prev, email: '' }));
          setError('');
        }}
      />
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <CheckInFormFields
        name={formData.name}
        email={formData.email}
        timeSlot={formData.timeSlot}
        loading={loading}
        isNewMember={isNewMember}
        onChange={handleFieldChange}
        showTimeSlot={courseType === 'group' || courseType === 'kids_group'}
        courseType={courseType}
      />

      {courseType === 'private' && (
        <PrivateClassFields
          trainerId={formData.trainerId}
          timeSlot={formData.timeSlot}
          is1v2={formData.is1v2}
          loading={loading}
          onChange={handleFieldChange}
        />
      )}

      {error && (
        <div className="text-red-600 text-sm">{error}</div>
      )}

      <button
        type="submit"
        disabled={loading}
        className={`w-full py-2 px-4 rounded-lg text-white transition-colors ${
          loading ? 'bg-gray-400 cursor-not-allowed' : 
          courseType === 'private' ? 'bg-[#EA4335] hover:bg-red-600' : 'bg-[#4285F4] hover:bg-blue-600'
        }`}
      >
        {loading ? '签到中... Checking in...' : '签到 Check-in'}
      </button>
    </form>
  );
}