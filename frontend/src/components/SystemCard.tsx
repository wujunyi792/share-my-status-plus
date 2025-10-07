import { Battery, Cpu, HardDrive, Zap, Clock } from 'lucide-react';
import type { SystemState } from '@/types';
import { 
  formatPercentage, 
  getBatteryColor, 
  getResourceColor,
  formatRelativeTime
} from '@/utils';
import { cn } from '@/utils';

interface SystemCardProps {
  system: SystemState;
  className?: string;
}

export function SystemCard({ system, className }: SystemCardProps) {
  const batteryPct = system.batteryPct;
  const charging = system.charging;
  const cpuPct = system.cpuPct;
  const memoryPct = system.memoryPct;

  const getBatteryIcon = () => {
    if (batteryPct === undefined) return <Battery className="w-5 h-5" />;
    
    if (charging) {
      return <Zap className="w-5 h-5" />;
    }
    
    if (batteryPct > 0.75) {
      return <Battery className="w-5 h-5" />;
    } else if (batteryPct > 0.25) {
      return <Battery className="w-5 h-5" />;
    } else {
      return <Battery className="w-5 h-5" />;
    }
  };

  const getBatteryLevel = () => {
    if (batteryPct === undefined) return 'w-0';
    if (batteryPct > 0.75) return 'w-full';
    if (batteryPct > 0.5) return 'w-3/4';
    if (batteryPct > 0.25) return 'w-1/2';
    return 'w-1/4';
  };

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 p-4 h-full flex flex-col",
      className
    )}>
      <div className="space-y-4 flex-1">
        {/* 电池状态 */}
        {batteryPct !== undefined && (
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <div className={cn("flex-shrink-0", getBatteryColor(batteryPct, charging))}>
                {getBatteryIcon()}
              </div>
              <span className="text-sm font-medium text-gray-700">电池</span>
            </div>
            <div className="flex items-center space-x-2">
              <span className={cn("text-sm font-mono", getBatteryColor(batteryPct, charging))}>
                {formatPercentage(batteryPct)}
              </span>
              {charging && (
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
              )}
            </div>
          </div>
        )}

        {/* CPU使用率 */}
        {cpuPct !== undefined && (
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Cpu className={cn("w-5 h-5 flex-shrink-0", getResourceColor(cpuPct))} />
              <span className="text-sm font-medium text-gray-700">CPU</span>
            </div>
            <span className={cn("text-sm font-mono", getResourceColor(cpuPct))}>
              {formatPercentage(cpuPct)}
            </span>
          </div>
        )}

        {/* 内存使用率 */}
        {memoryPct !== undefined && (
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <HardDrive className={cn("w-5 h-5 flex-shrink-0", getResourceColor(memoryPct))} />
              <span className="text-sm font-medium text-gray-700">内存</span>
            </div>
            <span className={cn("text-sm font-mono", getResourceColor(memoryPct))}>
              {formatPercentage(memoryPct)}
            </span>
          </div>
        )}
      </div>

      {/* 状态指示器 */}
      <div className="mt-4 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
          <span className="text-xs text-gray-500">系统运行中</span>
        </div>
        
        {charging && (
          <div className="flex items-center space-x-1 text-green-500">
            <Zap className="w-3 h-3" />
            <span className="text-xs">充电中</span>
          </div>
        )}
      </div>

      {/* 更新时间 */}
      <div className="mt-3 pt-3 border-t border-gray-100">
        <div className="flex items-center justify-center space-x-1 text-gray-500">
          <Clock className="w-3 h-3" />
          <span className="text-xs">{formatRelativeTime(system.ts)}</span>
        </div>
      </div>
    </div>
  );
}
