import React, { useState } from 'react';
import { Users, CalendarCheck, AlertCircle, PieChart, BarChart, Calendar } from 'lucide-react';
import { Line, Pie, Bar } from 'react-chartjs-2';
import StatCard from '../common/StatCard';
import LoadingSpinner from '../common/LoadingSpinner';
import ErrorMessage from '../common/ErrorMessage';
import { useCheckInTrends } from '../../hooks/useCheckInTrends';
import { useMembershipCardStats } from '../../hooks/useMembershipCardStats';
import { useTrainerWorkload } from '../../hooks/useTrainerWorkload';

// 中国传统色彩配色
const chineseColors = {
  // 红色系
  reds: [
    '#8C1F28', // 淡枣红 DAN ZAO HONG
    '#9D2933', // 血石红 XUE SHI HONG
    '#C3272B', // 中国红 ZHONG GUO HONG
    '#CF5C35', // 蟹壳红 XIE KE HONG
    '#C87456', // 淡红瓦 DAN HONG WA
    '#F04B22', // 橙排红 CHENG FEI HONG
    '#F47983', // 珊瑚朱 SHAN HU ZHU
  ],
  // 橙色系
  oranges: [
    '#DD7E3B', // 洗柿橙 XI SHI CHENG
    '#F6A6A6', // 藏花红 CANG HUA HONG
    '#E8B49A', // 薄香橙 BO XIANG CHENG
  ],
  // 蓝色系
  blues: [
    '#283F3E', // 铜器青 TONG QI QING
    '#1D4C50', // 青灰蓝 QING HUI LAN
    '#3F605B', // 飞泉青 FEI QUAN QING
    '#0D35B1', // 唐瓷蓝 TANG CI LAN
    '#1559CF', // 琉璃蓝 LIU LI LAN
    '#7097DE', // 天水蓝 TIAN SHUI LAN
    '#1A93BC', // 钴蓝 GU LAN
  ],
  // 背景和边框
  backgrounds: [
    'rgba(195, 39, 43, 0.8)',    // 中国红
    'rgba(221, 126, 59, 0.8)',   // 洗柿橙
    'rgba(21, 89, 207, 0.8)',    // 琉璃蓝
    'rgba(112, 151, 222, 0.8)',  // 天水蓝
    'rgba(26, 147, 188, 0.8)',   // 钴蓝
    'rgba(63, 96, 91, 0.8)',     // 飞泉青
    'rgba(240, 75, 34, 0.8)',    // 橙排红
    'rgba(232, 180, 154, 0.8)',  // 薄香橙
  ],
  borders: [
    'rgb(195, 39, 43)',    // 中国红
    'rgb(221, 126, 59)',   // 洗柿橙
    'rgb(21, 89, 207)',    // 琉璃蓝
    'rgb(112, 151, 222)',  // 天水蓝
    'rgb(26, 147, 188)',   // 钴蓝
    'rgb(63, 96, 91)',     // 飞泉青
    'rgb(240, 75, 34)',    // 橙排红
    'rgb(232, 180, 154)',  // 薄香橙
  ]
};

interface DashboardStats {
  totalMembers: number;
  todayCheckins: number;
  extraCheckins: number;
  expiringMembers: number;
}

interface Props {
  stats: DashboardStats;
}

export default function Overview({ stats }: Props) {
  const { trends, loading: trendsLoading, error: trendsError } = useCheckInTrends();
  const { cardStats, loading: cardStatsLoading, error: cardStatsError } = useMembershipCardStats();
  
  // 添加时间范围选择状态
  const [timeRange, setTimeRange] = useState<'thisMonth' | 'lastMonth' | 'last3Months' | 'thisQuarter' | 'thisYear'>('thisMonth');
  
  // 更新useTrainerWorkload调用，传递timeRange参数
  const { trainerStats, loading: trainerStatsLoading, error: trainerStatsError } = useTrainerWorkload(timeRange);

  // 处理会员卡数据，计算百分比
  const processCardStats = () => {
    if (!cardStats || cardStats.length === 0) {
      return [{ type: '暂无数据', value: 1, percentage: '100%' }];
    }

    const total = cardStats.reduce((sum, stat) => sum + stat.count, 0);
    
    return cardStats.map(stat => ({
      type: stat.cardType,
      value: stat.count,
      percentage: `${Math.round((stat.count / total) * 100)}%`
    }));
  };

  // 获取处理后的会员卡分布数据
  const cardDistributionData = processCardStats();

  // 获取简化的会员卡类型（分为团课卡、儿童团课卡和私教卡）
  const simplifyCardTypes = () => {
    if (!cardStats || cardStats.length === 0) {
      return [{ type: '暂无数据', value: 1, percentage: '100%' }];
    }

    const groupTypeMap = new Map<string, number>();
    
    // 根据卡类型分组，区分团课卡、儿童团课卡和私教卡
    cardStats.forEach(stat => {
      let displayType = '';
      
      // 分类逻辑：儿童团课卡、私教卡和普通团课卡
      if (stat.cardType.includes('儿童') || stat.cardType.toLowerCase().includes('kids')) {
        displayType = '儿童团课卡';
      } else if (stat.cardType.includes('私教') || stat.cardType.toLowerCase().includes('private')) {
        displayType = '私教卡';
      } else {
        displayType = '团课卡';
      }
      
      groupTypeMap.set(
        displayType,
        (groupTypeMap.get(displayType) || 0) + stat.count
      );
    });
    
    const total = cardStats.reduce((sum, stat) => sum + stat.count, 0);
    
    // 转换为所需格式
    return Array.from(groupTypeMap.entries())
      .map(([type, value]) => ({
        type,
        value,
        percentage: `${Math.round((value / total) * 100)}%`
      }))
      .sort((a, b) => b.value - a.value);
  };

  // 获取简化后的会员卡分布数据（用于饼图）
  const simplifiedCardData = simplifyCardTypes();

  // 根据卡类型获取背景色（确保颜色一致性）
  const getCardTypeColor = (cardType: string, index: number, isBackground: boolean = false) => {
    const defaultColors = isBackground ? 
      [chineseColors.backgrounds[1], chineseColors.backgrounds[2], chineseColors.backgrounds[3]] : 
      [chineseColors.borders[1], chineseColors.borders[2], chineseColors.borders[3]];
    
    if (cardType.includes('私教')) {
      return isBackground ? chineseColors.backgrounds[2] : chineseColors.borders[2];
    } else if (cardType.includes('儿童')) {
      return isBackground ? chineseColors.backgrounds[3] : chineseColors.borders[3];
    } else if (cardType.includes('团课')) {
      return isBackground ? chineseColors.backgrounds[1] : chineseColors.borders[1];
    }
    
    // 对于其他类型，使用索引选择颜色
    return defaultColors[index % defaultColors.length];
  };

  // 教练工作量数据（按月份和教练名字显示）
  const trainerNames = ['JR', 'Da', 'Ming', 'Big', 'Bas', 'Sumay', 'First'];
  
  // 根据选择的时间范围获取月份标签和数据
  const getTimeRangeData = () => {
    // 将trainerStats数据映射到对应的教练位置
    const mapTrainerData = () => {
      // 创建默认全0数组
      const defaultData = [0, 0, 0, 0, 0, 0, 0];
      
      // 如果没有数据或加载中，返回默认数组
      if (!trainerStats || trainerStats.length === 0 || trainerStatsLoading) {
        return defaultData;
      }
      
      // 创建一个新数组，保持trainerNames的顺序
      return trainerNames.map(name => {
        // 找到匹配的教练数据
        const trainerData = trainerStats.find(
          stat => stat.trainerName.toLowerCase().includes(name.toLowerCase()) || 
                 name.toLowerCase().includes(stat.trainerName.toLowerCase())
        );
        
        // 如果找到数据，返回教练的课时数，否则返回0
        return trainerData ? trainerData.sessionCount : 0;
      });
    };
    
    // 获取当前教练数据
    const currentTrainerData = mapTrainerData();
    
    // 根据不同时间范围返回相应的数据结构
    switch(timeRange) {
      case 'thisMonth':
        return {
          labels: ['本月'],
          data: [
            { label: '本月', data: currentTrainerData }
          ]
        };
      case 'lastMonth':
        return {
          labels: ['上月'],
          data: [
            { label: '上月', data: currentTrainerData }
          ]
        };
      case 'last3Months':
        // 对于近3月，我们已经在API中获取了完整的数据，所以使用相同的数据
        return {
          labels: ['近3月'],
          data: [
            { label: '近3月', data: currentTrainerData }
          ]
        };
      case 'thisQuarter':
        // 对于本季度，我们已经在API中获取了完整的数据，所以使用相同的数据
        return {
          labels: ['本季度'],
          data: [
            { label: '本季度', data: currentTrainerData }
          ]
        };
      case 'thisYear':
        // 对于本年度，我们已经在API中获取了完整的数据，所以使用相同的数据
        return {
          labels: ['本年度'],
          data: [
            { label: '本年度', data: currentTrainerData }
          ]
        };
      default:
        return {
          labels: ['本月'],
          data: [
            { label: '本月', data: currentTrainerData }
          ]
        };
    }
  };

  // 获取当前时间范围的数据
  const timeRangeData = getTimeRangeData();

  return (
    <div className="space-y-8">
      {/* 统计卡片 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="总会员数"
          value={stats.totalMembers}
          icon={Users}
          color="bg-[#1559CF]" // 琉璃蓝
        />
        <StatCard
          title="今日总签到"
          value={stats.todayCheckins}
          icon={CalendarCheck}
          color="bg-[#DD7E3B]" // 洗柿橙
        />
        <StatCard
          title="今日额外签到"
          value={stats.extraCheckins}
          icon={AlertCircle}
          color="bg-[#C3272B]" // 中国红
        />
        <StatCard
          title="即将过期会员"
          value={stats.expiringMembers}
          icon={AlertCircle}
          color="bg-[#3F605B]" // 飞泉青
        />
      </div>

      {/* 图表区域 */}
      <div className="space-y-6">
        {/* 会员活跃度分析 */}
        <div className="bg-white rounded-lg shadow p-6 border-2 border-[#283F3E]">
          <div className="flex items-center mb-4">
            <BarChart className="w-5 h-5 text-[#C3272B] mr-2" />
            <h2 className="text-lg font-medium">会员活跃度分析 Member Activity</h2>
          </div>
          
          {trendsLoading ? (
            <LoadingSpinner />
          ) : trendsError ? (
            <ErrorMessage message={trendsError.message} />
          ) : (
            <div className="h-64">
              <Line 
                data={{
                  labels: trends.map(trend => trend.date),
                  datasets: [
                    {
                      label: '团课签到 Group Class',
                      data: trends.map(trend => trend.groupClass || 0),
                      borderColor: chineseColors.borders[2], // 琉璃蓝
                      backgroundColor: 'rgba(21, 89, 207, 0.1)',
                      tension: 0.1,
                      fill: true,
                      borderWidth: 2,
                    },
                    {
                      label: '儿童团课签到 Kids Group Class',
                      data: trends.map(trend => trend.kidsGroupClass || 0),
                      borderColor: chineseColors.borders[3] || '#34A853', // 绿色
                      backgroundColor: 'rgba(52, 168, 83, 0.1)',
                      tension: 0.1,
                      fill: true,
                      borderWidth: 2,
                    },
                    {
                      label: '私教签到 Private Class',
                      data: trends.map(trend => trend.privateClass || 0),
                      borderColor: chineseColors.borders[0], // 中国红
                      backgroundColor: 'rgba(195, 39, 43, 0.1)',
                      tension: 0.1,
                      fill: true,
                      borderWidth: 2,
                    }
                  ],
                }}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: {
                    legend: {
                      position: 'top',
                      labels: {
                        font: {
                          weight: 'bold',
                        },
                        color: '#283F3E', // 铜器青
                      }
                    },
                  },
                  scales: {
                    y: {
                      beginAtZero: true,
                      ticks: {
                        stepSize: 1,
                        color: '#283F3E', // 铜器青
                      },
                      grid: {
                        color: 'rgba(40, 63, 62, 0.1)', // 铜器青
                      }
                    },
                    x: {
                      ticks: {
                        color: '#283F3E', // 铜器青
                      },
                      grid: {
                        color: 'rgba(40, 63, 62, 0.1)', // 铜器青
                      }
                    }
                  },
                }}
              />
            </div>
          )}
        </div>

        {/* 会员卡类型分布 */}
        <div className="bg-white rounded-lg shadow p-6 border-2 border-[#283F3E]">
          <div className="flex items-center mb-4">
            <PieChart className="w-5 h-5 text-[#DD7E3B] mr-2" />
            <h2 className="text-lg font-medium">会员卡类型分布 Membership Card Distribution</h2>
          </div>
          
          {cardStatsLoading ? (
            <LoadingSpinner />
          ) : cardStatsError ? (
            <ErrorMessage message={cardStatsError.message} />
          ) : cardStats.length === 0 ? (
            <div className="text-center py-8 text-gray-500">暂无会员卡数据</div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* 简化的饼图（团课卡/私教卡） */}
              <div className="h-80">
                <Pie 
                  data={{
                    labels: simplifiedCardData.map(item => item.type),
                    datasets: [{
                      data: simplifiedCardData.map(item => item.value),
                      backgroundColor: simplifiedCardData.map((item, index) => 
                        getCardTypeColor(item.type, index, true)
                      ),
                      borderColor: simplifiedCardData.map((item, index) => 
                        getCardTypeColor(item.type, index)
                      ),
                      borderWidth: 1
                    }]
                  }}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      title: {
                        display: true,
                        text: '卡类型总览',
                        font: {
                          size: 16
                        },
                        color: chineseColors.blues[0]
                      },
                      legend: {
                        position: 'bottom',
                        labels: {
                          font: {
                            size: 14
                          },
                          color: chineseColors.blues[0]
                        }
                      },
                      tooltip: {
                        callbacks: {
                          label: function(context) {
                            const item = simplifiedCardData[context.dataIndex];
                            return `${item.type}: ${item.value}张 (${item.percentage})`;
                          }
                        }
                      }
                    }
                  }}
                />
              </div>
              
              {/* 详细会员卡类型分布表格 */}
              <div className="h-80 overflow-auto">
                <h3 className="text-md font-medium mb-3 text-center">会员卡详细分布</h3>
                <table className="w-full border-collapse">
                  <thead>
                    <tr className="bg-gray-100">
                      <th className="p-2 text-left border-b">卡类型</th>
                      <th className="p-2 text-center border-b">数量</th>
                      <th className="p-2 text-center border-b">占比</th>
                    </tr>
                  </thead>
                  <tbody>
                    {cardDistributionData.map((item, index) => (
                      <tr key={index} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                        <td className="p-2 border-b">
                          <div className="flex items-center">
                            <div 
                              className="w-3 h-3 rounded-full mr-2" 
                              style={{ 
                                backgroundColor: getCardTypeColor(item.type, index) 
                              }}
                            ></div>
                            {item.type}
                          </div>
                        </td>
                        <td className="p-2 text-center border-b">{item.value}</td>
                        <td className="p-2 text-center border-b">{item.percentage}</td>
                      </tr>
                    ))}
                    <tr className="bg-gray-100 font-semibold">
                      <td className="p-2 border-b">总计</td>
                      <td className="p-2 text-center border-b">
                        {cardDistributionData.reduce((sum, item) => sum + item.value, 0)}
                      </td>
                      <td className="p-2 text-center border-b">100%</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        {/* 教练工作量分析 - 按选择的时间范围显示私教课 */}
        <div className="bg-white rounded-lg shadow p-6 border-2 border-[#283F3E]">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center">
              <BarChart className="w-5 h-5 text-[#1A93BC] mr-2" />
              <h2 className="text-lg font-medium">教练私教课工作量分析 Trainer Private Workload</h2>
            </div>
            
            {/* 时间选择器 */}
            <div className="flex items-center space-x-2">
              <Calendar className="w-4 h-4 text-[#1A93BC]" />
              <div className="text-sm font-medium text-gray-600 mr-2">时间范围:</div>
              <div className="flex bg-gray-100 rounded-md overflow-hidden">
                <button 
                  className={`px-2 py-1 text-xs font-medium ${timeRange === 'thisMonth' ? 'bg-[#1A93BC] text-white' : 'hover:bg-gray-200'}`}
                  onClick={() => setTimeRange('thisMonth')}
                >
                  本月
                </button>
                <button 
                  className={`px-2 py-1 text-xs font-medium ${timeRange === 'lastMonth' ? 'bg-[#1A93BC] text-white' : 'hover:bg-gray-200'}`}
                  onClick={() => setTimeRange('lastMonth')}
                >
                  上月
                </button>
                <button 
                  className={`px-2 py-1 text-xs font-medium ${timeRange === 'last3Months' ? 'bg-[#1A93BC] text-white' : 'hover:bg-gray-200'}`}
                  onClick={() => setTimeRange('last3Months')}
                >
                  近3月
                </button>
                <button 
                  className={`px-2 py-1 text-xs font-medium ${timeRange === 'thisQuarter' ? 'bg-[#1A93BC] text-white' : 'hover:bg-gray-200'}`}
                  onClick={() => setTimeRange('thisQuarter')}
                >
                  本季度
                </button>
                <button 
                  className={`px-2 py-1 text-xs font-medium ${timeRange === 'thisYear' ? 'bg-[#1A93BC] text-white' : 'hover:bg-gray-200'}`}
                  onClick={() => setTimeRange('thisYear')}
                >
                  本年度
                </button>
              </div>
            </div>
          </div>
          
          {trainerStatsLoading ? (
            <LoadingSpinner />
          ) : trainerStatsError ? (
            <ErrorMessage message={trainerStatsError.message} />
          ) : (
            <div className="h-64">
              <Bar 
                data={{
                  labels: trainerNames,
                  datasets: timeRangeData.data.map((item, index) => ({
                    label: item.label,
                    data: item.data,
                    backgroundColor: chineseColors.backgrounds[index % chineseColors.backgrounds.length],
                    borderColor: chineseColors.borders[index % chineseColors.borders.length],
                    borderWidth: 1,
                  }))
                }}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  scales: {
                    y: {
                      beginAtZero: true,
                      max: 10,
                      ticks: {
                        stepSize: 2,
                        color: chineseColors.blues[0]
                      },
                      grid: {
                        color: 'rgba(40, 63, 62, 0.1)'
                      }
                    },
                    x: {
                      ticks: {
                        color: chineseColors.blues[0]
                      },
                      grid: {
                        color: 'rgba(40, 63, 62, 0.1)'
                      }
                    }
                  },
                  plugins: {
                    legend: {
                      position: 'top',
                      labels: {
                        color: chineseColors.blues[0]
                      }
                    },
                    tooltip: {
                      callbacks: {
                        label: function(context) {
                          const label = context.dataset.label || '';
                          const value = context.raw || 0;
                          return `${label}: ${value}课时`;
                        }
                      }
                    }
                  }
                }}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
} 