import { supabase } from '../lib/supabase';

// 定义常量
const ADMIN_EMAILS = ['admin@jrmuaythai.com'];

// 定义类型
interface AdminLoginCredentials {
  username: string;
  password: string;
}

interface AdminLoginResult {
  success: boolean;
  error?: string;
  admin?: {
    email: string;
    id: string;
  };
}

export async function signInAdmin({ username, password }: AdminLoginCredentials): Promise<AdminLoginResult> {
  try {
    if (!username) {
      throw new Error('请输入邮箱地址 Please enter email address');
    }

    // 使用正确的Supabase认证API
    const { data, error } = await supabase.auth.signInWithPassword({
      email: username.trim(),
      password: password
    });

    if (error) {
      console.error('Authentication error:', error);
      throw new Error(`登录失败：${error.message}`);
    }

    if (!data?.user?.email) {
      throw new Error('登录失败：未找到用户邮箱 Login failed: Email not found');
    }

    // 验证是否是管理员邮箱（不区分大小写）
    const userEmail = data.user.email.toLowerCase();
    if (!ADMIN_EMAILS.includes(userEmail)) {
      console.log('Attempting login with:', userEmail);
      console.log('Allowed admin emails:', ADMIN_EMAILS);
      throw new Error('该账号没有管理员权限 No admin privileges');
    }

    // 存储管理员状态
    localStorage.setItem('isAdmin', 'true');
    localStorage.setItem('adminToken', data.session?.access_token || '');
    localStorage.setItem('adminEmail', data.user.email);

    return {
      success: true,
      admin: {
        email: data.user.email,
        id: data.user.id
      }
    };

  } catch (error) {
    console.error('Admin login error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : '未知错误 Unknown error'
    };
  }
}

export async function signOutAdmin(): Promise<void> {
  localStorage.removeItem('isAdmin');
  localStorage.removeItem('adminToken');
  localStorage.removeItem('adminEmail');
  await supabase.auth.signOut();
}

export function isAdminLoggedIn(): boolean {
  const isAdminFlag = localStorage.getItem('isAdmin');
  if (isAdminFlag !== 'true') {
    return false;
  }

  const adminEmail = localStorage.getItem('adminEmail');
  if (!adminEmail) {
    return false;
  }

  return ADMIN_EMAILS.includes(adminEmail.toLowerCase());
}

export function getCurrentAdmin(): { email: string | null; token: string | null } | null {
  if (!isAdminLoggedIn()) {
    return null;
  }

  return {
    email: localStorage.getItem('adminEmail'),
    token: localStorage.getItem('adminToken')
  };
}