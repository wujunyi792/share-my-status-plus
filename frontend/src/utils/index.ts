import { clsx, type ClassValue } from 'clsx';
import { WSMessageType } from '@/types';

// CSS类名合并工具
export function cn(...inputs: ClassValue[]) {
  return clsx(inputs);
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

// 获取电池颜色
export function getBatteryColor(batteryPct?: number, charging?: boolean): string {
  if (charging) return 'text-green-500';
  if (batteryPct === undefined) return 'text-gray-500';
  
  if (batteryPct > 0.5) return 'text-green-500';
  if (batteryPct > 0.2) return 'text-yellow-500';
  return 'text-red-500';
}

// 获取CPU/内存颜色
export function getResourceColor(value?: number): string {
  if (value === undefined) return 'text-gray-500';
  
  if (value < 0.5) return 'text-green-500';
  if (value < 0.8) return 'text-yellow-500';
  return 'text-red-500';
}

// 生成WebSocket URL
export function getWebSocketURL(sharingKey: string): string {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  // 直接连接到后端服务器，避免通过Vite代理
  const backendHost = 'localhost:8080';
  return `${protocol}//${backendHost}/api/v1/ws?sharingKey=${encodeURIComponent(sharingKey)}`;
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

// 检查是否为移动设备
export function isMobile(): boolean {
  return window.innerWidth <= 768;
}

// 获取分享链接
export function getShareLink(sharingKey: string, redirect?: string, template?: string): string {
  const baseUrl = `${window.location.protocol}//${window.location.host}/s/${sharingKey}`;
  const params = new URLSearchParams();
  
  if (redirect) {
    params.set('r', redirect);
  }
  
  if (template) {
    params.set('m', template);
  }
  
  const queryString = params.toString();
  return queryString ? `${baseUrl}?${queryString}` : baseUrl;
}
