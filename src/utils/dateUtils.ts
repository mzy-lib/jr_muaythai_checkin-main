import { format, isAfter, isBefore, addDays } from 'date-fns';

// Add new function to format date
export const formatDate = (date: string | Date) => {
  return format(new Date(date), 'yyyy-MM-dd');
};

export const isWithinClassHours = (classType: 'morning' | 'evening'): boolean => {
  const now = new Date();
  const hour = now.getHours();
  const minutes = now.getMinutes();
  const time = hour + minutes / 60;

  return classType === 'morning' 
    ? time >= 8.5 && time <= 11  // 8:30 - 11:00
    : time >= 16.5 && time <= 19; // 16:30 - 19:00
};

export const formatDateTime = (date: Date): string => {
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(date);
};

export const formatDateForDB = (date: Date | string | null): string | null => {
  if (!date) return null;
  
  try {
    const dateObj = date instanceof Date ? date : new Date(date);
    if (isNaN(dateObj.getTime())) return null;
    
    return dateObj.toISOString();
  } catch {
    return null;
  }
};

export const isWithinDays = (date: Date, days: number) => {
  const today = new Date();
  const futureDate = addDays(today, days);
  return isAfter(date, today) && isBefore(date, futureDate);
};

export const isPast = (date: Date) => {
  return isBefore(date, new Date());
};

/**
 * 格式化时间段字符串，确保符合后端要求的格式 (HH:MM-HH:MM)
 * 如果已经是正确格式，则直接返回
 * 对于团课，将标准时段转换为固定格式
 */
export const formatTimeSlot = (timeSlot: string): string => {
  // 如果已经是正确格式 (HH:MM-HH:MM)，直接返回
  if (/^\d{2}:\d{2}-\d{2}:\d{2}$/.test(timeSlot)) {
    return timeSlot;
  }
  
  // 处理团课标准时段
  if (timeSlot === '上午' || timeSlot === 'morning') {
    return '09:00-10:30';
  }
  
  if (timeSlot === '下午' || timeSlot === 'evening') {
    return '17:00-18:30';
  }
  
  // 如果是其他格式，尝试标准化
  const parts = timeSlot.split('-');
  if (parts.length === 2) {
    const start = parts[0].trim();
    const end = parts[1].trim();
    
    // 尝试格式化时间
    const formatTime = (time: string): string => {
      // 如果已经是HH:MM格式
      if (/^\d{2}:\d{2}$/.test(time)) {
        return time;
      }
      
      // 如果是H:MM格式
      if (/^\d:\d{2}$/.test(time)) {
        return `0${time}`;
      }
      
      // 如果只有小时
      if (/^\d{1,2}$/.test(time)) {
        const hour = parseInt(time, 10);
        return hour < 10 ? `0${hour}:00` : `${hour}:00`;
      }
      
      return time;
    };
    
    return `${formatTime(start)}-${formatTime(end)}`;
  }
  
  // 无法格式化，返回原始值
  console.warn(`无法格式化时间段: ${timeSlot}`);
  return timeSlot;
};