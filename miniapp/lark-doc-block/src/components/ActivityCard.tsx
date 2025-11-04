import type { ActivityState } from '../types';
import { cn, formatRelativeTime } from '../utils';
import './ActivityCard.css';

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
    
    if (lowerLabel.includes('研发') || lowerLabel.includes('开发') || 
        lowerLabel.includes('编程') || lowerLabel.includes('代码') || 
        lowerLabel.includes('写代码') || lowerLabel.includes('coding') ||
        lowerLabel.includes('programming') || lowerLabel.includes('develop')) {
      return {
        icon: '💻',
        color: 'activity-green',
        bgColor: 'activity-bg-green',
        borderColor: 'activity-border-green',
      };
    } 
    else if (lowerLabel.includes('工作') || lowerLabel.includes('办公') || 
             lowerLabel.includes('研究') || lowerLabel.includes('学习') || 
             lowerLabel.includes('阅读')) {
      return {
        icon: '💼',
        color: 'activity-blue',
        bgColor: 'activity-bg-blue',
        borderColor: 'activity-border-blue',
      };
    } 
    else if (lowerLabel.includes('设计') || lowerLabel.includes('design')) {
      return {
        icon: '🎨',
        color: 'activity-pink',
        bgColor: 'activity-bg-pink',
        borderColor: 'activity-border-pink',
      };
    } 
    else if (lowerLabel.includes('会议') || lowerLabel.includes('讨论') || 
             lowerLabel.includes('开会') || lowerLabel.includes('meeting')) {
      return {
        icon: '👥',
        color: 'activity-orange',
        bgColor: 'activity-bg-orange',
        borderColor: 'activity-border-orange',
      };
    } 
    else if (lowerLabel.includes('浏览') || lowerLabel.includes('上网') || 
             lowerLabel.includes('browse') || lowerLabel.includes('browsing')) {
      return {
        icon: '🌐',
        color: 'activity-cyan',
        bgColor: 'activity-bg-cyan',
        borderColor: 'activity-border-cyan',
      };
    } 
    else if (lowerLabel.includes('终端') || lowerLabel.includes('terminal') || 
             lowerLabel.includes('命令行') || lowerLabel.includes('shell')) {
      return {
        icon: '⌨️',
        color: 'activity-slate',
        bgColor: 'activity-bg-slate',
        borderColor: 'activity-border-slate',
      };
    } 
    else if (lowerLabel.includes('娱乐') || lowerLabel.includes('游戏') || 
             lowerLabel.includes('音乐') || lowerLabel.includes('视频') ||
             lowerLabel.includes('entertainment')) {
      return {
        icon: '🎮',
        color: 'activity-purple',
        bgColor: 'activity-bg-purple',
        borderColor: 'activity-border-purple',
      };
    } 
    else if (lowerLabel.includes('社交') || lowerLabel.includes('聊天') || 
             lowerLabel.includes('通讯') || lowerLabel.includes('social') ||
             lowerLabel.includes('chat')) {
      return {
        icon: '💬',
        color: 'activity-emerald',
        bgColor: 'activity-bg-emerald',
        borderColor: 'activity-border-emerald',
      };
    } 
    else if (lowerLabel.includes('休息') || lowerLabel.includes('休闲') || 
             lowerLabel.includes('idle') || lowerLabel.includes('空闲')) {
      return {
        icon: '☕',
        color: 'activity-amber',
        bgColor: 'activity-bg-amber',
        borderColor: 'activity-border-amber',
      };
    } 
    else {
      return {
        icon: '⚡',
        color: 'activity-indigo',
        bgColor: 'activity-bg-indigo',
        borderColor: 'activity-border-indigo',
      };
    }
  };

  // 空状态配置
  const emptyConfig = {
    icon: '💤',
    color: 'activity-gray',
    bgColor: 'activity-bg-gray',
    borderColor: 'activity-border-gray',
  };

  const config = isEmpty ? emptyConfig : getActivityConfig(activity.label || '');

  return (
    <div className={cn('activity-card', className)}>
      <div className="activity-main">
        {/* 活动图标 */}
        <div className={cn('activity-icon-wrapper', config.bgColor, config.borderColor)}>
          {config.icon}
        </div>

        {/* 活动信息 */}
        <div className="activity-info">
          <p className={cn('activity-label', config.color)}>
            {isEmpty ? '暂无活动' : (activity.label || '-')}
          </p>
        </div>
      </div>

      {/* 更新时间 */}
      <div className="activity-footer">
        <div className="activity-footer-item">
          <span className="activity-footer-icon">📋</span>
          <span className="activity-footer-text">当前活动 更新于 {formatRelativeTime(activity.ts)}</span>
        </div>
        {!isEmpty && (
          <div className="activity-footer-item activity-footer-active">
            <div className="system-pulse-dot system-pulse-purple" />
            <span className="activity-footer-active-text">活跃</span>
          </div>
        )}
      </div>
    </div>
  );
}

