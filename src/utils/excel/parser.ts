import { read, utils } from 'xlsx';
import { ParsedRow, ExcelMemberRow, ParsedMemberData } from './types';
import { validateMemberData } from './validator';
import { formatDateForDB } from '../dateUtils';
import { CardType, CardSubtype, TrainerType } from '../../types/database';

/**
 * 添加UTF-8 BOM到CSV数据
 * 这个函数可以用于处理从Google Sheet导出的CSV数据，确保中文字符正确显示
 * @param csvData 原始CSV数据
 * @returns 带有UTF-8 BOM标记的CSV数据
 */
export const addUTF8BOM = (csvData: string): string => {
  // UTF-8 BOM 是 \uFEFF
  return `\uFEFF${csvData}`;
};

/**
 * 检测文件是否包含UTF-8 BOM
 * @param buffer 文件数据的ArrayBuffer
 * @returns 是否包含BOM
 */
export const hasUTF8BOM = (buffer: ArrayBuffer): boolean => {
  const uint8Array = new Uint8Array(buffer);
  return uint8Array.length >= 3 && 
         uint8Array[0] === 0xEF && 
         uint8Array[1] === 0xBB && 
         uint8Array[2] === 0xBF;
};

/**
 * 将文本内容转换为UTF-8编码的CSV数据
 * 适用于从Google Sheet导出的CSV文件
 * @param csvContent 原始CSV内容（文本格式）
 * @returns 转换为UTF-8编码的CSV内容
 */
export const convertToUTF8CSV = (csvContent: string): string => {
  // 检查是否已经有BOM标记
  const hasBOM = csvContent.charCodeAt(0) === 0xFEFF;
  
  // 如果没有BOM标记，添加UTF-8 BOM
  if (!hasBOM) {
    return addUTF8BOM(csvContent);
  }
  
  return csvContent;
};

/**
 * 将文件转换为UTF-8编码的文本内容
 * @param file CSV或Excel文件
 * @returns Promise<string> 文件的UTF-8编码内容
 */
export const fileToUTF8Text = async (file: File): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = (event) => {
      if (event.target?.result) {
        // 获取文件内容并转换为UTF-8
        const content = event.target.result as string;
        const utf8Content = convertToUTF8CSV(content);
        resolve(utf8Content);
      } else {
        reject(new Error("无法读取文件内容"));
      }
    };
    
    reader.onerror = () => {
      reject(new Error("文件读取失败"));
    };
    
    // 以文本形式读取文件，自动检测编码
    reader.readAsText(file);
  });
};

/**
 * 转换CSV文件为UTF-8编码并返回新的File对象
 * @param file 原始CSV文件
 * @returns Promise<File> 转换后的UTF-8编码CSV文件
 */
export const convertCSVFileToUTF8 = async (file: File): Promise<File> => {
  try {
    // 读取文件内容
    const content = await fileToUTF8Text(file);
    
    // 创建新的UTF-8编码的Blob
    const utf8Blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
    
    // 创建新的File对象
    return new File([utf8Blob], file.name, { 
      type: 'text/csv;charset=utf-8;',
      lastModified: new Date().getTime()
    });
  } catch (error) {
    console.error('CSV文件UTF-8转换失败:', error);
    throw error;
  }
};

// 定义卡类型映射
const CARD_TYPE_MAPPING = {
  '团课': 'class',  // 映射到CardType中的"class"
  '月卡': 'monthly',  // 映射到CardType中的"monthly"
  '私教课': 'private'  // 映射到CardType中的"private"
} as const;

// 定义卡类别映射
const CARD_CATEGORY_MAPPING = {
  '课时卡': 'group',
  '月卡': 'monthly',
  '私教': 'private'
} as const;

// 定义卡子类型映射
const CARD_SUBTYPE_MAPPING = {
  // 团课课时卡
  '单次卡': 'single_class',
  '两次卡': 'two_classes',
  '10次卡': 'ten_classes',
  // 月卡
  '单次月卡': 'single_monthly',
  '双次月卡': 'double_monthly',
  // 私教卡
  '单次私教': 'single_private',
  '10次私教': 'ten_private'
} as const;

// 定义教练等级映射
const TRAINER_TYPE_MAPPING = {
  'JR教练': 'jr',
  '高级教练': 'senior'
} as const;

// 定义表头映射
const HEADER_MAPPING = {
  '姓名': 'name',
  '姓名 Name': 'name',
  '邮箱': 'email',
  '邮箱 Email': 'email',
  '电话': 'phone',
  '电话 Phone': 'phone',
  '卡类型': 'card_type',
  '卡类型 Card Type': 'card_type',
  '卡类别': 'card_category',
  '卡类别 Card Category': 'card_category',
  '卡子类型': 'card_subtype',
  '卡子类型 Card Subtype': 'card_subtype',
  '剩余团课课时': 'remaining_group_sessions',
  '剩余团课课时 Remaining Group Sessions': 'remaining_group_sessions',
  '剩余私教课时': 'remaining_private_sessions',
  '剩余私教课时 Remaining Private Sessions': 'remaining_private_sessions',
  '到期日期': 'valid_until',
  '到期日期 Valid Until': 'valid_until',
  '教练等级': 'trainer_type',
  '教练等级 Trainer Type': 'trainer_type',
  '备注': 'notes',
  '备注 Notes': 'notes'
};

// 修改日期格式化函数，处理多种类型的输入
const formatDateForPostgres = (dateInput: any): string | null => {
  // 如果输入为空，返回null
  if (dateInput === null || dateInput === undefined) return null;
  
  try {
    let date: Date;
    
    // 根据输入类型处理
    if (dateInput instanceof Date) {
      // 如果已经是Date对象
      date = dateInput;
    } else if (typeof dateInput === 'string') {
      // 如果是字符串，先清理再转换
      if (dateInput.trim() === '') return null;
      date = new Date(dateInput);
    } else if (typeof dateInput === 'number') {
      // 如果是数字（Excel日期是数字格式）
      date = new Date(dateInput);
    } else {
      // 其他类型，尝试直接转换
      date = new Date(dateInput);
    }
    
    // 检查日期是否有效
    if (isNaN(date.getTime())) {
      console.error('无效的日期:', dateInput);
      return null;
    }
    
    // 只保留日期部分，格式为YYYY-MM-DD
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    
    return `${year}-${month}-${day}`;
  } catch (error) {
    console.error('日期处理错误:', error, '输入值:', dateInput);
    return null;
  }
};

export const parseExcelFile = async (file: File): Promise<ParsedRow[]> => {
  try {
    // 解析开始
    console.log('开始解析Excel文件');
    
    // 对CSV文件应用UTF-8处理
    let processedFile = file;
    if (file.name.endsWith('.csv')) {
      console.log('检测到CSV文件，尝试应用UTF-8编码转换...');
      try {
        processedFile = await convertCSVFileToUTF8(file);
        console.log('CSV文件已转换为UTF-8编码');
      } catch (err) {
        console.warn('UTF-8转换失败，将使用原始文件:', err);
      }
    }
    
    // 读取文件buffer
    const buffer = await processedFile.arrayBuffer();
    const uint8Array = new Uint8Array(buffer);
    
    // 检查并处理UTF-8 BOM (Byte Order Mark)
    // UTF-8 BOM 是文件开头的三个字节: 0xEF, 0xBB, 0xBF
    let hasBOM = false;
    if (uint8Array.length >= 3 && 
        uint8Array[0] === 0xEF && 
        uint8Array[1] === 0xBB && 
        uint8Array[2] === 0xBF) {
      console.log('检测到UTF-8 BOM标记');
      hasBOM = true;
    } else {
      console.log('未检测到UTF-8 BOM标记，可能导致中文乱码');
    }
    
    // 设置读取选项，强制使用UTF-8编码
    const workbook = read(buffer, { 
      type: 'array',
      cellDates: true,
      cellNF: false,
      cellText: false,
      codepage: 65001  // 强制使用UTF-8编码 (codepage 65001)
    });
    
    // 检查工作表信息
    console.log('工作表信息:', {
      sheetNames: workbook.SheetNames,
      activeSheet: workbook.SheetNames[0],
      hasBOM: hasBOM
    });
    
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    
    // 获取原始数据，尝试多种读取方式
    let rawRows = utils.sheet_to_json<Record<string, any>>(sheet, {
      raw: true,
      defval: null
    });

    // 检查原始数据的格式和内容
    console.log('原始Excel数据:', rawRows);
    if (rawRows.length > 0) {
      console.log('第1行原始数据的键:', Object.keys(rawRows[0]));
      console.log('第1行原始数据值:', Object.values(rawRows[0]));
      console.log('第1行原始数据详细:', JSON.stringify(rawRows[0]));
    }

    // 检查每行是否有效
    const hasValidData = rawRows.some(row => 
      Object.values(row).some(value => value !== null && value !== '')
    );
    
    if (!hasValidData) {
      console.error('CSV文件中没有有效数据，请检查格式');
      // 尝试使用不同的选项读取
      const rawRowsAlt = utils.sheet_to_json<Record<string, any>>(sheet, {
        raw: true,
        defval: null,
        header: 1  // 使用第1行作为数据，不使用表头
      });
      console.log('使用替代方法读取CSV:', rawRowsAlt);
    }

    // 编码问题检测与修复
    const isEncodingIssue = rawRows.length > 0 && Object.keys(rawRows[0]).some(key => 
      key.includes('å') || key.includes('é') || key.includes('ç')
    );
    
    let fixedRows = rawRows;
    if (isEncodingIssue) {
      console.log('检测到编码问题，尝试修复...');
      
      // 直接使用硬编码的标准表头进行处理
      const standardHeaders = [
        '姓名 Name', '邮箱 Email', '电话 Phone', '卡类型 Card Type', 
        '卡类别 Card Category', '卡子类型 Card Subtype', 
        '剩余团课课时 Remaining Group Sessions', 
        '剩余私教课时 Remaining Private Sessions',
        '到期日期 Valid Until', '教练等级 Trainer Type'
      ];
      
      // 尝试直接将标准表头映射到数据上
      fixedRows = rawRows.map(row => {
        const originalKeys = Object.keys(row);
        const values = Object.values(row);
        const fixedRow: Record<string, any> = {};
        
        // 如果键的数量与标准表头数量相同，假设它们是按顺序对应的
        if (originalKeys.length === standardHeaders.length) {
          standardHeaders.forEach((header, index) => {
            fixedRow[header] = values[index];
          });
        } else {
          // 否则尝试基于字段位置推断
          // 邮箱字段通常是第二个字段，而且格式特殊
          for (let i = 0; i < values.length; i++) {
            const value = values[i];
            // 检测邮箱
            if (typeof value === 'string' && value.includes('@') && value.includes('.')) {
              fixedRow['邮箱 Email'] = value;
              // 假设邮箱左边是姓名
              if (i > 0) fixedRow['姓名 Name'] = values[i-1];
              break;
            }
          }
        }
        
        console.log('修复后的行:', fixedRow);
        return fixedRow;
      });
      
      console.log('编码修复后的数据:', fixedRows);
    }

    // 映射中英文表头和值
    const rows = fixedRows.map(row => {
      const mappedRow: Record<string, any> = {};
      Object.entries(row).forEach(([key, value]) => {
        // 尝试修复编码问题的键
        let fixedKey = key;
        if (isEncodingIssue) {
          // 检查这个键是否包含特定的模式，例如"Name"、"Email"等
          if (key.includes('Name')) fixedKey = '姓名 Name';
          else if (key.includes('Email')) fixedKey = '邮箱 Email';
          else if (key.includes('Phone')) fixedKey = '电话 Phone';
          else if (key.includes('Card Type')) fixedKey = '卡类型 Card Type';
          else if (key.includes('Card Category')) fixedKey = '卡类别 Card Category';
          else if (key.includes('Card Subtype')) fixedKey = '卡子类型 Card Subtype';
          else if (key.includes('Group Sessions')) fixedKey = '剩余团课课时 Remaining Group Sessions';
          else if (key.includes('Private Sessions')) fixedKey = '剩余私教课时 Remaining Private Sessions';
          else if (key.includes('Valid Until')) fixedKey = '到期日期 Valid Until';
          else if (key.includes('Trainer Type')) fixedKey = '教练等级 Trainer Type';
        }
        
        const englishKey = HEADER_MAPPING[fixedKey as keyof typeof HEADER_MAPPING];
        if (englishKey) {
          // 转换卡类型
          if (englishKey === 'card_type' && typeof value === 'string') {
            // 检查值是否是乱码的中文
            if (value.includes('ç§') || value.includes('å¢') || value.includes('æ')) {
              // 尝试根据部分特征判断卡类型
              if (value.includes('ç§')) mappedRow[englishKey] = 'private'; // 私教课
              else if (value.includes('å¢')) mappedRow[englishKey] = 'class'; // 团课
              else mappedRow[englishKey] = 'class'; // 默认团课
            } else {
              mappedRow[englishKey] = CARD_TYPE_MAPPING[value as keyof typeof CARD_TYPE_MAPPING] || value;
            }
          }
          // 转换卡子类型
          else if (englishKey === 'card_subtype' && typeof value === 'string') {
            mappedRow[englishKey] = CARD_SUBTYPE_MAPPING[value as keyof typeof CARD_SUBTYPE_MAPPING] || value;
          }
          // 转换教练等级
          else if (englishKey === 'trainer_type' && typeof value === 'string') {
            mappedRow[englishKey] = TRAINER_TYPE_MAPPING[value as keyof typeof TRAINER_TYPE_MAPPING] || value;
          }
          // 转换卡类别
          else if (englishKey === 'card_category' && typeof value === 'string') {
            mappedRow[englishKey] = CARD_CATEGORY_MAPPING[value as keyof typeof CARD_CATEGORY_MAPPING] || value;
          }
          else {
            mappedRow[englishKey] = value;
          }
        }
      });
      return mappedRow as ExcelMemberRow;
    });
    
    console.log('映射后的数据:', rows);
    
    // 添加更详细的第一条数据日志
    if (rows.length > 0) {
      console.log('第一条记录详细信息:', {
        name: rows[0].name,
        email: rows[0].email,
        card_type: rows[0].card_type,
        card_subtype: rows[0].card_subtype
      });
    }
    
    // 返回结果前
    console.log('解析完成，返回数据条数:', rows.length);
    
    // 过滤掉空行或无效行
    const validRows = rows.filter(row => {
      // 检查行是否包含基本的姓名或邮箱信息
      const hasBasicInfo = row.name || row.email;
      if (!hasBasicInfo) {
        console.log('跳过空行或无效行:', row);
        return false;
      }
      return true;
    });
    
    console.log(`过滤后有效数据条数: ${validRows.length}/${rows.length}`);
    
    // 直接构建返回数据，完全跳过验证
    return validRows.map((row, index) => {
      // 为了调试，记录每行数据的实际值
      console.log(`处理第${index + 1}行数据:`, {
        raw_name: row.name,
        raw_email: row.email,
        raw_card_type: row.card_type,
        raw_card_subtype: row.card_subtype
      });
      
      // 生成唯一的临时邮箱，避免所有空邮箱都使用相同的default-@temp.com
      const safeName = String(row.name || '').trim().replace(/\s+/g, '-');
      const tempEmail = row.email && String(row.email).trim() 
        ? String(row.email).trim() 
        : `default-${safeName}-${index + 1}-${Date.now()}@temp.com`;
      
      const formattedDate = row.valid_until ? formatDateForPostgres(row.valid_until) : null;
      console.log('原始日期值:', row.valid_until, '类型:', typeof row.valid_until);
      console.log('格式化后日期:', formattedDate);
      
      return {
        data: {
          member: {
            name: String(row.name || '').trim(),
            email: tempEmail,
            phone: row.phone ? String(row.phone).trim() : null
          },
          card: {
            card_type: row.card_type as CardType || 'class',
            card_subtype: row.card_subtype as CardSubtype || 'single_class',
            card_category: row.card_category || undefined,
            remaining_group_sessions: row.remaining_group_sessions ? Number(row.remaining_group_sessions) : undefined,
            remaining_private_sessions: row.remaining_private_sessions ? Number(row.remaining_private_sessions) : undefined,
            valid_until: formattedDate || undefined,
            trainer_type: (() => {
              // 尝试从原始值映射，如果有值的话
              if (row.trainer_type) {
                // 检查是否是乱码的中文教练类型
                if (typeof row.trainer_type === 'string') {
                  // 直接检查是否已经是有效值
                  if (row.trainer_type === 'jr' || row.trainer_type === 'senior') {
                    return row.trainer_type as TrainerType;
                  }
                  
                  // 检查是否包含特征字符串，识别JR教练还是高级教练
                  const trainerTypeStr = String(row.trainer_type);
                  if (trainerTypeStr.includes('JR') || trainerTypeStr.includes('jr') || 
                      trainerTypeStr.includes('Jx') || trainerTypeStr.toLowerCase().includes('jr')) {
                    return 'jr';
                  } else if (trainerTypeStr.includes('高级') || trainerTypeStr.includes('senior') || 
                            trainerTypeStr.includes('高') || trainerTypeStr.toLowerCase().includes('senior')) {
                    return 'senior';
                  }
                }
              }
              
              // 根据卡类型决定默认值
              const cardType = row.card_type as CardType || 'class';
              const cardSubtype = row.card_subtype as CardSubtype || 'single_class';
              
              if (cardType === 'private' || 
                  (cardSubtype && cardSubtype.includes('private')) || 
                  (row.remaining_private_sessions && Number(row.remaining_private_sessions) > 0)) {
                return 'jr'; // 私教卡默认JR教练
              }
              
              // 非私教卡默认返回null
              return undefined;
            })() as TrainerType | undefined
          }
        },
        errors: [],
        rowNumber: index + 2
      };
    });
  } catch (err) {
    console.error('Excel解析错误:', err);
    throw err;
  }
};