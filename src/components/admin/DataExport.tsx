import React, { useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Member, CheckIn, MembershipCard } from '../../types/database';
import { format } from 'date-fns';
import { Download } from 'lucide-react';
import LoadingSpinner from '../common/LoadingSpinner';

type MemberRecord = {
  [key: string]: string;
  姓名: string;
  邮箱: string;
  会员卡类型: string;
  剩余团课课时: string;
  剩余私教课时: string;
  剩余儿童团课课时: string;
  会员卡到期日: string;
  注册时间: string;
  最后签到时间: string;
};

type CheckInRecord = {
  [key: string]: string;
  会员姓名: string;
  会员邮箱: string;
  上课时段: string;
  课程性质: string;
  教练: string;
  课程类型: string;
  签到时间: string;
  签到类型: string;
};

export default function DataExport() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 添加判断儿童团课的辅助函数
  const isKidsGroupClass = (classType: any): boolean => {
    if (!classType) return false;
    
    // 对于字符串类型，进行精确匹配
    if (typeof classType === 'string') {
      const typeStr = classType.toLowerCase();
      return typeStr === 'kids group' || typeStr.includes('kids') || typeStr.includes('儿童');
    }
    
    // 对于可能的其他类型（如对象），尝试转换为字符串
    try {
      const typeStr = String(classType).toLowerCase();
      return typeStr === 'kids group' || typeStr.includes('kids') || typeStr.includes('儿童');
    } catch (e) {
      return false;
    }
  };

  const getCardTypeText = (card: MembershipCard) => {
    // 标准化卡类型
    const cardType = standardizeCardType(card.card_type ?? null);
    const cardCategory = standardizeCardCategory(card.card_category ?? null);
    const cardSubtype = standardizeCardSubtype(card.card_subtype ?? null);
    
    // 儿童团课处理
    if (cardType === '儿童团课') {
      if (cardSubtype === '10次卡') {
        return '儿童团课10次卡 Kids Ten Classes';
      }
      return '儿童团课卡 Kids Class';
    }
    // 团课处理
    else if (cardType === '团课') {
      if (cardCategory === '月卡') {
        if (cardSubtype === '单次月卡') {
          return '团课单次月卡 Single Monthly';
        } else if (cardSubtype === '双次月卡') {
          return '团课双次月卡 Double Monthly';
        }
      } else { // 课时卡或其他类别
        if (cardSubtype === '单次卡') {
          return '团课单次卡 Single Class';
        } else if (cardSubtype === '两次卡') {
          return '团课两次卡 Two Classes';
        } else if (cardSubtype === '10次卡') {
          return '团课10次卡 Ten Classes';
        }
      }
    } 
    // 私教课处理
    else if (cardType === '私教课') {
      if (cardSubtype === '单次卡') {
        return '私教单次卡 Single Private';
      } else if (cardSubtype === '10次卡') {
        const trainerType = card.trainer_type;
        if (trainerType) {
          return `私教10次卡 Ten Private (${trainerType === 'jr' ? 'JR教练' : '高级教练'})`;
        }
        return '私教10次卡 Ten Private';
      }
    }
    
    // 如果没有匹配上面的规则，返回完整名称
    let name = '';
    if (cardType) {
      name = cardType;
      if (cardSubtype) {
        name += ` ${cardSubtype}`;
      }
      if (cardType === '私教课' && card.trainer_type) {
        name += ` (${card.trainer_type === 'jr' ? 'JR教练' : '高级教练'})`;
      }
    }
    
    return name || '未知卡类型';
  };
  
  // 标准化卡类型函数
  function standardizeCardType(cardType: string | null): string {
    if (!cardType) return '';
    
    const lowerType = cardType.toLowerCase();
    
    if (lowerType.includes('kids') || lowerType.includes('儿童')) {
      return '儿童团课';
    } else if (lowerType === 'class' || lowerType === 'group' || lowerType.includes('团课')) {
      return '团课';
    } else if (lowerType === 'private' || lowerType.includes('私教')) {
      return '私教课';
    }
    
    return cardType;
  }
  
  // 标准化卡类别函数
  function standardizeCardCategory(cardCategory: string | null): string {
    if (!cardCategory) return '';
    
    const lowerCategory = cardCategory.toLowerCase();
    
    if (lowerCategory === 'session' || lowerCategory === 'sessions' || lowerCategory.includes('课时')) {
      return '课时卡';
    } else if (lowerCategory === 'monthly' || lowerCategory.includes('月')) {
      return '月卡';
    }
    
    return cardCategory;
  }
  
  // 标准化卡子类型函数
  function standardizeCardSubtype(cardSubtype: string | null): string {
    if (!cardSubtype) return '';
    
    const lowerSubtype = cardSubtype.toLowerCase();
    
    if (lowerSubtype.includes('single') && !lowerSubtype.includes('monthly')) {
      return '单次卡';
    } else if ((lowerSubtype.includes('two') || lowerSubtype.includes('double')) && !lowerSubtype.includes('monthly')) {
      return '两次卡';
    } else if (lowerSubtype.includes('ten') || lowerSubtype.includes('10')) {
      return '10次卡';
    } else if (lowerSubtype.includes('single') && lowerSubtype.includes('monthly')) {
      return '单次月卡';
    } else if (lowerSubtype.includes('double') && lowerSubtype.includes('monthly')) {
      return '双次月卡';
    }
    
    return cardSubtype;
  }

  const formatDateSafe = (date: string | null): string => {
    if (!date) return '';
    try {
      return format(new Date(date), 'yyyy-MM-dd');
    } catch {
      return '';
    }
  };

  const formatDateTimeSafe = (date: string | null): string => {
    if (!date) return '';
    try {
      return format(new Date(date), 'yyyy-MM-dd HH:mm:ss');
    } catch {
      return '';
    }
  };

  const exportMembers = async () => {
    try {
      setLoading(true);
      setError(null);

      // 获取所有会员数据
      const { data: members, error: membersError } = await supabase
        .from('members')
        .select(`
          *,
          membership_cards (
            card_type,
            card_category,
            card_subtype,
            remaining_group_sessions,
            remaining_private_sessions,
            remaining_kids_sessions,
            valid_until
          )
        `);

      if (membersError) throw membersError;

      // 检查是否有数据
      if (!members || members.length === 0) {
        setError('没有可导出的会员数据 No member data to export');
        return;
      }

      // 转换为CSV格式
      const records: MemberRecord[] = members.map((member: Member & { membership_cards: MembershipCard[] }) => ({
        '姓名': member.name,
        '邮箱': member.email || '',
        '会员卡类型': member.membership_cards.map(card => getCardTypeText(card)).join(', '),
        '剩余团课课时': member.membership_cards
          .filter(card => {
            // 只处理普通团课卡
            const cardType = standardizeCardType(card.card_type ?? null);
            return cardType === '团课';
          })
          .map(card => {
            // 判断是否为月卡，如果是返回空字符串
            const cardCategory = standardizeCardCategory(card.card_category ?? null);
            const cardSubtype = standardizeCardSubtype(card.card_subtype ?? null);
            
            // 如果是月卡类型，显示为空
            if (cardCategory === '月卡' || cardSubtype?.includes('月卡')) {
              return '';
            }
            
            // 非月卡正常显示剩余课时
            return card.remaining_group_sessions?.toString() || '0';
          })
          .join(', '),
        '剩余私教课时': member.membership_cards
          .filter(card => {
            // 使用标准化函数判断私教卡
            const cardType = standardizeCardType(card.card_type ?? null);
            return cardType === '私教课';
          })
          .map(card => card.remaining_private_sessions?.toString() || '0')
          .join(', '),
        '剩余儿童团课课时': member.membership_cards
          .filter(card => {
            // 只处理儿童团课卡
            const cardType = standardizeCardType(card.card_type ?? null);
            return cardType === '儿童团课';
          })
          .map(card => card.remaining_kids_sessions?.toString() || '0')
          .join(', '),
        '会员卡到期日': member.membership_cards
          .filter(card => card.valid_until)
          .map(card => formatDateSafe(card.valid_until))
          .join(', '),
        '注册时间': formatDateSafe(member.created_at),
        '最后签到时间': formatDateSafe(member.last_check_in_date)
      }));

      // 生成CSV文件
      const headers = Object.keys(records[0]);
      const csv = [
        headers.join(','),
        ...records.map(row => headers.map(header => `"${row[header]}"`).join(','))
      ].join('\n');

      // 下载文件
      const BOM = "\uFEFF"; // 添加BOM标记解决Windows Excel打开中文乱码问题
      const blob = new Blob([BOM + csv], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `members_${format(new Date(), 'yyyyMMdd')}.csv`;
      link.click();

      // 显示提示信息
      setError('导出成功! 如果在Windows Excel中打开时显示乱码，请使用"数据">"从文本/CSV"功能导入，并选择UTF-8编码。');

    } catch (err) {
      console.error('Failed to export members:', err);
      setError('导出失败，请重试 Export failed, please try again');
    } finally {
      setLoading(false);
    }
  };

  const exportCheckIns = async () => {
    try {
      setLoading(true);
      setError(null);

      // 获取所有签到记录
      // 修正查询语法，改用连接的方式获取会员和教练信息
      const { data: checkIns, error: checkInsError } = await supabase
        .from('check_ins')
        .select(`
          id,
          member_id,
          card_id,
          trainer_id,
          class_type,
          time_slot,
          check_in_date,
          is_extra,
          is_private,
          is_1v2,
          created_at
        `)
        .order('created_at', { ascending: false });

      if (checkInsError) throw checkInsError;

      // 检查是否有数据
      if (!checkIns || checkIns.length === 0) {
        setError('没有可导出的签到记录 No check-in records to export');
        return;
      }

      // 获取所有会员数据，用于后续关联
      const { data: members, error: membersError } = await supabase
        .from('members')
        .select('id, name, email');
      
      if (membersError) throw membersError;
      
      // 创建会员ID到会员信息的映射
      const memberMap = new Map();
      members?.forEach(member => {
        memberMap.set(member.id, { name: member.name, email: member.email || '' });
      });

      // 获取所有教练数据，用于后续关联
      const { data: trainers, error: trainersError } = await supabase
        .from('trainers')
        .select('id, name, type');
      
      if (trainersError) throw trainersError;
      
      // 创建教练ID到教练信息的映射
      const trainerMap = new Map();
      trainers?.forEach(trainer => {
        trainerMap.set(trainer.id, { name: trainer.name, type: trainer.type });
      });

      // 转换为CSV格式
      const records: CheckInRecord[] = checkIns.map((record: any) => {
        const memberInfo = memberMap.get(record.member_id) || { name: '', email: '' };
        const trainerInfo = record.trainer_id ? trainerMap.get(record.trainer_id) : null;
        
        // 获取课程类型文本
        let courseTypeText = '-';
        if (record.is_private) {
          courseTypeText = record.is_1v2 ? '1对2' : '1对1';
        }

        // 判断是否为儿童团课
        const isKidsClass = isKidsGroupClass(record.class_type);

        return {
          '会员姓名': memberInfo.name,
          '会员邮箱': memberInfo.email,
          '上课时段': record.time_slot || (isKidsClass ? '儿童团课 10:30-12:00' : record.class_type === 'morning' ? '早课 9:00-10:30' : '晚课 17:00-18:30'),
          '课程性质': record.is_private ? '私教课' : isKidsClass ? '儿童团课' : '团课',
          '教练': trainerInfo?.name || '-',
          '课程类型': courseTypeText,
          '签到时间': formatDateTimeSafe(record.created_at),
          '签到类型': record.is_extra ? '额外签到' : '正常签到'
        };
      });

      // 生成CSV文件
      const headers = Object.keys(records[0]);
      const csv = [
        headers.join(','),
        ...records.map(row => headers.map(header => `"${row[header]}"`).join(','))
      ].join('\n');

      // 下载文件
      const BOM = "\uFEFF"; // 添加BOM标记解决Windows Excel打开中文乱码问题
      const blob = new Blob([BOM + csv], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `check_ins_${format(new Date(), 'yyyyMMdd')}.csv`;
      link.click();

      // 显示提示信息
      setError('导出成功! 如果在Windows Excel中打开时显示乱码，请使用"数据">"从文本/CSV"功能导入，并选择UTF-8编码。');

    } catch (err) {
      console.error('Failed to export check-ins:', err);
      setError('导出失败，请重试 Export failed, please try again');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="space-y-6">
      {error && (
        <div className={`px-4 py-3 rounded relative ${
          error.includes('导出成功') 
            ? "bg-green-50 border border-green-200 text-green-700" 
            : "bg-red-50 border border-red-200 text-red-700"
        }`}>
          {error}
        </div>
      )}

      <div className="bg-white p-6 rounded-lg shadow-sm">
        <h3 className="text-lg font-medium mb-4">数据导出 Data Export</h3>
        <div className="space-y-4">
          <div>
            <h4 className="text-sm font-medium text-gray-700 mb-2">
              会员数据 Member Data
            </h4>
            <button
              onClick={exportMembers}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#4285F4] hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <Download className="w-4 h-4 mr-2" />
              导出会员数据 Export Members
            </button>
          </div>

          <div>
            <h4 className="text-sm font-medium text-gray-700 mb-2">
              签到记录 Check-in Records
            </h4>
            <button
              onClick={exportCheckIns}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#4285F4] hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <Download className="w-4 h-4 mr-2" />
              导出签到记录 Export Check-ins
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}