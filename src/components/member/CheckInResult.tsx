import React from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle, AlertCircle } from 'lucide-react';

interface Props {
  status: {
    success: boolean;
    isExtra?: boolean;
    isNewMember?: boolean;
    message: string;
    existingMember?: boolean;
    needsEmailVerification?: boolean;
    isDuplicate?: boolean;
    courseType?: 'private' | 'group';
  };
}

export default function CheckInResult({ status }: Props) {
  // 根据签到状态生成标题
  const getTitle = () => {
    if (status.existingMember) {
      return '会员已存在 Member Exists';
    }
    if (!status.success) {
      if (status.needsEmailVerification) {
        return '重名会员提醒 Duplicate Name Alert';
      }
      if (status.isDuplicate) {
        return '重复签到提醒 Duplicate Check-in';
      }
      return '签到失败 Check-in Failed';
    }
    if (status.isExtra) {
      return status.courseType === 'private' 
        ? '签到成功！Private Class Check-in Success!'
        : '签到成功！Check-in Success!';
    }
    return status.courseType === 'private'
      ? '私教课签到成功！Private Class Check-in Success!'
      : '签到成功！Check-in Success!';
  };

  // 根据签到状态生成图标颜色
  const getIconColor = () => {
    if (!status.success) return 'text-yellow-500';
    return 'text-green-500'; // 所有成功签到都使用绿色
  };

  // 根据签到状态生成消息样式
  const getMessageStyle = () => {
    if (!status.success) return 'text-red-600';
    return 'text-gray-600'; // 所有成功签到都使用相同文本颜色
  };

  return (
    <div className="text-center py-8">
      {status.existingMember ? (
        <>
          <AlertCircle className="w-16 h-16 mx-auto mb-4 text-yellow-500" />
          <h2 className="text-xl font-semibold mb-2">{getTitle()}</h2>
          <p className="text-gray-600 mb-6 whitespace-pre-line">{status.message}</p>
          <Link
            to="/member"
            className="inline-block px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors"
          >
            前往会员签到 Go to Member Check-in
          </Link>
        </>
      ) : status.success ? (
        <>
          <CheckCircle className={`w-16 h-16 mx-auto mb-4 ${getIconColor()}`} />
          <h2 className="text-xl font-semibold mb-2">{getTitle()}</h2>
          <p className={`mb-6 whitespace-pre-line ${getMessageStyle()}`}>{status.message}</p>
          <p className="text-sm text-gray-500">
            页面将在3秒后自动返回首页...
            <br />
            Redirecting to home page in 3 seconds...
          </p>
        </>
      ) : (
        <>
          <AlertCircle className="w-16 h-16 mx-auto mb-4 text-yellow-500" />
          <h2 className="text-xl font-semibold mb-2">{getTitle()}</h2>
          <p className="text-gray-600 mb-6 whitespace-pre-line">{status.message}</p>
          <Link
            to="/"
            className="inline-block px-4 py-2 bg-[#EA4335] text-white rounded-lg hover:bg-red-600 transition-colors"
          >
            返回首页 Return Home
          </Link>
        </>
      )}
    </div>
  );
}