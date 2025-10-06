import React from 'react';
import { Activity, Clock, User } from 'lucide-react';
import type { ActivityState } from '@/types';
import { cn } from '@/utils';

interface ActivityCardProps {
  activity: ActivityState;
  className?: string;
}

export function ActivityCard({ activity, className }: ActivityCardProps) {
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
    } else if (lowerLabel.includes('会议') || lowerLabel.includes('讨论')) {
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

  const config = getActivityConfig(activity.label);

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 p-4 transition-all duration-200 hover:shadow-md",
      className
    )}>
      <div className="flex items-center space-x-4">
        {/* 活动图标 */}
        <div className={cn(
          "w-12 h-12 rounded-lg flex items-center justify-center text-2xl",
          config.bgColor,
          config.borderColor,
          "border"
        )}>
          {config.icon}
        </div>

        {/* 活动信息 */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center space-x-2 mb-1">
            <Activity className={cn("w-4 h-4", config.color)} />
            <span className="text-sm font-medium text-gray-900">
              正在做的事
            </span>
          </div>
          
          <p className={cn("text-lg font-semibold", config.color)}>
            {activity.label}
          </p>
        </div>
      </div>

      {/* 活动状态指示器 */}
      <div className="mt-4 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
          <span className="text-xs text-gray-500">活跃中</span>
        </div>
        
        <div className="flex items-center space-x-1 text-gray-500">
          <Clock className="w-3 h-3" />
          <span className="text-xs">实时更新</span>
        </div>
      </div>

      {/* 活动类型标签 */}
      <div className="mt-3">
        <span className={cn(
          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
          config.bgColor,
          config.color
        )}>
          <User className="w-3 h-3 mr-1" />
          {activity.label}
        </span>
      </div>
    </div>
  );
}
