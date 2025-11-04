import { WSMessageType } from '../types';

// CSS类名合并工具（简化版，不使用clsx）
export function cn(...inputs: (string | undefined | null | boolean)[]): string {
  return inputs.filter(Boolean).join(' ');
}

// 格式化时间
export function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

// 格式化相对时间
export function formatRelativeTime(timestamp: number): string {
  // 处理ts为0的情况
  if (!timestamp || timestamp === 0) {
    return '暂无数据';
  }

  const now = Date.now();
  const diff = now - timestamp;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) {
    return `${days}天前`;
  } else if (hours > 0) {
    return `${hours}小时前`;
  } else if (minutes > 0) {
    return `${minutes}分钟前`;
  } else {
    return '刚刚';
  }
}

// 格式化百分比
export function formatPercentage(value: number): string {
  // 保留两位小数的百分比格式化
  return `${(value * 100).toFixed(2)}%`;
}

// 格式化电池状态
export function formatBatteryStatus(batteryPct?: number, charging?: boolean): string {
  if (batteryPct === undefined) return '未知';
  
  const percentage = Math.round(batteryPct * 100);
  const status = charging ? '充电中' : '未充电';
  return `${percentage}% (${status})`;
}

// 获取电池颜色类名（CSS类名）
export function getBatteryColor(batteryPct?: number, charging?: boolean): string {
  if (charging) return 'color-green';
  if (batteryPct === undefined) return 'color-gray';
  
  if (batteryPct > 0.5) return 'color-green';
  if (batteryPct > 0.2) return 'color-yellow';
  return 'color-red';
}

// 获取CPU/内存颜色类名（CSS类名）
export function getResourceColor(value?: number): string {
  if (value === undefined) return 'color-gray';
  
  if (value < 0.5) return 'color-green';
  if (value < 0.8) return 'color-yellow';
  return 'color-red';
}

// 生成WebSocket URL（需要传入apiBaseUrl）
export function getWebSocketURL(apiBaseUrl: string, sharingKey: string): string {
  const baseUrl = apiBaseUrl.replace(/\/$/, ''); // 移除尾部斜杠
  return `${baseUrl}/api/v1/ws?sharingKey=${encodeURIComponent(sharingKey)}`;
}

// 错误处理
export function handleError(error: any): string {
  if (error?.response?.data?.message) {
    return error.response.data.message;
  }
  if (error?.message) {
    return error.message;
  }
  return '未知错误';
}

// 导出WSMessageType
export { WSMessageType };

// 防抖函数
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: ReturnType<typeof setTimeout>;
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

// 节流函数
export function throttle<T extends (...args: any[]) => any>(
  func: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle: boolean;
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}

