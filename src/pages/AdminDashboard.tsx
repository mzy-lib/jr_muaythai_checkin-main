import React, { useState, useEffect } from 'react';
import { Shield, Users, CalendarCheck, AlertCircle, Home } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import AdminLogin from '../components/AdminLogin';
import NetworkError from '../components/common/NetworkError';
import LoadingSpinner from '../components/common/LoadingSpinner';
import { supabase } from '../lib/supabase';
import { Link } from 'react-router-dom';

// 直接导入所有组件
import MemberList from '../components/admin/MemberList';
import CheckInRecordsList from '../components/admin/CheckInRecordsList';
import ExcelImport from '../components/admin/ExcelImport';
import DataExport from '../components/admin/DataExport';
import TrainerList from '../components/admin/TrainerList';
import Overview from '../components/admin/Overview';

type ActiveTab = 'overview' | 'members' | 'checkins' | 'trainers' | 'import' | 'export';

type DashboardStats = {
  totalMembers: number;
  todayCheckins: number;
  extraCheckins: number;
  expiringMembers: number;
};

export default function AdminDashboard() {
  const { user, loading, error, retry } = useAuth();
  const [activeTab, setActiveTab] = useState<ActiveTab>('overview');
  const [stats, setStats] = useState<DashboardStats>({
    totalMembers: 0,
    todayCheckins: 0,
    extraCheckins: 0,
    expiringMembers: 0
  });
  const [statsLoading, setStatsLoading] = useState(true);

  useEffect(() => {
    if (user) {
      fetchDashboardStats();
    }
  }, [user]);

  const fetchDashboardStats = async () => {
    try {
      setStatsLoading(true);
      
      // 获取今日日期（设置为当天开始）
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      // 获取7天后的日期（设置为当天结束）
      const sevenDaysLater = new Date();
      sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);
      sevenDaysLater.setHours(23, 59, 59, 999);

      // 格式化日期
      const todayStr = today.toISOString();
      const sevenDaysLaterStr = sevenDaysLater.toISOString();

      // 并行获取各项统计数据
      const [
        { count: totalMembers },
        { count: todayCheckins },
        { count: extraCheckins },
        { count: expiringMembers }
      ] = await Promise.all([
        // 总会员数
        supabase
          .from('members')
          .select('*', { count: 'exact', head: true }),
        
        // 今日签到数
        supabase
          .from('check_ins')
          .select('*', { count: 'exact', head: true })
          .gte('created_at', todayStr),
        
        // 额外签到数
        supabase
          .from('check_ins')
          .select('*', { count: 'exact', head: true })
          .eq('is_extra', true)
          .gte('created_at', todayStr),
        
        // 即将过期会员数（从membership_cards表查询）
        supabase
          .from('membership_cards')
          .select('member_id', { count: 'exact', head: true })
          .not('valid_until', 'is', null)
          .lte('valid_until', sevenDaysLaterStr)
          .gt('valid_until', todayStr)
          .order('valid_until', { ascending: true })
      ]);

      setStats({
        totalMembers: totalMembers || 0,
        todayCheckins: todayCheckins || 0,
        extraCheckins: extraCheckins || 0,
        expiringMembers: expiringMembers || 0
      });
    } catch (err) {
      console.error('Failed to fetch dashboard stats:', err);
    } finally {
      setStatsLoading(false);
    }
  };

  if (loading) return <LoadingSpinner />;
  if (error) return <NetworkError onRetry={retry} />;
  if (!user) return <AdminLogin onSuccess={() => window.location.reload()} />;

  const tabs = [
    { id: 'overview', label: '数据概览' },
    { id: 'members', label: '会员管理' },
    { id: 'checkins', label: '签到记录' },
    { id: 'trainers', label: '教练管理' },
    { id: 'import', label: '数据导入' },
    { id: 'export', label: '数据导出' },
  ];

  const StatCard = ({ title, value, icon: Icon, color }: { 
    title: string;
    value: number;
    icon: typeof Users;
    color: string;
  }) => (
    <div className="bg-white p-6 rounded-lg shadow-sm">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="mt-2 text-3xl font-semibold text-gray-900">{value}</p>
        </div>
        <div className={`p-3 rounded-full ${color}`}>
          <Icon className="w-6 h-6 text-white" />
        </div>
      </div>
    </div>
  );

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <div className="flex items-center space-x-2">
          <Shield className="w-8 h-8 text-[#4285F4]" />
          <span className="text-xl font-medium">管理后台</span>
        </div>
        <Link to="/" className="flex items-center space-x-1 px-4 py-2 bg-gray-100 text-gray-600 hover:bg-gray-200 rounded-lg transition-colors">
          <Home className="w-5 h-5" />
          <span>返回主页</span>
        </Link>
      </div>
      
      <div className="flex space-x-4 mb-8">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as ActiveTab)}
            className={`px-4 py-2 rounded-lg ${
              activeTab === tab.id
                ? 'bg-[#4285F4] text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === 'overview' && <Overview stats={stats} />}
      {activeTab === 'members' && <MemberList />}
      {activeTab === 'checkins' && <CheckInRecordsList />}
      {activeTab === 'trainers' && <TrainerList />}
      {activeTab === 'import' && <ExcelImport />}
      {activeTab === 'export' && <DataExport />}
    </div>
  );
}