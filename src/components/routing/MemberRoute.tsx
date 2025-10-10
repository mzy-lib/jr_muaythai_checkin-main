import React from 'react';
import { Navigate } from 'react-router-dom';
import { useMemberAuth } from '../../contexts/MemberAuthContext';

interface MemberRouteProps {
  children: React.ReactNode;
}

export default function MemberRoute({ children }: MemberRouteProps) {
  const { isAuthenticated } = useMemberAuth();

  if (!isAuthenticated) {
    // 如果未登录，重定向到会员登录页面
    return <Navigate to="/member-login" replace />;
  }

  return <>{children}</>;
} 