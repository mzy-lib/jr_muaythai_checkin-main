import { ExcelRow, ParsedRow, ParsedMemberData, ParsedCheckInData } from './types';
import { Member, CardType, CardSubtype, ClassType, TrainerType } from '../../types/database';
import { validateName } from '../nameValidation';
import { validateEmail } from '../validation/emailValidation';

export const validateRow = (row: ExcelRow, rowNumber: number): ParsedRow => {
  const errors: string[] = [];
  const name = row.name?.trim() || '';

  if (!name) {
    return {
      data: {
        member: {
          name: '',
          email: null,
          phone: null
        },
        card: {
          card_type: 'class' as CardType,
          card_subtype: 'single_class' as CardSubtype
        }
      },
      errors: ['姓名不能为空 Name is required'],
      rowNumber
    };
  }

  // 基础会员数据
  const memberData: Partial<Member> = {
    name,
    email: row.email?.trim() || null,
    phone: null
  };

  // 卡数据
  const cardData = {
    card_type: 'class' as CardType,
    card_subtype: 'single_class' as CardSubtype,
    remaining_group_sessions: row.remaining_classes ? Number(row.remaining_classes) : undefined,
    valid_until: row.membership_expiry || undefined
  };

  // 验证字段
  if (!validateName(name)) {
    errors.push(`无效的姓名格式 Invalid name format: "${name}"`);
  }

  if (memberData.email && !validateEmail(memberData.email)) {
    errors.push('无效的邮箱格式 Invalid email format');
  }

  return {
    data: {
      member: memberData,
      card: cardData
    },
    errors,
    rowNumber
  };
};

// 验证卡类型
const validateCardType = (type: string | null): type is CardType => {
  if (!type) return true;
  return ['class', 'monthly', 'private'].includes(type);
};

// 验证卡子类型
const validateCardSubtype = (subtype: string | null, cardType: CardType | null): subtype is CardSubtype => {
  if (!subtype || !cardType) return true;

  const validSubtypes = {
    class: ['single_class', 'two_classes', 'ten_classes'],
    monthly: ['single_monthly', 'double_monthly'],
    private: ['single_private', 'ten_private']
  };

  return validSubtypes[cardType]?.includes(subtype) || false;
};

// 验证课程类型
const validateClassType = (type: string): type is ClassType => {
  return ['morning', 'evening'].includes(type);
};

// 验证教练等级
const validateTrainerType = (type: string | null): type is TrainerType => {
  if (!type) return true;
  return ['jr', 'senior'].includes(type);
};

// 验证日期格式
const validateDate = (date: string | null): boolean => {
  if (!date) return true;
  const dateObj = new Date(date);
  return !isNaN(dateObj.getTime());
};

// 验证课时数
const validateSessions = (sessions: number | null): boolean => {
  if (sessions === null) return true;
  return Number.isInteger(sessions) && sessions >= 0;
};

// 验证手机号
const validatePhone = (phone: string | null): boolean => {
  if (!phone) return true;
  return /^1[3-9]\d{9}$/.test(phone);
};

// 验证会员数据
export const validateMemberData = (data: ParsedMemberData): string[] => {
  const errors: string[] = [];

  // 验证必填字段
  if (!data.name || !validateName(data.name)) {
    errors.push('无效的姓名格式 Invalid name format');
  }

  // 验证邮箱格式
  if (data.email && !validateEmail(data.email)) {
    errors.push('无效的邮箱格式 Invalid email format');
  }

  // 验证手机号格式
  if (data.phone && !validatePhone(data.phone)) {
    errors.push('无效的手机号格式 Invalid phone number format');
  }

  // 验证卡类型
  if (!validateCardType(data.card_type)) {
    errors.push('无效的卡类型 Invalid card type');
  }

  // 验证卡子类型
  if (!validateCardSubtype(data.card_subtype, data.card_type)) {
    errors.push('无效的卡子类型 Invalid card subtype');
  }

  // 验证课时数
  if (data.card_type === 'class' || data.card_type === 'private') {
    if (data.remaining_group_sessions !== null && !validateSessions(data.remaining_group_sessions)) {
      errors.push('无效的团课课时数 Invalid group sessions');
    }
    if (data.remaining_private_sessions !== null && !validateSessions(data.remaining_private_sessions)) {
      errors.push('无效的私教课时数 Invalid private sessions');
    }
  }

  // 验证到期日期
  if (!validateDate(data.valid_until)) {
    errors.push('无效的到期日期格式 Invalid expiry date format');
  }

  // 验证教练等级
  if (!validateTrainerType(data.trainer_type)) {
    errors.push('无效的教练等级 Invalid trainer type');
  }

  return errors;
};

// 验证签到数据
export const validateCheckInData = (data: ParsedCheckInData): string[] => {
  const errors: string[] = [];

  // 验证必填字段
  if (!data.name || !validateName(data.name)) {
    errors.push('无效的姓名格式 Invalid name format');
  }

  // 验证邮箱格式
  if (data.email && !validateEmail(data.email)) {
    errors.push('无效的邮箱格式 Invalid email format');
  }

  // 验证课程类型
  if (!validateClassType(data.class_type)) {
    errors.push('无效的课程类型 Invalid class type');
  }

  // 验证签到日期
  if (!validateDate(data.check_in_date)) {
    errors.push('无效的签到日期格式 Invalid check-in date format');
  }

  // 验证签到时间
  if (data.check_in_time && !validateDate(`2000-01-01 ${data.check_in_time}`)) {
    errors.push('无效的签到时间格式 Invalid check-in time format');
  }

  return errors;
};