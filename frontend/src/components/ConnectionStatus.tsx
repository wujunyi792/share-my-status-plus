import React from 'react';
import { Wifi, WifiOff, AlertCircle, Loader2 } from 'lucide-react';
import type { WSConnectionStatus } from '@/types';
import { cn } from '@/utils';

interface ConnectionStatusProps {
  status: WSConnectionStatus;
  className?: string;
}

export function ConnectionStatus({ status, className }: ConnectionStatusProps) {
  const getStatusConfig = (status: WSConnectionStatus) => {
    switch (status) {
      case 'connecting':
        return {
          icon: Loader2,
          text: '连接中',
          color: 'text-yellow-600',
          bgColor: 'bg-yellow-50',
          borderColor: 'border-yellow-200',
          animate: 'animate-spin',
        };
      case 'connected':
        return {
          icon: Wifi,
          text: '已连接',
          color: 'text-green-600',
          bgColor: 'bg-green-50',
          borderColor: 'border-green-200',
          animate: '',
        };
      case 'disconnected':
        return {
          icon: WifiOff,
          text: '已断开',
          color: 'text-gray-600',
          bgColor: 'bg-gray-50',
          borderColor: 'border-gray-200',
          animate: '',
        };
      case 'error':
        return {
          icon: AlertCircle,
          text: '连接错误',
          color: 'text-red-600',
          bgColor: 'bg-red-50',
          borderColor: 'border-red-200',
          animate: '',
        };
      default:
        return {
          icon: WifiOff,
          text: '未知状态',
          color: 'text-gray-600',
          bgColor: 'bg-gray-50',
          borderColor: 'border-gray-200',
          animate: '',
        };
    }
  };

  const config = getStatusConfig(status);
  const IconComponent = config.icon;

  return (
    <div className={cn(
      "inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium border",
      config.bgColor,
      config.borderColor,
      className
    )}>
      <IconComponent className={cn(
        "w-4 h-4 mr-2",
        config.color,
        config.animate
      )} />
      <span className={config.color}>
        {config.text}
      </span>
    </div>
  );
}
