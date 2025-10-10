import { supabase } from '../../../lib/supabase';

export async function cleanupTestData() {
  // Delete check-ins first due to foreign key constraints
  await supabase
    .from('check_ins')
    .delete()
    .match({ member_id: 'in', 
      select: 'id', 
      from: 'members',
      where: { email: 'like', value: '%.test.mt@example.com' }
    });

  // Then delete test members
  await supabase
    .from('members')
    .delete()
    .like('email', '%.test.mt@example.com');
}

export async function setupTestData() {
  await cleanupTestData();

  // Re-insert test data
  const testMembers = [
    {
      name: '张三',
      email: 'zhang.san.test.mt@example.com',
      membership: 'single_monthly',
      remaining_classes: 0,
      membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      is_new_member: false
    },
    {
      name: '李四',
      email: 'li.si.test.mt@example.com', 
      membership: 'double_monthly',
      remaining_classes: 0,
      membership_expiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
      is_new_member: false
    },
    {
      name: '王小明',
      email: 'wang.xm1.test.mt@example.com',
      membership: 'ten_classes',
      remaining_classes: 3,
      is_new_member: false
    },
    {
      name: '王小明',
      email: 'wang.xm2.test.mt@example.com',
      membership: 'single_monthly',
      remaining_classes: 0,
      membership_expiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
      is_new_member: false
    },
    {
      name: '新学员',
      email: 'new.member.test.mt@example.com',
      membership: null,
      remaining_classes: 0,
      is_new_member: true
    }
  ];

  for (const member of testMembers) {
    await supabase.from('members').insert(member);
  }
}