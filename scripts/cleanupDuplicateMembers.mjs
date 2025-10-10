import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function cleanupDuplicateMembers() {
  try {
    // 1. 删除指定会员的签到记录
    const { error: checkInsError } = await supabase
      .from('check_ins')
      .delete()
      .eq('member_id', (
        await supabase
          .from('members')
          .select('id')
          .eq('name', '批量测试95')
      ).data[0].id);

    if (checkInsError) {
      console.error('删除签到记录失败:', checkInsError);
      return;
    }

    // 2. 删除指定会员
    const { error: memberError } = await supabase
      .from('members')
      .delete()
      .eq('name', '批量测试95');

    if (memberError) {
      console.error('删除会员失败:', memberError);
      return;
    }

    console.log('成功删除会员及其签到记录');
  } catch (error) {
    console.error('清理过程中出错:', error);
  }
}

cleanupDuplicateMembers(); 