import React, { useState } from 'react';
import { Shield } from 'lucide-react';
import { signInAdmin } from '../utils/adminUtils';
import { useAuth } from '../hooks/useAuth';
import { useNavigate } from 'react-router-dom';

interface AdminLoginProps {
  onSuccess?: () => void;
}

export default function AdminLogin({ onSuccess }: AdminLoginProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const { retry } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const result = await signInAdmin({ username: email, password });
      console.log('Login result:', result); // 添加调试日志

      if (result.success) {
        // 使用replace: true确保不能返回登录页
        navigate('/admin/dashboard', { replace: true });
      } else {
        setError(result.error || '登录失败，请重试。Login failed, please try again.');
      }
    } catch (err) {
      console.error('Login error:', err); // 添加调试日志
      setError(err instanceof Error ? err.message : '登录失败，请重试。Login failed, please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center py-12 px-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-8">
        <div className="text-center mb-8">
          <Shield className="w-12 h-12 text-muaythai-blue mx-auto mb-4" />
          <h1 className="text-2xl font-bold">管理员登录 Admin Login</h1>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              邮箱 Email
            </label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              disabled={loading}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              密码 Password
            </label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              disabled={loading}
            />
          </div>

          {error && (
            <div className="text-red-600 text-sm">{error}</div>
          )}

          <button
            type="submit"
            className="w-full bg-[#4285F4] text-white py-2 px-4 rounded-lg hover:bg-blue-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={loading}
          >
            {loading ? '登录中... Logging in...' : '登录 Login'}
          </button>
        </form>
      </div>
    </div>
  );
}