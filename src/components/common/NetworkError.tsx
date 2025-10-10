import React from 'react';
import { WifiOff } from 'lucide-react';

interface Props {
  onRetry: () => void;
}

export default function NetworkError({ onRetry }: Props) {
  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full text-center">
        <WifiOff className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h2 className="text-xl font-bold mb-2">网络连接错误 Network Error</h2>
        <p className="text-gray-600 mb-6">
          无法连接到服务器，请检查网络连接后重试。
          <br />
          Unable to connect to server. Please check your network connection and try again.
        </p>
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors"
        >
          重试 Retry
        </button>
      </div>
    </div>
  );
}