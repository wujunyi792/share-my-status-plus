import type { SystemState } from '../types';
import { 
  formatPercentage, 
  getBatteryColor, 
  getResourceColor,
  formatRelativeTime
} from '../utils';
import { cn } from '../utils';
import './SystemCard.css';

interface SystemCardProps {
  system: SystemState;
  className?: string;
}

export function SystemCard({ system, className }: SystemCardProps) {
  const batteryPct = system.batteryPct;
  const charging = system.charging;
  const cpuPct = system.cpuPct;
  const memoryPct = system.memoryPct;

  // 检查是否为空状态
  const isEmpty = !system.ts || system.ts === 0;

  const getBatteryIcon = () => {
    if (charging) {
      return '⚡';
    }
    return '🔋';
  };

  return (
    <div className={cn('system-card', className)}>
      <div className="system-content">
        {isEmpty ? (
          <div className="system-empty">
            <div className="system-item-label">
              <span className="system-icon color-gray">💻</span>
              <span className="system-label-text">暂无系统信息</span>
            </div>
          </div>
        ) : (
          <>
            {/* 电池状态 */}
            {batteryPct !== undefined && (
              <div className="system-item">
                <div className="system-item-label">
                  <span className={cn('system-icon', getBatteryColor(batteryPct, charging))}>
                    {getBatteryIcon()}
                  </span>
                  <span className="system-label-text">电池</span>
                </div>
                <div className="system-item-value">
                  <span className={cn('system-value-text', getBatteryColor(batteryPct, charging))}>
                    {formatPercentage(batteryPct)}
                  </span>
                  {charging && (
                    <div className="system-pulse-dot system-pulse-green" />
                  )}
                </div>
              </div>
            )}

            {/* CPU使用率 */}
            <div className="system-item">
              <div className="system-item-label">
                <span className={cn('system-icon', cpuPct !== undefined ? getResourceColor(cpuPct) : 'color-gray')}>
                  💻
                </span>
                <span className="system-label-text">CPU</span>
              </div>
              {cpuPct !== undefined ? (
                <span className={cn('system-value-text', getResourceColor(cpuPct))}>
                  {formatPercentage(cpuPct)}
                </span>
              ) : (
                <span className="system-value-text color-gray">-</span>
              )}
            </div>

            {/* 内存使用率 */}
            <div className="system-item">
              <div className="system-item-label">
                <span className={cn('system-icon', memoryPct !== undefined ? getResourceColor(memoryPct) : 'color-gray')}>
                  💾
                </span>
                <span className="system-label-text">内存</span>
              </div>
              {memoryPct !== undefined ? (
                <span className={cn('system-value-text', getResourceColor(memoryPct))}>
                  {formatPercentage(memoryPct)}
                </span>
              ) : (
                <span className="system-value-text color-gray">-</span>
              )}
            </div>
          </>
        )}
      </div>

      {/* 状态指示器 */}
      {!isEmpty && (
        <div className="system-status">
          <div className="system-status-item">
            <div className="system-pulse-dot system-pulse-green" />
            <span className="system-status-text">系统运行中</span>
          </div>
          
          {charging && (
            <div className="system-status-item system-status-charging">
              <span className="system-charging-icon">⚡</span>
              <span className="system-charging-text">充电中</span>
            </div>
          )}
        </div>
      )}

      {/* 更新时间 */}
      <div className="system-footer">
        <div className="system-footer-item">
          <span className="system-footer-icon">🕐</span>
          <span className="system-footer-text">更新于 {formatRelativeTime(system.ts)}</span>
        </div>
       
      </div>
    </div>
  );
}

