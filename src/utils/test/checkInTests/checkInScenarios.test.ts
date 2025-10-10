import { describe, it, expect, beforeAll } from 'vitest';
import { supabase } from '../../../lib/supabase';
import { MembershipType } from '../../../types/database';

// 测试数据
const testMembers = [
  {
    name: '新会员测试',
    email: 'new.member.test@example.com',
    is_new_member: true
  },
  {
    name: '单次课程会员',
    email: 'single.class.test@example.com',
    membership: 'single_class' as MembershipType,
    remaining_classes: 1,
    membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30天后过期
  },
  {
    name: '月卡单日会员',
    email: 'monthly.single.test@example.com',
    membership: 'single_monthly' as MembershipType,
    membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  },
  {
    name: '月卡双日会员',
    email: 'monthly.double.test@example.com',
    membership: 'double_monthly' as MembershipType,
    membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  },
  {
    name: '过期会员',
    email: 'expired.test@example.com',
    membership: 'single_monthly' as MembershipType,
    membership_expiry: new Date(Date.now() - 24 * 60 * 60 * 1000) // 已过期
  },
  {
    name: '无剩余课时会员',
    email: 'no.classes.test@example.com',
    membership: 'single_class' as MembershipType,
    remaining_classes: 0,
    membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  }
];

// 辅助函数：创建会员
async function createTestMember(member: typeof testMembers[0]) {
  const { data, error } = await supabase
    .from('members')
    .insert([member])
    .select()
    .single();
  
  if (error) throw error;
  return data;
}

// 辅助函数：签到
async function checkIn(memberId: string, classType: 'morning' | 'evening') {
  const { data, error } = await supabase
    .from('check_ins')
    .insert([{
      member_id: memberId,
      class_type: classType
    }])
    .select('is_extra')
    .single();
  
  if (error) throw error;
  return data;
}

describe('签到场景测试', () => {
  // 在所有测试开始前创建测试会员
  beforeAll(async () => {
    // 清理已存在的测试数据
    await supabase
      .from('check_ins')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    await supabase
      .from('members')
      .delete()
      .like('email', '%.test@example.com');

    // 创建测试会员
    for (const member of testMembers) {
      await createTestMember(member);
    }
  });

  describe('新会员签到', () => {
    it('新会员首次签到应标记为额外签到', async () => {
      const member = await supabase
        .from('members')
        .select()
        .eq('email', 'new.member.test@example.com')
        .single();
      
      const result = await checkIn(member.data.id, 'morning');
      expect(result.is_extra).toBe(true);
    });

    it('新会员签到后应更新状态为非新会员', async () => {
      const { data: member } = await supabase
        .from('members')
        .select()
        .eq('email', 'new.member.test@example.com')
        .single();
      
      expect(member.is_new_member).toBe(false);
    });
  });

  describe('单次课程会员签到', () => {
    it('有剩余课时时应正常签到', async () => {
      const member = await supabase
        .from('members')
        .select()
        .eq('email', 'single.class.test@example.com')
        .single();
      
      const result = await checkIn(member.data.id, 'morning');
      expect(result.is_extra).toBe(false);
    });

    it('签到后应减少剩余课时', async () => {
      const { data: member } = await supabase
        .from('members')
        .select()
        .eq('email', 'single.class.test@example.com')
        .single();
      
      expect(member.remaining_classes).toBe(0);
    });
  });

  describe('月卡会员签到', () => {
    describe('单日月卡', () => {
      it('首次签到应正常签到', async () => {
        const member = await supabase
          .from('members')
          .select()
          .eq('email', 'monthly.single.test@example.com')
          .single();
        
        const result = await checkIn(member.data.id, 'morning');
        expect(result.is_extra).toBe(false);
      });

      it('同一天第二次签到应标记为额外签到', async () => {
        const member = await supabase
          .from('members')
          .select()
          .eq('email', 'monthly.single.test@example.com')
          .single();
        
        const result = await checkIn(member.data.id, 'evening');
        expect(result.is_extra).toBe(true);
      });
    });

    describe('双日月卡', () => {
      it('首次签到应正常签到', async () => {
        const member = await supabase
          .from('members')
          .select()
          .eq('email', 'monthly.double.test@example.com')
          .single();
        
        const result = await checkIn(member.data.id, 'morning');
        expect(result.is_extra).toBe(false);
      });

      it('同一天第二次签到应正常签到', async () => {
        const member = await supabase
          .from('members')
          .select()
          .eq('email', 'monthly.double.test@example.com')
          .single();
        
        const result = await checkIn(member.data.id, 'evening');
        expect(result.is_extra).toBe(false);
      });

      it('同一天第三次签到应标记为额外签到', async () => {
        const member = await supabase
          .from('members')
          .select()
          .eq('email', 'monthly.double.test@example.com')
          .single();
        
        const result = await checkIn(member.data.id, 'morning');
        expect(result.is_extra).toBe(true);
      });
    });
  });

  describe('特殊情况', () => {
    it('过期会员签到应标记为额外签到', async () => {
      const member = await supabase
        .from('members')
        .select()
        .eq('email', 'expired.test@example.com')
        .single();
      
      const result = await checkIn(member.data.id, 'morning');
      expect(result.is_extra).toBe(true);
    });

    it('无剩余课时会员签到应标记为额外签到', async () => {
      const member = await supabase
        .from('members')
        .select()
        .eq('email', 'no.classes.test@example.com')
        .single();
      
      const result = await checkIn(member.data.id, 'morning');
      expect(result.is_extra).toBe(true);
    });

    it('同一时段重复签到应抛出错误', async () => {
      const member = await supabase
        .from('members')
        .select()
        .eq('email', 'monthly.single.test@example.com')
        .single();
      
      await expect(async () => {
        await checkIn(member.data.id, 'morning');
        await checkIn(member.data.id, 'morning');
      }).rejects.toThrow();
    });
  });
}); 