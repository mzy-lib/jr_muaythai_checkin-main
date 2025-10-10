import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import Home from '../../pages/Home';
import GroupClassCheckIn from '../../pages/GroupClassCheckIn';
import PrivateClassCheckIn from '../../pages/PrivateClassCheckIn';
import KidsGroupClassCheckIn from '../../pages/KidsGroupClassCheckIn';
import AdminDashboard from '../../pages/AdminDashboard';
import AdminLogin from '../AdminLogin';
import Layout from '../layout/Layout';
import LoadingSpinner from '../common/LoadingSpinner';
import { MemberAuthProvider } from '../../contexts/MemberAuthContext';
import MemberRoute from './MemberRoute';
import MemberLayout from '../../pages/member/MemberLayout';
import MemberProfile from '../../pages/member/MemberProfile';
import MemberCard from '../../pages/member/MemberCard';
import MemberRecords from '../../pages/member/MemberRecords';
import MemberLogin from '../../pages/MemberLogin';

const AppRouter: React.FC = () => {
  const { user, loading, error } = useAuth();

  // 如果正在加载认证状态，显示加载动画
  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <BrowserRouter>
      <MemberAuthProvider>
        <Routes>
          {/* 主页 */}
          <Route path="/" element={<Home />} />

          {/* 团课签到 */}
          <Route path="/group-class" element={<GroupClassCheckIn />} />

          {/* 儿童团课签到 */}
          <Route path="/kids-group-class" element={<KidsGroupClassCheckIn />} />

          {/* 私教课签到 */}
          <Route path="/private-class" element={<PrivateClassCheckIn />} />

          {/* 会员登录 */}
          <Route path="/member-login" element={<MemberLogin />} />

          {/* 管理员路由 */}
          <Route path="/admin" element={<AdminLogin />} />
          <Route 
            path="/admin/dashboard" 
            element={user ? <AdminDashboard /> : <Navigate to="/admin" />} 
          />

          {/* 会员相关路由 */}
          <Route 
            path="/member" 
            element={
              <MemberRoute>
                <MemberLayout />
              </MemberRoute>
            }
          >
            <Route index element={<MemberProfile />} />
            <Route path="card" element={<MemberCard />} />
            <Route path="records" element={<MemberRecords />} />
          </Route>

          {/* 404页面 */}
          <Route path="*" element={<div>404 Not Found</div>} />
        </Routes>
      </MemberAuthProvider>
    </BrowserRouter>
  );
};

export default AppRouter;