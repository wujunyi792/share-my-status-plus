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
  const getActivityConfig = (label: string) => {
    const lowerLabel = label.toLowerCase();
    
    if (lowerLabel.includes('工作') || lowerLabel.includes('办公')) {
      return {
        icon: '💼',
        color: 'text-blue-600',
        bgColor: 'bg-blue-50',
        borderColor: 'border-blue-200',
      };
    } else if (lowerLabel.includes('代码') || lowerLabel.includes('编程') || lowerLabel.includes('开发')) {
      return {
        icon: '💻',
        color: 'text-green-600',
        bgColor: 'bg-green-50',
        borderColor: 'border-green-200',
      };
    } else if (lowerLabel.includes('学习') || lowerLabel.includes('阅读')) {
      return {
        icon: '📚',
        color: 'text-purple-600',
        bgColor: 'bg-purple-50',
        borderColor: 'border-purple-200',
      };
    } else if (lowerLabel.includes('会议') || lowerLabel.includes('讨论') || lowerLabel.includes('开会')) {
      return {
        icon: '👥',
        color: 'text-orange-600',
        bgColor: 'bg-orange-50',
        borderColor: 'border-orange-200',
      };
    } else if (lowerLabel.includes('休息') || lowerLabel.includes('休闲')) {
      return {
        icon: '☕',
        color: 'text-gray-600',
        bgColor: 'bg-gray-50',
        borderColor: 'border-gray-200',
      };
    } else {
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

      {/* 更新时间 */}
      <div className="mt-6 pt-4 border-t border-gray-100">
        <div className="flex items-center justify-center space-x-1 text-gray-500">
          <Clock className="w-3 h-3" />
          <span className="text-xs">{formatRelativeTime(activity.ts)}</span>
        </div>
      </div>
    </div>
  );
}
