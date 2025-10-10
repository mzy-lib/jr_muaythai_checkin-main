import React, { useState, FormEvent } from 'react';
import type { Database } from '../../types/database';
import MemberTable from './MemberTable';
import EditMemberModal from './EditMemberModal';
import { useMemberSearch } from '../../hooks/useMemberSearch';
import LoadingSpinner from '../common/LoadingSpinner';
import ErrorMessage from '../common/ErrorMessage';
import { UserPlus } from 'lucide-react';
import AddMemberModal from './AddMemberModal';
import { formatCardInfo } from '../../utils/membership/formatters';

type Member = Database['public']['Tables']['members']['Row'];
type MembershipCard = Database['public']['Tables']['membership_cards']['Row'];
type MemberWithCards = Member & { membership_cards: MembershipCard[] };
type CardType = Database['public']['Enums']['CardType'];
type ExtendedCardType = 
  | '团课' | '私教课' | '儿童团课'  // 中文卡类型
  | 'no_card' // 其他筛选选项
  | 'private' | 'class'; // 添加额外的映射类型
type CardSubtype = Database['public']['Enums']['CardSubtype'];

// 卡类型和子类型的映射关系 - 保留原有逻辑，但使用中文名称
const cardTypeToSubtypes: Record<ExtendedCardType, string[]> = {
  'class': ['单次卡', '两次卡', '10次卡'],
  'private': ['单次卡', '10次卡'],
  '团课': ['单次卡', '两次卡', '10次卡', '单次月卡', '双次月卡'],
  '私教课': ['单次卡', '10次卡'],
  '儿童团课': ['10次卡'],
  'no_card': []
};

// 修改后的卡子类型的显示名称
const cardSubtypeLabels: Record<string, string> = {
  '单次月卡': '团课单次月卡 Single Monthly',
  '双次月卡': '团课双次月卡 Double Monthly',
  '单次卡': '单次卡 Single Class/Private',
  '两次卡': '团课两次卡 Two Classes',
  '10次卡': '10次卡 Ten Classes/Private'
};

// 卡子类型的数据库存储值映射 - 不再需要，直接使用中文值
const cardSubtypeToDbValue: Record<string, string> = {
  'single_monthly': '单次月卡',
  'double_monthly': '双次月卡',
  'single_class': '单次卡',
  'two_classes': '两次卡',
  'ten_classes': '10次卡',
  'single_private': '单次卡',
  'ten_private': '10次卡'
};

const PAGE_SIZE = 10;

// 计算会员卡有效期状态
const getCardStatus = (validUntil: string | null) => {
  if (!validUntil) return { status: 'valid' as const, text: '无有效期限制' };
  
  const now = new Date();
  const expireDate = new Date(validUntil);
  const daysLeft = Math.ceil((expireDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  
  if (daysLeft < 0) return { status: 'expired' as const, text: '已过期' };
  if (daysLeft < 7) return { status: 'warning' as const, text: `即将过期 (${daysLeft}天)` };
  return { status: 'valid' as const, text: '有效' };
};

export default function MemberList() {
  const [searchTerm, setSearchTerm] = useState('');
  const [cardTypeFilter, setCardTypeFilter] = useState<ExtendedCardType | ''>('');
  const [cardSubtypeFilter, setCardSubtypeFilter] = useState<string>('');
  const [expiryFilter, setExpiryFilter] = useState<'active' | 'upcoming' | 'expired' | 'low_classes' | ''>('');
  const [selectedMember, setSelectedMember] = useState<MemberWithCards | null>(null);
  const [_showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  
  const { 
    members, 
    totalCount,
    currentPage,
    totalPages,
    loading, 
    error,
    searchMembers,
    deleteMember,
    updateMember
  } = useMemberSearch(PAGE_SIZE);

  const handleSearch = (page: number = 1, forceRefresh: boolean = false) => {
    // 直接使用选择的卡类型和卡子类型进行搜索
    // 数据库中存储的就是中文值
    searchMembers({
      searchTerm,
      cardType: cardTypeFilter as CardType | 'no_card' | '团课' | '私教课' | '儿童团课',
      cardSubtype: cardSubtypeFilter,
      expiryStatus: expiryFilter,
      page,
      pageSize: PAGE_SIZE
    });
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    handleSearch(1);
  };
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch(1);
    }
  };

  const handlePageChange = (page: number) => {
    handleSearch(page);
  };

  const handleEdit = (member: MemberWithCards) => {
    setSelectedMember(member);
    setIsEditModalOpen(true);
  };

  const handleDelete = async (memberId: string) => {
    if (!window.confirm('确定要删除该会员吗？此操作不可撤销。\nAre you sure you want to delete this member? This action cannot be undone.')) {
      return;
    }

    try {
      await deleteMember(memberId);
      setShowDeleteConfirm(null);
      alert('会员删除成功！\nMember deleted successfully!');
    } catch (err) {
      alert(err instanceof Error ? err.message : '删除失败 Delete failed');
    }
  };

  const handleUpdate = async (memberId: string, updates: Partial<Member>) => {
    try {
      await updateMember(memberId, updates);
      setSelectedMember(null);
      setIsEditModalOpen(false);
    } catch (err) {
      console.error('Failed to update member:', err);
      throw err;
    }
  };

  // 添加刷新会员列表的方法
  const refreshMemberList = () => {
    console.log('执行刷新会员列表...');
    
    // 保留当前的筛选条件
    setTimeout(() => {
      handleSearch(currentPage, true); // 使用强制刷新
    }, 0);
  };

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error} />;

  // 确保members数组中的每个成员都有membership_cards属性
  // 由于useMemberSearch返回的members已经包含membership_cards属性
  // 这里只需要进行类型断言
  const membersWithCards = members as unknown as MemberWithCards[];

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-lg font-medium">会员列表 Member List</h2>
        <button
          onClick={() => setIsAddModalOpen(true)}
          className="inline-flex items-center px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors gap-2"
        >
          <UserPlus className="w-5 h-5" />
          <span>添加会员 Add Member</span>
        </button>
      </div>

      <div className="bg-white p-4 rounded-lg shadow">
        <h3 className="text-lg font-medium mb-4">搜索筛选 Search Filters</h3>
        <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              姓名/邮箱 Name/Email
            </label>
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              onKeyPress={handleKeyPress}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              placeholder="搜索会员姓名或邮箱..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              卡类型 Card Type
            </label>
            <select
              value={cardTypeFilter}
              onChange={(e) => {
                const newType = e.target.value as ExtendedCardType | '';
                setCardTypeFilter(newType);
                setCardSubtypeFilter(''); // 重置子类型
              }}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
            >
              <option value="">全部 All</option>
              <option value="no_card">无会员卡 No Card</option>
              <option value="团课">团课 Group Class</option>
              <option value="私教课">私教课 Private Class</option>
              <option value="儿童团课">儿童团课 Kids Class</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              卡子类型 Card Subtype
            </label>
            <select
              value={cardSubtypeFilter}
              onChange={(e) => setCardSubtypeFilter(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              disabled={cardTypeFilter === 'no_card' || !cardTypeFilter}
            >
              <option value="">全部子类型 All subtypes</option>
              {cardTypeFilter && cardTypeFilter !== 'no_card' && cardTypeToSubtypes[cardTypeFilter].map(subtype => (
                <option key={subtype} value={subtype}>
                  {cardSubtypeLabels[subtype] || subtype}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              到期状态 Expiry Status
            </label>
            <select
              value={expiryFilter}
              onChange={(e) => setExpiryFilter(e.target.value as 'active' | 'upcoming' | 'expired' | 'low_classes' | '')}
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
            >
              <option value="">全部状态 All status</option>
              <option value="active">正常 Active</option>
              <option value="upcoming">即将到期 Expiring soon</option>
              <option value="expired">已过期 Expired</option>
              <option value="low_classes">课时不足 Low Classes</option>
            </select>
          </div>

          <div className="md:col-span-3 flex justify-between items-center">
            <div className="text-sm text-gray-600">
              共 {totalCount} 条记录
            </div>
            <button
              type="submit"
              className="px-4 py-2 bg-[#4285F4] text-white rounded-lg hover:bg-blue-600 transition-colors"
            >
              搜索 Search
            </button>
          </div>
        </form>
      </div>

      <MemberTable 
        members={membersWithCards} 
        onMemberUpdated={refreshMemberList}
        onEdit={handleEdit}
        onDelete={handleDelete}
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={handlePageChange}
      />

      {/* 会员编辑模态框 */}
      {isEditModalOpen && selectedMember && (
        <EditMemberModal
          member={selectedMember as any}
          onClose={() => setIsEditModalOpen(false)}
          onUpdate={handleUpdate}
          refreshMemberList={refreshMemberList}
        />
      )}

      {/* 添加会员模态框 */}
      {isAddModalOpen && (
        <AddMemberModal
          onClose={() => setIsAddModalOpen(false)}
          onAdd={() => {
            setIsAddModalOpen(false);
            refreshMemberList(); // 添加会员后也刷新列表
          }}
        />
      )}
    </div>
  );
}
