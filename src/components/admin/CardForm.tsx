import React, { useState, FormEvent, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Database } from '../../types/database';

type MembershipCard = Database['public']['Tables']['membership_cards']['Row'];
type TrainerType = Database['public']['Enums']['TrainerType'];

interface CardFormProps {
  memberId: string;
  card?: MembershipCard;
  onSave: (card: MembershipCard) => Promise<void>;
  onCancel: () => void;
}

export default function CardForm({ memberId, card, onSave, onCancel }: CardFormProps) {
  const [formData, setFormData] = useState<Partial<MembershipCard>>(
    card || {
      member_id: memberId,
      card_type: '',
      card_category: '',
      card_subtype: '',
      trainer_type: null,
      remaining_group_sessions: null,
      remaining_private_sessions: null,
      remaining_kids_sessions: null,
      valid_until: null
    }
  );
  
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 修改卡类型选项，使用中文
  const cardTypeOptions = [
    { value: '团课', label: '团课 Group' },
    { value: '私教课', label: '私教课 Private' },
    { value: '儿童团课', label: '儿童团课 Kids' }
  ];

  // 修改卡类别选项，使用中文
  const getCardCategoryOptions = (cardType: string) => {
    if (cardType === '团课') {
      return [
        { value: '课时卡', label: '课时卡' },
        { value: '月卡', label: '月卡' }
      ];
    }
    return [];
  };

  // 修改卡子类型选项，使用中文
  const getCardSubtypeOptions = (cardType: string, cardCategory: string) => {
    if (cardType === '团课') {
      if (cardCategory === '课时卡') {
        return [
          { value: '单次卡', label: '单次卡' },
          { value: '两次卡', label: '两次卡' },
          { value: '10次卡', label: '10次卡' }
        ];
      } else if (cardCategory === '月卡') {
        return [
          { value: '单次月卡', label: '单次月卡' },
          { value: '双次月卡', label: '双次月卡' }
        ];
      }
    } else if (cardType === '私教课') {
      return [
        { value: '单次卡', label: '单次卡' },
        { value: '10次卡', label: '10次卡' }
      ];
    } else if (cardType === '儿童团课') {
      return [
        { value: '10次卡', label: '10次卡' }
      ];
    }
    return [];
  };

  // 教练类型选项
  const trainerTypeOptions = [
    { value: 'jr', label: 'JR教练' },
    { value: 'senior', label: '高级教练' }
  ];

  // 处理表单字段变化
  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target;
    
    // 处理数字类型的输入
    if (type === 'number') {
      setFormData({
        ...formData,
        [name]: value === '' ? null : parseInt(value, 10)
      });
    } else if (name === 'valid_until') {
      // 直接存储日期字符串，不进行转换，在提交时再处理
      setFormData({
        ...formData,
        [name]: value || null
      });
    } else {
      setFormData({
        ...formData,
        [name]: value
      });
    }

    // 清除该字段的错误
    if (errors[name]) {
      setErrors({
        ...errors,
        [name]: ''
      });
    }

    // 根据卡类型重置相关字段
    if (name === 'card_type') {
      if (value === '儿童团课') {
        setFormData(prev => ({
          ...prev,
          card_category: '课时卡',
          card_subtype: '10次卡',
          remaining_kids_sessions: 10,
          remaining_group_sessions: null,
          remaining_private_sessions: null,
          trainer_type: null
        }));
      } else {
        setFormData(prev => ({
          ...prev,
          card_category: value === '团课' ? '' : null,
          card_subtype: '',
          trainer_type: value === '私教课' ? '' : null,
          remaining_group_sessions: value === '团课' ? null : null,
          remaining_private_sessions: value === '私教课' ? null : null,
          remaining_kids_sessions: null
        }));
      }
    }

    // 根据卡类别重置子类型
    if (name === 'card_category') {
      setFormData(prev => ({
        ...prev,
        card_subtype: ''
      }));
    }

    // 根据子类型设置默认课时数
    if (name === 'card_subtype') {
      if (formData.card_type === '团课' && formData.card_category === '课时卡') {
        let sessions = null;
        if (value === '单次卡') sessions = 1;
        else if (value === '两次卡') sessions = 2;
        else if (value === '10次卡') sessions = 10;
        
        setFormData(prev => ({
          ...prev,
          remaining_group_sessions: sessions
        }));
      } else if (formData.card_type === '私教课') {
        let sessions = null;
        if (value === '单次卡') sessions = 1;
        else if (value === '10次卡') sessions = 10;
        
        setFormData(prev => ({
          ...prev,
          remaining_private_sessions: sessions
        }));
      } else if (formData.card_type === '儿童团课') {
        setFormData(prev => ({
          ...prev,
          remaining_kids_sessions: 10
        }));
      }
    }
  };

  // 初始化时，如果是儿童团课，自动设置相关字段
  useEffect(() => {
    if (formData.card_type === '儿童团课') {
      setFormData(prev => ({
        ...prev,
        card_category: '课时卡',
        card_subtype: '10次卡',
        remaining_kids_sessions: formData.remaining_kids_sessions || 10
      }));
    }
  }, []);

  // 表单提交处理
  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrors({});

    try {
      // 验证表单
      const validationErrors: Record<string, string> = {};
      
      if (!formData.card_type) {
        validationErrors.card_type = '请选择卡类型';
      }
      
      if (formData.card_type === '团课' && !formData.card_category) {
        validationErrors.card_category = '请选择卡种类';
      }
      
      if (!formData.card_subtype) {
        validationErrors.card_subtype = '请选择具体类型';
      }
      
      if (formData.card_type === '私教课' && !formData.trainer_type) {
        validationErrors.trainer_type = '请选择教练类型';
      }
      
      if (Object.keys(validationErrors).length > 0) {
        setErrors(validationErrors);
        setLoading(false);
        return;
      }

      // 创建要提交的卡数据副本
      let finalFormData = { ...formData };
      
      // 特别处理有效期字段
      if (finalFormData.valid_until) {
        // 确保日期格式正确，转换为ISO字符串
        const dateObj = new Date(finalFormData.valid_until);
        if (!isNaN(dateObj.getTime())) {
          // 将日期设置为当天的23:59:59，确保整天有效
          dateObj.setHours(23, 59, 59, 999);
          finalFormData.valid_until = dateObj.toISOString();
        } else {
          console.error('无效的日期格式:', finalFormData.valid_until);
          setErrors({ submit: '无效的日期格式，请确保日期格式正确' });
          setLoading(false);
          return;
        }
      } else {
        // 确保null而不是undefined或空字符串
        finalFormData.valid_until = null;
      }
      
      // 标准化卡类型
      let standardizedCard = { ...finalFormData };
      
      // 根据readme.md中的定义标准化卡类型
      if (formData.card_type === '团课' || formData.card_type?.toLowerCase() === 'class' || formData.card_type?.toLowerCase() === 'group') {
        standardizedCard.card_type = '团课';
        
        if (formData.card_category?.toLowerCase() === 'session' || formData.card_category?.toLowerCase() === 'sessions') {
          standardizedCard.card_category = '课时卡';
        } else if (formData.card_category?.toLowerCase() === 'monthly') {
          standardizedCard.card_category = '月卡';
        }
        
        // 标准化子类型
        if (formData.card_subtype?.toLowerCase().includes('single') && formData.card_category?.toLowerCase() !== 'monthly') {
          standardizedCard.card_subtype = '单次卡';
        } else if (formData.card_subtype?.toLowerCase().includes('two') && formData.card_category?.toLowerCase() !== 'monthly') {
          standardizedCard.card_subtype = '两次卡';
        } else if (formData.card_subtype?.toLowerCase().includes('ten') || formData.card_subtype?.toLowerCase().includes('10')) {
          standardizedCard.card_subtype = '10次卡';
        } else if (formData.card_subtype?.toLowerCase().includes('single') && formData.card_category?.toLowerCase() === 'monthly') {
          standardizedCard.card_subtype = '单次月卡';
        } else if (formData.card_subtype?.toLowerCase().includes('double')) {
          standardizedCard.card_subtype = '双次月卡';
        }
      } else if (formData.card_type === '私教课' || formData.card_type === '私教' || formData.card_type?.toLowerCase() === 'private') {
        standardizedCard.card_type = '私教课';
        
        // 标准化子类型
        if (formData.card_subtype?.toLowerCase().includes('single')) {
          standardizedCard.card_subtype = '单次卡';
        } else if (formData.card_subtype?.toLowerCase().includes('ten') || formData.card_subtype?.toLowerCase().includes('10')) {
          standardizedCard.card_subtype = '10次卡';
        }
      } else if (formData.card_type === '儿童团课' || formData.card_type?.toLowerCase() === 'kids_group') {
        standardizedCard.card_type = '儿童团课';
        standardizedCard.card_category = '课时卡';
        standardizedCard.card_subtype = '10次卡';
      }
      
      // 调用父组件的保存函数
      await onSave(standardizedCard as MembershipCard);
    } catch (error) {
      console.error('保存会员卡失败:', error);
      setErrors({ submit: error instanceof Error ? error.message : '保存会员卡失败，请重试' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">
          卡类型 Card Type
        </label>
        <select
          name="card_type"
          value={formData.card_type || ''}
          onChange={(e) => {
            const newType = e.target.value;
            handleChange(e);
            
            // 自动设置儿童团课卡的默认值
            if (newType === '儿童团课') {
              setFormData(prev => ({
                ...prev,
                card_type: '儿童团课',
                card_category: '课时卡', 
                card_subtype: '10次卡',
                remaining_kids_sessions: 10
              }));
            }
          }}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          required
        >
          <option value="">请选择卡类型...</option>
          {cardTypeOptions.map(option => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        {errors.card_type && <p className="mt-1 text-sm text-red-600">{errors.card_type}</p>}
      </div>

      {formData.card_type === '团课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            卡种类 Card Category
          </label>
          <select
            name="card_category"
            value={formData.card_category || ''}
            onChange={handleChange}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            required
          >
            <option value="">请选择卡种类...</option>
            {getCardCategoryOptions(formData.card_type).map(option => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
          {errors.card_category && <p className="mt-1 text-sm text-red-600">{errors.card_category}</p>}
        </div>
      )}

      {formData.card_type === '儿童团课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            卡种类 Card Category
          </label>
          <div className="mt-1 p-2 bg-gray-100 rounded">
            课时卡
          </div>
        </div>
      )}

      {(formData.card_type === '团课' || formData.card_type === '私教课') && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            具体类型 Card Subtype
          </label>
          <select
            name="card_subtype"
            value={formData.card_subtype || ''}
            onChange={handleChange}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            required
          >
            <option value="">请选择具体类型...</option>
            {getCardSubtypeOptions(formData.card_type, formData.card_category || '').map(option => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
          {errors.card_subtype && <p className="mt-1 text-sm text-red-600">{errors.card_subtype}</p>}
        </div>
      )}

      {formData.card_type === '儿童团课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            具体类型 Card Subtype
          </label>
          <div className="mt-1 p-2 bg-gray-100 rounded">
            10次卡
          </div>
        </div>
      )}

      {formData.card_type === '私教课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            教练类型 Trainer Type
          </label>
          <select
            name="trainer_type"
            value={formData.trainer_type || ''}
            onChange={handleChange}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            required
          >
            <option value="">请选择教练类型...</option>
            {trainerTypeOptions.map(option => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
          {errors.trainer_type && <p className="mt-1 text-sm text-red-600">{errors.trainer_type}</p>}
        </div>
      )}

      {formData.card_type === '团课' && formData.card_category === '课时卡' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            剩余团课课时 Remaining Group Sessions
          </label>
          <input
            type="number"
            name="remaining_group_sessions"
            value={formData.remaining_group_sessions === null ? '' : formData.remaining_group_sessions}
            onChange={handleChange}
            min="0"
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>
      )}

      {formData.card_type === '私教课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700">
            剩余私教课时 Remaining Private Sessions
          </label>
          <input
            type="number"
            name="remaining_private_sessions"
            value={formData.remaining_private_sessions === null ? '' : formData.remaining_private_sessions}
            onChange={handleChange}
            min="0"
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>
      )}

      {formData.card_type === '儿童团课' && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            剩余儿童团课次数
          </label>
          <input
            type="number"
            min="0"
            value={formData.remaining_kids_sessions === null ? '' : formData.remaining_kids_sessions}
            onChange={(e) => setFormData({
              ...formData,
              remaining_kids_sessions: e.target.value ? parseInt(e.target.value) : null
            })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md"
          />
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700">
          有效期至 Valid Until
        </label>
        <input
          type="date"
          name="valid_until"
          value={formData.valid_until ? new Date(formData.valid_until).toISOString().split('T')[0] : ''}
          onChange={handleChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        />
        <p className="mt-1 text-xs text-gray-500">
          留空表示无到期限制。系统会根据卡类型自动设置有效期。
        </p>
      </div>

      {errors.submit && (
        <div className="rounded-md bg-red-50 p-4">
          <div className="flex">
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">保存失败</h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{errors.submit}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="flex justify-end space-x-3 pt-4">
        <button
          type="button"
          onClick={onCancel}
          className="rounded-md border border-gray-300 bg-white py-2 px-4 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
          disabled={loading}
        >
          取消 Cancel
        </button>
        <button
          type="submit"
          className="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
          disabled={loading}
        >
          {loading ? '保存中...' : '保存 Save'}
        </button>
      </div>
    </form>
  );
} 