import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckInFormData } from '../types/database';
import { useCheckIn } from '../hooks/useCheckIn';
import CheckInForm from '../components/CheckInForm';
import { MuayThaiIcon } from '../components/icons/MuayThaiIcon';
import LoadingSpinner from '../components/common/LoadingSpinner';
import ErrorMessage from '../components/common/ErrorMessage';
import CheckInResult from '../components/member/CheckInResult';
import NetworkError from '../components/common/NetworkError';

interface CheckInStatus {
  success: boolean;
  isExtra?: boolean;
  message: string;
  isDuplicate?: boolean;
  isNewMember?: boolean;
}

export default function MemberCheckIn() {
  const navigate = useNavigate();
  const { submitCheckIn, loading, error } = useCheckIn();
  const [checkInStatus, setCheckInStatus] = useState<CheckInStatus | null>(null);
  const [networkError, setNetworkError] = useState(false);

  const handleSubmit = async (formData: CheckInFormData) => {
    try {
      const result = await submitCheckIn(formData);
      setCheckInStatus(result);

      if (result.success) {
        // Redirect after successful check-in
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
          <MuayThaiIcon />
          <h1 className="text-2xl font-bold mb-2">会员签到 Member Check-in</h1>
          <p className="text-gray-600">欢迎回来！Welcome back!</p>
        </div>

        {error && <ErrorMessage message={error} />}
        {checkInStatus ? (
          <CheckInResult status={checkInStatus} />
        ) : (
          loading ? <LoadingSpinner /> : <CheckInForm onSubmit={handleSubmit} />
        )}
      </div>
    </div>
  );
}