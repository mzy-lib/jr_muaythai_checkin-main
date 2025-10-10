import React, { useState, useRef } from 'react';
import { Upload, Download, AlertTriangle, FileType, HelpCircle } from 'lucide-react';
import { utils, writeFile } from 'xlsx';
import { supabase } from '../../lib/supabase';
import { parseExcelFile, addUTF8BOM, convertCSVFileToUTF8 } from '../../utils/excel/parser';
import ImportErrors from './ImportErrors';
import LoadingSpinner from '../common/LoadingSpinner';
import { Member, CardType, CardSubtype, TrainerType } from '../../types/database';

interface ImportRow {
  data: {
    member: Partial<Member>;
    card: {
      card_type: CardType;
      card_subtype: CardSubtype;
      remaining_group_sessions?: number;
      remaining_private_sessions?: number;
      valid_until?: string;
      trainer_type?: TrainerType;
    };
  };
  errors: string[];
  rowNumber: number;
}

export default function ExcelImport() {
  const [importing, setImporting] = useState(false);
  const [importErrors, setImportErrors] = useState<ImportRow[]>([]);
  const [formatError, setFormatError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showHelp, setShowHelp] = useState(false);

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    
    // 重置错误状态
    setFormatError(null);
    
    console.log('文件上传: ', {
      name: file.name,
      type: file.type,
      size: `${(file.size / 1024).toFixed(2)}KB`
    });

    try {
      setImporting(true);
      setImportErrors([]);

      // 检查文件格式
      if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        setFormatError('请上传CSV或Excel格式的文件');
        setImporting(false);
        return;
      }

      // 判断是否可能是从Google Sheet导出的CSV文件
      const isGoogleSheetCSV = file.name.endsWith('.csv') && file.type === 'text/csv';
      
      if (isGoogleSheetCSV) {
        console.log('检测到Google Sheet CSV文件，应用特殊UTF-8处理...');
        // CSV文件自动应用UTF-8处理由parseExcelFile内部处理
      }

      const parsedRows = await parseExcelFile(file);
      
      // 检查解析结果
      if (!parsedRows || parsedRows.length === 0) {
        setFormatError('文件解析失败，可能是格式问题。请确保使用正确的模板并填写了数据。');
        setImporting(false);
        return;
      }
      
      const errors = parsedRows.filter(row => row.errors.length > 0);
      
      if (errors.length > 0) {
        setImportErrors(errors);
        return;
      }

      // 处理有效数据
      console.log('开始处理有效数据，总行数:', parsedRows.length);
      
      try {
        for (let i = 0; i < parsedRows.length; i++) {
          const row = parsedRows[i];
          console.log(`处理第${i+1}/${parsedRows.length}行数据:`, {
            name: row.data.member.name,
            email: row.data.member.email,
            card_type: row.data.card.card_type,
            card_subtype: row.data.card.card_subtype
          });
          
          // 确保email不为null
          if (!row.data.member.email) {
            const safeName = (row.data.member.name || '').replace(/\s+/g, '-');
            row.data.member.email = `member-${safeName}-${row.rowNumber}@temp.com`;
            console.log(`为第${row.rowNumber}行的会员生成临时email: ${row.data.member.email}`);
          }
          
          // 确认会员数据
          console.log('准备插入的会员数据:', row.data.member);
          
          // 1. 创建或更新会员信息
          try {
            const { data: memberData, error: memberError } = await supabase
              .from('members')
              .upsert(row.data.member, { onConflict: 'email' })
              .select()
              .single();

            if (memberError) {
              console.error(`会员导入错误(行${i+1}):`, memberError);
              throw memberError;
            }
            
            console.log(`会员创建/更新成功(行${i+1}):`, memberData);

            // 2. 创建会员卡
            if (memberData) {
              const cardData = {
                ...row.data.card,
                member_id: memberData.id,
                created_at: new Date().toISOString()
              };
              
              // 1. 先创建会员卡，但不包含valid_until字段
              const initialCardData = { ...cardData };
              delete initialCardData.valid_until; // 先移除valid_until字段

              console.log(`准备插入基础会员卡数据(不含有效期):`, initialCardData);

              try {
                // 创建基础卡记录
                const { data: insertedCard, error: cardError } = await supabase
                  .from('membership_cards')
                  .upsert(
                    initialCardData,
                    {
                      onConflict: 'member_id,card_type,card_subtype',
                      ignoreDuplicates: false
                    }
                  )
                  .select();

                if (cardError) {
                  console.error(`会员卡创建错误:`, cardError);
                  throw cardError;
                }
                
                console.log(`会员卡基础信息创建成功:`, insertedCard);

                // 2. 如果有效期存在，单独更新这个字段
                if (cardData.valid_until && insertedCard && insertedCard.length > 0) {
                  const cardId = insertedCard[0].id;
                  console.log(`尝试单独更新valid_until字段，卡ID:${cardId}, 值:${cardData.valid_until}`);
                  
                  // 确保日期格式是YYYY-MM-DD
                  let dateValue = cardData.valid_until;
                  if (typeof dateValue === 'string' && !dateValue.match(/^\d{4}-\d{2}-\d{2}$/)) {
                    try {
                      const date = new Date(dateValue);
                      const year = date.getFullYear();
                      const month = String(date.getMonth() + 1).padStart(2, '0');
                      const day = String(date.getDate()).padStart(2, '0');
                      dateValue = `${year}-${month}-${day}`;
                    } catch (err) {
                      console.error('日期转换失败:', err);
                    }
                  }
                  
                  // 单独执行更新操作
                  const { data: updateResult, error: updateError } = await supabase
                    .from('membership_cards')
                    .update({ valid_until: dateValue })
                    .eq('id', cardId)
                    .select();
                    
                  if (updateError) {
                    console.error('更新valid_until失败:', updateError);
                  } else {
                    console.log('valid_until更新成功:', updateResult);
                  }
                }
                
                console.log(`会员卡创建完成:`, insertedCard);
              } catch (cardErr) {
                console.error(`会员卡创建过程中发生异常:`, cardErr);
                throw cardErr;
              }
            } else {
              console.warn(`会员数据不存在，无法创建会员卡(行${i+1})`);
            }
          } catch (memberErr) {
            console.error(`处理会员数据过程中发生异常(行${i+1}):`, memberErr);
            throw memberErr;
          }
        }
        
        console.log('所有数据处理完成，成功导入');
        alert('导入成功！Import successful!');
      } catch (processErr: any) {
        console.error('数据处理过程中发生错误:', processErr);
        alert(`导入失败，发生错误: ${processErr.message || '未知错误'}`);
      }
    } catch (err) {
      console.error('导入失败详情:', err);
      setFormatError(`导入失败: ${err instanceof Error ? err.message : '未知错误'}`);
      alert('导入失败，请检查控制台了解详情。Import failed. Please check the console for details.');
    } finally {
      setImporting(false);
      // 重置文件输入，以便可以重新选择相同的文件
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const downloadSampleData = () => {
    // 定义表头
    const headers = [
      '姓名 Name',
      '邮箱 Email',
      '电话 Phone',
      '卡类型 Card Type',
      '卡类别 Card Category',
      '卡子类型 Card Subtype',
      '剩余团课课时 Remaining Group Sessions',
      '剩余私教课时 Remaining Private Sessions',
      '到期日期 Valid Until',
      '教练等级 Trainer Type'
    ].join(',');

    // 示例数据
    const sampleData = [
      {
        '姓名 Name': '王小明',
        '邮箱 Email': 'wang.xm@example.com',
        '电话 Phone': '13800138000',
        '卡类型 Card Type': '团课',
        '卡类别 Card Category': '课时卡',
        '卡子类型 Card Subtype': '10次卡',
        '剩余团课课时 Remaining Group Sessions': '10',
        '剩余私教课时 Remaining Private Sessions': '',
        '到期日期 Valid Until': '2024-06-30',
        '教练等级 Trainer Type': ''
      },
      {
        '姓名 Name': 'John Smith',
        '邮箱 Email': 'john.smith@example.com',
        '电话 Phone': '13900139000',
        '卡类型 Card Type': '月卡',
        '卡类别 Card Category': '月卡',
        '卡子类型 Card Subtype': '单次月卡',
        '剩余团课课时 Remaining Group Sessions': '',
        '剩余私教课时 Remaining Private Sessions': '',
        '到期日期 Valid Until': '2024-04-15',
        '教练等级 Trainer Type': ''
      },
      {
        '姓名 Name': '陈美玲',
        '邮箱 Email': 'chen.ml@example.com',
        '电话 Phone': '13700137000',
        '卡类型 Card Type': '私教课',
        '卡类别 Card Category': '私教',
        '卡子类型 Card Subtype': '10次私教',
        '剩余团课课时 Remaining Group Sessions': '',
        '剩余私教课时 Remaining Private Sessions': '5',
        '到期日期 Valid Until': '2024-06-30',
        '教练等级 Trainer Type': '高级教练'
      }
    ];

    // 转换为CSV
    const rows = sampleData.map(row => 
      Object.values(row)
        .map(value => `"${value}"`) // 用引号包裹值以处理逗号
        .join(',')
    );
    
    // 添加UTF-8 BOM以兼容Excel
    const csv = addUTF8BOM([headers, ...rows].join('\n'));

    // 创建并触发下载
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'member_data_template_utf8.csv';
    
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // 下载UTF-8编码的样本数据模板
  const downloadUTF8Template = () => {
    // 定义表头
    const headers = [
      '姓名 Name',
      '邮箱 Email',
      '电话 Phone',
      '卡类型 Card Type',
      '卡类别 Card Category',
      '卡子类型 Card Subtype',
      '剩余团课课时 Remaining Group Sessions',
      '剩余私教课时 Remaining Private Sessions',
      '到期日期 Valid Until',
      '教练等级 Trainer Type',
      '备注 Notes'
    ].join(',');

    // 示例数据
    const sampleData = [
      {
        '姓名 Name': '王小明',
        '邮箱 Email': 'wang.xm@example.com',
        '电话 Phone': '13800138000',
        '卡类型 Card Type': '团课',
        '卡类别 Card Category': '课时卡',
        '卡子类型 Card Subtype': '10次卡',
        '剩余团课课时 Remaining Group Sessions': '10',
        '剩余私教课时 Remaining Private Sessions': '',
        '到期日期 Valid Until': '2024-06-30',
        '教练等级 Trainer Type': '',
        '备注 Notes': '从Google Sheet导出'
      },
      {
        '姓名 Name': 'John Smith',
        '邮箱 Email': 'john.smith@example.com',
        '电话 Phone': '13900139000',
        '卡类型 Card Type': '月卡',
        '卡类别 Card Category': '月卡',
        '卡子类型 Card Subtype': '单次月卡',
        '剩余团课课时 Remaining Group Sessions': '',
        '剩余私教课时 Remaining Private Sessions': '',
        '到期日期 Valid Until': '2024-04-15',
        '教练等级 Trainer Type': '',
        '备注 Notes': '包含中文注释：这是测试数据'
      },
      {
        '姓名 Name': '陈美玲',
        '邮箱 Email': 'chen.ml@example.com',
        '电话 Phone': '13700137000',
        '卡类型 Card Type': '私教课',
        '卡类别 Card Category': '私教',
        '卡子类型 Card Subtype': '10次私教',
        '剩余团课课时 Remaining Group Sessions': '',
        '剩余私教课时 Remaining Private Sessions': '5',
        '到期日期 Valid Until': '2024-06-30',
        '教练等级 Trainer Type': '高级教练',
        '备注 Notes': '私教课程'
      }
    ];

    // 转换为CSV
    const rows = sampleData.map(row => 
      Object.values(row)
        .map(value => `"${value}"`) // 用引号包裹值以处理逗号
        .join(',')
    );
    
    // 添加UTF-8 BOM以兼容Excel
    const csv = addUTF8BOM([headers, ...rows].join('\n'));

    // 创建并触发下载
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'member_data_template_utf8.csv';
    
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // 添加导入指南下载按钮
  const downloadImportGuide = () => {
    const guide = `
# 会员数据导入指南

## 文件格式要求
- 可接受的文件格式：CSV (推荐)、XLSX、XLS
- 编码：UTF-8（特别是对于中文字符）

## 从Google Sheets导出CSV的步骤
1. 在Google Sheets中打开您的数据表格
2. 点击【文件】->【下载】->【CSV格式（.csv）】
3. 直接使用下载的文件导入系统，不要用Excel打开修改

## 避免中文字符乱码的建议
- 确保使用"UTF-8 CSV"格式
- 如果使用Excel准备数据，请用"另存为"并选择"CSV UTF-8 (逗号分隔)"格式
- 避免在Excel中修改已经导出的CSV文件，这可能会改变文件编码

## 表格字段说明
- 姓名(Name): 会员姓名，必填
- 邮箱(Email): 会员邮箱，建议填写
- 电话(Phone): 会员电话号码，可选
- 卡类型(Card Type): 团课、月卡或私教课
- 卡类别(Card Category): 课时卡、月卡或私教
- 卡子类型(Card Subtype): 如单次卡、10次卡等
- 剩余团课课时(Remaining Group Sessions): 团课剩余次数
- 剩余私教课时(Remaining Private Sessions): 私教剩余次数
- 到期日期(Valid Until): 卡有效期，格式如2024-06-30
- 教练等级(Trainer Type): 适用于私教卡，如JR教练、高级教练

如有疑问，请联系管理员获取帮助。
`;
    
    // 添加UTF-8 BOM以兼容中文
    const text = addUTF8BOM(guide);

    // 创建并触发下载
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = '会员数据导入指南.txt';
    
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // 添加帮助提示切换函数
  const toggleHelp = () => {
    setShowHelp(!showHelp);
  };

  return (
    <div className="space-y-6 p-6 bg-white rounded-lg shadow">
      <div className="flex flex-col space-y-2">
        <h2 className="text-2xl font-bold">导入会员数据</h2>
        <p className="text-gray-500">上传Excel文件或CSV导入会员数据和会员卡信息</p>
      </div>

      {/* 帮助按钮 */}
      <div className="flex justify-end">
        <button
          onClick={toggleHelp}
          className="flex items-center gap-1 text-gray-500 hover:text-gray-700"
        >
          <HelpCircle size={16} />
          <span>{showHelp ? '隐藏帮助' : '显示帮助'}</span>
        </button>
      </div>

      {/* 帮助提示区域 */}
      {showHelp && (
        <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
          <h3 className="font-semibold text-blue-700 mb-2">中文字符乱码问题解决指南</h3>
          <ol className="list-decimal list-inside text-sm space-y-2 text-blue-800">
            <li>
              <strong>推荐方法（Google Sheets）：</strong>
              <ul className="list-disc list-inside ml-5 mt-1">
                <li>在Google Sheets中准备您的数据</li>
                <li>点击【文件】 → 【下载】 → 选择【CSV格式】</li>
                <li>直接将下载的CSV文件导入到系统中，<strong>不要用Excel打开它</strong></li>
              </ul>
            </li>
            <li>
              <strong>使用Excel方法：</strong>
              <ul className="list-disc list-inside ml-5 mt-1">
                <li>在Excel中准备数据后，点击【另存为】</li>
                <li>在弹出的对话框中，选择保存类型为【CSV UTF-8 (逗号分隔)】</li>
                <li>保存后直接导入系统</li>
              </ul>
            </li>
            <li>
              <strong>修复现有文件：</strong>
              <ul className="list-disc list-inside ml-5 mt-1">
                <li>在Google Sheets中新建空白表格</li>
                <li>导入您的CSV文件（【文件】→【导入】→选择您的文件）</li>
                <li>然后再次导出为CSV（【文件】→【下载】→【CSV格式】）</li>
              </ul>
            </li>
          </ol>
          <p className="text-sm text-blue-700 mt-2">
            <strong>注意：</strong> 我们的系统已经尝试自动修复编码问题，但某些情况下可能仍需手动处理。
          </p>
        </div>
      )}

      <div className="flex gap-4 flex-wrap">
        <button
          onClick={downloadSampleData}
          className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-600 rounded hover:bg-blue-100 transition-colors"
        >
          <Download size={18} /> 下载样板文件
        </button>
        
        <button
          onClick={downloadUTF8Template}
          className="flex items-center gap-2 px-4 py-2 bg-green-50 text-green-600 rounded hover:bg-green-100 transition-colors"
        >
          <FileType size={18} /> 下载UTF-8模板(推荐)
        </button>
        
        <button
          onClick={downloadImportGuide}
          className="flex items-center gap-2 px-4 py-2 bg-purple-50 text-purple-600 rounded hover:bg-purple-100 transition-colors"
        >
          <FileType size={18} /> 导入指南
        </button>
      </div>

      <div className="flex items-center justify-center w-full">
        <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
          <div className="flex flex-col items-center justify-center pt-5 pb-6">
            <Upload className="mb-2 text-gray-500" />
            <p className="mb-2 text-sm text-gray-500">
              <span className="font-semibold">点击上传</span> 或拖放文件
            </p>
            <p className="text-xs text-gray-500">支持 XLSX, XLS 或 CSV 文件</p>
          </div>
          <input 
            ref={fileInputRef}
            type="file" 
            className="hidden" 
            accept=".csv,.xlsx,.xls" 
            onChange={handleFileUpload} 
            disabled={importing}
          />
        </label>
      </div>

      {formatError && (
        <div className="bg-red-50 border-l-4 border-red-500 p-4 rounded-r-lg flex items-start gap-2">
          <AlertTriangle className="text-red-500 mt-1 flex-shrink-0" size={16} />
          <div>
            <p className="text-sm text-red-700">{formatError}</p>
            <p className="text-xs text-red-600 mt-1">
              如果您遇到中文乱码问题，请尝试通过Google Sheets导出CSV，或点击上方的"显示帮助"查看详细解决方案。
            </p>
          </div>
        </div>
      )}
      
      {importing && <LoadingSpinner />}
      
      {importErrors.length > 0 && (
        <ImportErrors 
          errors={importErrors} 
          onClose={() => setImportErrors([])}
        />
      )}
    </div>
  );
}