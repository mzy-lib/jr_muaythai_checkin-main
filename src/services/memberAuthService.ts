import { supabase } from '../lib/supabase';

interface LoginResult {
  success: boolean;
  error?: string;
  member?: any;
}

export const login = async (name: string, email: string): Promise<LoginResult> => {
  try {
    // 查询会员表验证信息
    const { data, error } = await supabase
      .from('members')
      .select('*')
      .eq('name', name)
      .eq('email', email)
      .single();

    if (error) {
      console.error('Login error:', error);
      return {
        success: false,
        error: '登录失败，请重试'
      };
    }

    if (!data) {
      return {
        success: false,
        error: '会员信息不存在，请检查姓名和邮箱是否正确'
      };
    }

    // 登录成功，将会员信息存储到本地
    localStorage.setItem('member', JSON.stringify(data));

    return {
      success: true,
      member: data
    };
  } catch (err) {
    console.error('Login error:', err);
    return {
      success: false,
      error: '登录过程中出现错误，请重试'
    };
  }
};

export const logout = () => {
  localStorage.removeItem('member');
};

export const getCurrentMember = () => {
  const memberStr = localStorage.getItem('member');
  if (!memberStr) return null;
  try {
    return JSON.parse(memberStr);
  } catch {
    return null;
  }
}; 