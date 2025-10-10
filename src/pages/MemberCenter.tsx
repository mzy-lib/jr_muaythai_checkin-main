import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMemberAuth } from '../contexts/MemberAuthContext';
import { useMemberData } from '../hooks/useMemberData';

export default function MemberCenter() {
  const { isAuthenticated, member, setMember } = useMemberAuth();
  const { memberInfo, memberCards, checkInHistory, loading, error } = useMemberData();
  const navigate = useNavigate();

  // 如果未登录，重定向到登录页面
  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/member-login');
    }
  }, [isAuthenticated, navigate]);

  if (!isAuthenticated) {
    return null; // 未登录时不渲染内容
  }

  const handleLogout = () => {
    setMember(null);
    localStorage.removeItem('member');
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8 flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gray-900">
            {member?.name} 的个人中心
          </h1>
          <button
            onClick={handleLogout}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
          >
            退出登录
          </button>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {loading ? (
          <div className="text-center py-12">
            <div className="spinner"></div>
            <p className="mt-4 text-gray-600">加载中...</p>
          </div>
        ) : error ? (
          <div className="rounded-md bg-red-50 p-4 my-4">
            <div className="flex">
              <div className="ml-3">
                <h3 className="text-sm font-medium text-red-800">加载失败</h3>
                <div className="mt-2 text-sm text-red-700">
                  <p>{error}</p>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {/* 会员基本信息 */}
            <div className="bg-white shadow overflow-hidden sm:rounded-lg">
              <div className="px-4 py-5 sm:px-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900">会员信息</h3>
                <p className="mt-1 max-w-2xl text-sm text-gray-500">个人详细信息</p>
              </div>
              <div className="border-t border-gray-200">
                <dl>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">姓名</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{memberInfo?.name}</dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">邮箱</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{memberInfo?.email}</dd>
                  </div>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">电话</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{memberInfo?.phone || '未设置'}</dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">最近签到</dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                      {memberInfo?.last_check_in_date ? new Date(memberInfo.last_check_in_date).toLocaleDateString() : '无签到记录'}
                    </dd>
                  </div>
                </dl>
              </div>
            </div>

            {/* 会员卡信息 */}
            <div className="bg-white shadow overflow-hidden sm:rounded-lg">
              <div className="px-4 py-5 sm:px-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900">会员卡信息</h3>
                <p className="mt-1 max-w-2xl text-sm text-gray-500">您的会员卡和剩余课时</p>
              </div>
              <div className="border-t border-gray-200">
                {memberCards.length > 0 ? (
                  <ul className="divide-y divide-gray-200">
                    {memberCards.map((card) => (
                      <li key={card.id} className="px-4 py-4">
                        <div className="flex justify-between">
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {card.card_type} {card.card_category} {card.card_subtype}
                              {card.trainer_type && ` (${card.trainer_type})`}
                            </p>
                            <p className="text-sm text-gray-500">
                              {card.card_type === '团课' ? 
                                `剩余团课: ${card.remaining_group_sessions ?? '未设置'}` : 
                                `剩余私教: ${card.remaining_private_sessions ?? '未设置'}`}
                              {card.valid_until && ` | 有效期至: ${new Date(card.valid_until).toLocaleDateString()}`}
                            </p>
                          </div>
                          <div className="flex items-center">
                            <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              new Date(card.valid_until) > new Date() ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                            }`}>
                              {new Date(card.valid_until) > new Date() ? '有效' : '已过期'}
                            </span>
                          </div>
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <div className="px-4 py-5 text-sm text-gray-500">
                    暂无会员卡信息
                  </div>
                )}
              </div>
            </div>

            {/* 签到历史 */}
            <div className="bg-white shadow overflow-hidden sm:rounded-lg">
              <div className="px-4 py-5 sm:px-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900">签到历史</h3>
                <p className="mt-1 max-w-2xl text-sm text-gray-500">最近的签到记录</p>
              </div>
              <div className="border-t border-gray-200">
                {checkInHistory.length > 0 ? (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            日期
                          </th>
                          <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            课程类型
                          </th>
                          <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            教练
                          </th>
                          <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            状态
                          </th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {checkInHistory.map((checkIn) => (
                          <tr key={checkIn.id}>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {new Date(checkIn.check_in_date).toLocaleDateString()}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {checkIn.class_type === 'morning' ? '早课' : 
                               checkIn.class_type === 'evening' ? '晚课' : 
                               checkIn.class_type === 'private' ? '私教课' : checkIn.class_type}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {checkIn.trainers?.name || '-'}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                                checkIn.is_extra ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800'
                              }`}>
                                {checkIn.is_extra ? '额外签到' : '正常签到'}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <div className="px-4 py-5 text-sm text-gray-500">
                    暂无签到记录
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
} 