import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckInFormData } from '../types/database';
import { useCheckIn } from '../hooks/useCheckIn';
import CheckInForm from '../components/CheckInForm';
import { MuayThaiIcon } from '../components/icons/MuayThaiIcon';
import LoadingSpinner from '../components/common/LoadingSpinner';
import ErrorMessage from '../components/common/ErrorMessage';
import CheckInResult from '../components/member/CheckInResult';
import NetworkError from '../components/common/NetworkError';
import { CheckInResult as CheckInResultType } from '../types/checkIn';

interface CheckInStatus extends CheckInResultType {
  courseType: 'kids_group';
}

export default function KidsGroupClassCheckIn() {
  const navigate = useNavigate();
  const { submitCheckIn, loading, error } = useCheckIn();
  const [checkInStatus, setCheckInStatus] = useState<CheckInStatus | null>(null);
  const [networkError, setNetworkError] = useState(false);
  
  // 添加缓存用户信息的功能
  useEffect(() => {
    // 从localStorage获取上次使用的用户信息
    const cachedUserInfo = localStorage.getItem('lastCheckinUser');
    if (cachedUserInfo) {
      try {
        const { name, email } = JSON.parse(cachedUserInfo);
        // 缓存的用户信息会在CheckInForm组件中使用
      } catch (e) {
        console.error('Failed to parse cached user info:', e);
      }
    }
  }, []);

  const handleSubmit = async (formData: CheckInFormData) => {
    try {
      // 缓存用户信息到localStorage
      localStorage.setItem('lastCheckinUser', JSON.stringify({
        name: formData.name,
        email: formData.email
      }));
      
      const result = await submitCheckIn({
        ...formData,
        courseType: 'kids_group',  // 标记为儿童团课签到
        timeSlot: '10:30-12:00'    // 儿童团课固定时段
      });

      // 确保结果包含courseType
      const finalResult = {
        ...result,
        courseType: 'kids_group' as const
      };
      
      setCheckInStatus(finalResult);

      if (finalResult.success && !finalResult.isExtra) {
        // 成功且不是额外签到时，3秒后返回首页
        setTimeout(() => {
          navigate('/');
        }, 3000);
      }
      
    } catch (err) {
      if (err instanceof Error && 
          (err.message.includes('Failed to fetch') || 
           err.message.includes('Network error'))) {
        setNetworkError(true);
      }
    }
  };

  if (networkError) {
    return <NetworkError onRetry={() => window.location.reload()} />;
  }

  return (
    <div className="min-h-screen bg-gray-100 py-12 px-4">
      <div className="max-w-md mx-auto bg-white rounded-lg shadow-lg p-8">
        <div className="text-center mb-8">
          <MuayThaiIcon className="w-32 h-32 mx-auto mb-6" />
          <h1 className="text-2xl font-bold mb-2">儿童团课签到 Kids Group Class Check-in</h1>
          <p className="text-gray-600">
            请输入姓名和邮箱进行签到
            <br />
            Please enter your name and email to check in
          </p>
        </div>

        {error && <ErrorMessage message={error} />}
        {checkInStatus ? (
          <CheckInResult status={checkInStatus} />
        ) : (
          loading ? <LoadingSpinner /> : (
            <CheckInForm 
              onSubmit={handleSubmit}
              courseType="kids_group"
              useCachedInfo={true} // 启用使用缓存信息
            />
          )
        )}

        {/* 额外签到时显示返回首页按钮 */}
        {checkInStatus?.success && checkInStatus.isExtra && (
          <div className="mt-4 text-center">
            <button
              onClick={() => navigate('/')}
              className="inline-block px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors"
            >
              返回首页 Return Home
            </button>
          </div>
        )}
      </div>
    </div>
  );
} 