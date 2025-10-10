import React from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { User, CreditCard, ClipboardList } from 'lucide-react';

// 定义泰拳主题色
const MUAYTHAI_RED = '#D32F2F';
const MUAYTHAI_BLUE = '#1559CF';

const MemberLayout: React.FC = () => {
  const location = useLocation();
  
  // 判断当前路径是否匹配
  const isActive = (path: string) => {
    if (path === '/member') {
      return location.pathname === '/member';
    }
    return location.pathname.startsWith(path);
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="max-w-7xl mx-auto">
        <div className="flex">
          {/* 侧边导航栏 */}
          <div className="w-64 bg-white shadow-sm min-h-screen p-4 border-r-4 border-r-[#1559CF]">
            <div className="mb-6 text-center">
              <img 
                src="/jr-logo.webp" 
                alt="JR泰拳馆 JR Muay Thai Gym" 
                className="w-32 h-32 mx-auto mb-2"
              />
            </div>
            <nav className="space-y-2">
              {/* 会员信息导航项 */}
              <div className={`flex items-center p-2 rounded-lg ${isActive('/member') ? 'bg-blue-600 text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
                <NavLink to="/member" end className="flex items-center w-full">
                  <User className="w-5 h-5 mr-2 flex-shrink-0" />
                  <span className="block">会员信息 Profile</span>
                </NavLink>
              </div>

              {/* 会员卡导航项 */}
              <div className={`flex items-center p-2 rounded-lg ${isActive('/member/card') ? 'bg-blue-600 text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
                <NavLink to="/member/card" className="flex items-center w-full">
                  <CreditCard className="w-5 h-5 mr-2 flex-shrink-0" />
                  <span className="block">会员卡 Cards</span>
                </NavLink>
              </div>

              {/* 签到记录导航项 */}
              <div className={`flex items-center p-2 rounded-lg ${isActive('/member/records') ? 'bg-blue-600 text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
                <NavLink to="/member/records" className="flex items-center w-full">
                  <ClipboardList className="w-5 h-5 mr-2 flex-shrink-0" />
                  <span className="block">签到记录 Check-ins</span>
                </NavLink>
              </div>
            </nav>
          </div>

          {/* 主内容区域 */}
          <main className="flex-1 p-4">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
};

export default MemberLayout; 