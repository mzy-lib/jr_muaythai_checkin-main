import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { NewMemberFormData } from '../types/database';
import { useNewMemberCheckIn } from '../hooks/useNewMemberCheckIn';
import CheckInForm from '../components/CheckInForm';
import CheckInResult from '../components/member/CheckInResult';
import { MuayThaiIcon } from '../components/icons/MuayThaiIcon';
import LoadingSpinner from '../components/common/LoadingSpinner';
import ErrorMessage from '../components/common/ErrorMessage';
import ExistingMemberPrompt from '../components/member/ExistingMemberPrompt';
import NetworkError from '../components/common/NetworkError';

export default function NewMemberCheckIn() {
  const navigate = useNavigate();
  const { submitNewMemberCheckIn, loading, error } = useNewMemberCheckIn();
  const [courseType, setCourseType] = useState<'group' | 'private'>('group');
  const [checkInStatus, setCheckInStatus] = useState<{
    success: boolean;
    isExtra?: boolean;
    message: string;
    existingMember?: boolean;
  } | null>(null);

  // Auto redirect after successful check-in
  useEffect(() => {
    if (checkInStatus?.success) {
      const timer = setTimeout(() => {
        navigate('/');
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [checkInStatus?.success, navigate]);

  const handleSubmit = async (formData: NewMemberFormData) => {
    try {
      const result = await submitNewMemberCheckIn(formData);
      setCheckInStatus(result);
    } catch (err) {
      console.error('Check-in error:', err);
      setCheckInStatus({
        success: false,
        message: err instanceof Error ? err.message : '签到失败，请重试。Check-in failed, please try again.'
      });
    }
  };

  const handleCourseTypeChange = (type: 'group' | 'private') => {
    setCourseType(type);
  };

  return (
    <div className="min-h-screen bg-gray-100 py-12 px-4">
      <div className="max-w-md mx-auto bg-white rounded-lg shadow-lg p-8">
        <div className="text-center mb-8">
          <MuayThaiIcon />
          <h1 className="text-2xl font-bold mb-2">新会员签到 New Member Check-in</h1>
          <p className="text-gray-600">欢迎来到JR泰拳馆！Welcome to JR Muay Thai!</p>
        </div>

        {error && <ErrorMessage message={error} />}
        
        {checkInStatus ? (
          <CheckInResult status={checkInStatus} />
        ) : (
          <>
            {loading ? (
              <LoadingSpinner />
            ) : (
              <>
                <div className="mb-6">
                  <div className="flex justify-center space-x-4">
                    <button
                      type="button"
                      onClick={() => handleCourseTypeChange('group')}
                      className={`px-4 py-2 rounded-lg ${
                        courseType === 'group' 
                          ? 'bg-[#4285F4] text-white' 
                          : 'bg-gray-200 text-gray-700'
                      }`}
                    >
                      团课 Group Class
                    </button>
                    <button
                      type="button"
                      onClick={() => handleCourseTypeChange('private')}
                      className={`px-4 py-2 rounded-lg ${
                        courseType === 'private' 
                          ? 'bg-[#EA4335] text-white' 
                          : 'bg-gray-200 text-gray-700'
                      }`}
                    >
                      私教 Private Class
                    </button>
                  </div>
                </div>
                <CheckInForm 
                  onSubmit={handleSubmit} 
                  isNewMember={true} 
                  requireEmail={true}
                  courseType={courseType}
                />
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}