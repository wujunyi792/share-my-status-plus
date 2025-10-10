import { Activity, Clock } from 'lucide-react';
import type { ActivityState } from '@/types';
import { cn, formatRelativeTime } from '@/utils';

interface ActivityCardProps {
  activity: ActivityState;
  className?: string;
}

export function ActivityCard({ activity, className }: ActivityCardProps) {
  // 检查是否为空状态
  const isEmpty = !activity.ts || activity.ts === 0 || !activity.label;

  // 根据活动标签获取对应的图标和颜色
  // 映射关系基于新的默认分类，同时保持对旧关键词的兼容性：
  // 💻 在搞研发: 研发/开发/编程/代码/写代码
  // 💼 在工作&研究: 工作/办公/研究/学习/阅读
  // 🎨 在设计: 设计
  // 👥 在开会: 会议/讨论/开会
  // 🌐 在浏览: 浏览/上网
  // ⌨️ 在终端: 终端/命令行
  // 🎮 在娱乐: 娱乐/游戏/音乐/视频
  // 💬 在社交: 社交/聊天/通讯
  // ☕ 休息/休闲: 休息/休闲/空闲
  // ⚡ 其他: 默认图标
  const getActivityConfig = (label: string) => {
    const lowerLabel = label.toLowerCase();
    
    // 在搞研发 - 优先级最高，因为包含更多关键词
    if (lowerLabel.includes('研发') || lowerLabel.includes('开发') || 
        lowerLabel.includes('编程') || lowerLabel.includes('代码') || 
        lowerLabel.includes('写代码') || lowerLabel.includes('coding') ||
        lowerLabel.includes('programming') || lowerLabel.includes('develop')) {
      return {
        icon: '💻',
        color: 'text-green-600',
        bgColor: 'bg-green-50',
        borderColor: 'border-green-200',
      };
    } 
    // 在工作&研究
    else if (lowerLabel.includes('工作') || lowerLabel.includes('办公') || 
             lowerLabel.includes('研究') || lowerLabel.includes('学习') || 
             lowerLabel.includes('阅读')) {
      return {
        icon: '💼',
        color: 'text-blue-600',
        bgColor: 'bg-blue-50',
        borderColor: 'border-blue-200',
      };
    } 
    // 在设计
    else if (lowerLabel.includes('设计') || lowerLabel.includes('design')) {
      return {
        icon: '🎨',
        color: 'text-pink-600',
        bgColor: 'bg-pink-50',
        borderColor: 'border-pink-200',
      };
    } 
    // 在开会
    else if (lowerLabel.includes('会议') || lowerLabel.includes('讨论') || 
             lowerLabel.includes('开会') || lowerLabel.includes('meeting')) {
      return {
        icon: '👥',
        color: 'text-orange-600',
        bgColor: 'bg-orange-50',
        borderColor: 'border-orange-200',
      };
    } 
    // 在浏览
    else if (lowerLabel.includes('浏览') || lowerLabel.includes('上网') || 
             lowerLabel.includes('browse') || lowerLabel.includes('browsing')) {
      return {
        icon: '🌐',
        color: 'text-cyan-600',
        bgColor: 'bg-cyan-50',
        borderColor: 'border-cyan-200',
      };
    } 
    // 在终端
    else if (lowerLabel.includes('终端') || lowerLabel.includes('terminal') || 
             lowerLabel.includes('命令行') || lowerLabel.includes('shell')) {
      return {
        icon: '⌨️',
        color: 'text-slate-600',
        bgColor: 'bg-slate-50',
        borderColor: 'border-slate-200',
      };
    } 
    // 在娱乐
    else if (lowerLabel.includes('娱乐') || lowerLabel.includes('游戏') || 
             lowerLabel.includes('音乐') || lowerLabel.includes('视频') ||
             lowerLabel.includes('entertainment')) {
      return {
        icon: '🎮',
        color: 'text-purple-600',
        bgColor: 'bg-purple-50',
        borderColor: 'border-purple-200',
      };
    } 
    // 在社交
    else if (lowerLabel.includes('社交') || lowerLabel.includes('聊天') || 
             lowerLabel.includes('通讯') || lowerLabel.includes('social') ||
             lowerLabel.includes('chat')) {
      return {
        icon: '💬',
        color: 'text-emerald-600',
        bgColor: 'bg-emerald-50',
        borderColor: 'border-emerald-200',
      };
    } 
    // 休息/休闲
    else if (lowerLabel.includes('休息') || lowerLabel.includes('休闲') || 
             lowerLabel.includes('idle') || lowerLabel.includes('空闲')) {
      return {
        icon: '☕',
        color: 'text-amber-600',
        bgColor: 'bg-amber-50',
        borderColor: 'border-amber-200',
      };
    } 
    // 默认/其他
    else {
      return {
        icon: '⚡',
        color: 'text-indigo-600',
        bgColor: 'bg-indigo-50',
        borderColor: 'border-indigo-200',
      };
    }
  };

  // 空状态配置
  const emptyConfig = {
    icon: '💤',
    color: 'text-gray-400',
    bgColor: 'bg-gray-50',
    borderColor: 'border-gray-200',
  };

  const config = isEmpty ? emptyConfig : getActivityConfig(activity.label || '');

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 p-6 transition-all duration-200 hover:shadow-md h-full flex flex-col justify-center",
      className
    )}>
      <div className="flex items-center space-x-4">
        {/* 活动图标 */}
        <div className={cn(
          "w-16 h-16 rounded-xl flex items-center justify-center text-3xl flex-shrink-0",
          config.bgColor,
          config.borderColor,
          "border-2 shadow-sm"
        )}>
          {config.icon}
        </div>

        {/* 活动信息 */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center space-x-2 mb-2">
            <Activity className={cn("w-4 h-4", config.color)} />
            <span className="text-sm font-medium text-gray-500">
              当前活动
            </span>
          </div>
          
          <p className={cn("text-2xl font-bold truncate", config.color)}>
            {isEmpty ? '暂无活动' : (activity.label || '-')}
          </p>
        </div>
      </div>

      {/* 更新时间 - 优化布局，提高信息密度 */}
      <div className="mt-6">
        <div className="flex items-center justify-between text-xs text-gray-500">
          <div className="flex items-center space-x-1">
            <Clock className="w-3 h-3" />
            <span>更新于 {formatRelativeTime(activity.ts)}</span>
          </div>
          {!isEmpty && (
            <div className="flex items-center space-x-1 text-purple-500">
              <div className="w-1.5 h-1.5 bg-purple-500 rounded-full animate-pulse" />
              <span>活跃</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
