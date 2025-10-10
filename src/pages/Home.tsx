import React from 'react';
import { Link } from 'react-router-dom';
import { Shield, User } from 'lucide-react';
import { MuayThaiIcon } from '../components/icons/MuayThaiIcon';

export default function Home() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        <div className="text-center mb-8">
          <MuayThaiIcon className="w-32 h-32 mx-auto mb-6" />
          <h1 className="text-2xl font-bold mb-2">JR泰拳馆签到系统</h1>
          <p className="text-gray-600">JR Muay Thai Check-in System</p>
        </div>

        <div className="space-y-4">
          {/* 团课签到入口 */}
          <Link
            to="/group-class"
            className="block w-full"
          >
            <div className="bg-[#4285F4] text-white rounded-lg p-4 hover:bg-blue-600 transition-colors">
              <div className="flex flex-col items-center space-y-1">
                <span className="text-lg font-medium">团课签到</span>
                <span className="text-lg font-medium">Group Class Check-in</span>
              </div>
            </div>
          </Link>

          {/* 私教课签到入口 */}
          <Link
            to="/private-class"
            className="block w-full"
          >
            <div className="bg-[#EA4335] text-white rounded-lg p-4 hover:bg-red-600 transition-colors">
              <div className="flex flex-col items-center space-y-1">
                <span className="text-lg font-medium">私教签到</span>
                <span className="text-lg font-medium">Private Class Check-in</span>
              </div>
            </div>
          </Link>

          {/* 儿童团课签到入口 */}
          <Link
            to="/kids-group-class"
            className="block w-full"
          >
            <div className="bg-[#34A853] text-white rounded-lg p-4 hover:bg-green-600 transition-colors">
              <div className="flex flex-col items-center space-y-1">
                <span className="text-lg font-medium">儿童团课签到</span>
                <span className="text-lg font-medium">Kids Group Class Check-in</span>
              </div>
            </div>
          </Link>
        </div>

        {/* 会员登录入口 - 新增 */}
        <div className="mt-8 text-center">
          <Link
            to="/member-login"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
          >
            <User className="w-5 h-5" />
            <span>会员登录 Member Login</span>
          </Link>
        </div>

        {/* 管理员登录入口 */}
        <div className="mt-4 text-center">
          <Link
            to="/admin"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
          >
            <Shield className="w-5 h-5" />
            <span>管理员登录 Admin Login</span>
          </Link>
        </div>
      </div>
    </div>
  );
}