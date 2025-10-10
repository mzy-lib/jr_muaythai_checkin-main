import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { MuayThaiIcon } from '../components/icons/MuayThaiIcon';
import MemberProfile from '../components/member/MemberProfile';
import CheckInRecords from '../components/member/CheckInRecords';
import LoadingSpinner from '../components/common/LoadingSpinner';
import ErrorMessage from '../components/common/ErrorMessage';
import { useMember } from '../hooks/useMember';

export default function MemberDashboard() {
  const { memberId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { member, loading, error } = useMember(memberId || '');

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} />;
  if (!member) {
    navigate('/');
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-100 py-12 px-4">
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="text-center mb-8">
          <MuayThaiIcon />
          <h1 className="text-2xl font-bold">会员中心 Member Dashboard</h1>
        </div>
        
        <MemberProfile member={member} />
        {user && <CheckInRecords memberId={member.id} />}
      </div>
    </div>
  );
}