import React, { useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import { validateEmail } from '../../utils/validation/emailValidation';
import { messages } from '../../utils/messageUtils';

interface Props {
  memberName: string;
  onSubmit: (email: string) => Promise<void>;
  onCancel: () => void;
}

export default function EmailVerification({ memberName, onSubmit, onCancel }: Props) {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validateEmail(email)) {
      setError(messages.validation.invalidEmail);
      return;
    }

    setError('');
    setLoading(true);

    try {
      await onSubmit(email.trim());
    } catch (err) {
      setError(err instanceof Error ? err.message : messages.checkIn.error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="animate-fadeIn">
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
        <h3 className="font-medium text-yellow-800 mb-2">
          检测到重名会员 Duplicate Name Detected
        </h3>
        <p className="text-yellow-700 mb-2">
          系统中存在多个名为"{memberName}"的会员记录。
          <br />
          Multiple members found with the name "{memberName}".
        </p>
        <p className="text-yellow-700">
          请输入您的邮箱以验证身份。
          <br />
          Please enter your email to verify your identity.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            邮箱 Email
          </label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md"
            placeholder="请输入邮箱 Please enter email"
            required
            disabled={loading}
            autoFocus
          />
        </div>

        {error && (
          <div className="text-red-600 text-sm">{error}</div>
        )}

        <div className="flex justify-between items-center pt-2">
          <button
            type="button"
            onClick={onCancel}
            className="flex items-center gap-1 text-gray-600 hover:text-gray-800"
            disabled={loading}
          >
            <ArrowLeft className="w-4 h-4" />
            返回重新输入姓名 Back to enter name
          </button>
          <button
            type="submit"
            className="px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors disabled:opacity-50"
            disabled={loading}
          >
            {loading ? '验证中... Verifying...' : '验证 Verify'}
          </button>
        </div>
      </form>
    </div>
  );
}