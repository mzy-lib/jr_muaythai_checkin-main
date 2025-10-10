import { createClient } from '@supabase/supabase-js';
import type { Member, CheckIn, MembershipCard } from '../types/database';

// 定义数据库类型
interface Database {
  public: {
    Tables: {
      members: {
        Row: Member
        Insert: Omit<Member, 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Omit<Member, 'id'>>
      }
      membership_cards: {
        Row: MembershipCard
        Insert: Omit<MembershipCard, 'id' | 'created_at'>
        Update: Partial<Omit<MembershipCard, 'id'>>
      }
      check_ins: {
        Row: CheckIn
        Insert: Omit<CheckIn, 'id' | 'created_at'>
        Update: Partial<Omit<CheckIn, 'id'>>
      }
    }
  }
}

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient<Database>(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    }
  }
);

// 添加 checkAuth 函数
export const checkAuth = async () => {
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) {
      console.error('[Auth] 获取会话失败:', error);
      throw error;
    }

    if (!session) {
      console.log('[Auth] 未登录');
      return null;
    }

    console.log('[Auth] 已登录:', session.user.email);
    return session;
  } catch (error) {
    console.error('[Auth] 检查认证状态失败:', error);
    return null;
  }
};

// 添加认证状态变化监听
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') {
    console.log('[Auth] 已登录:', session?.user?.email);
  } else if (event === 'SIGNED_OUT') {
    console.log('[Auth] 已登出');
  }
});
