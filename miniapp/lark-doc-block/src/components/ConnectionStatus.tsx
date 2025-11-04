import type { WSConnectionStatus } from '../types';
import { cn } from '../utils';
import './ConnectionStatus.css';

interface ConnectionStatusProps {
  status: WSConnectionStatus;
  className?: string;
  onRetry?: () => void;
}

export function ConnectionStatus({ status, className, onRetry }: ConnectionStatusProps) {
  const getStatusConfig = (status: WSConnectionStatus) => {
    switch (status) {
      case 'connecting':
        return {
          icon: '⟳',
          text: '连接中',
          color: 'status-yellow',
          bgColor: 'status-bg-yellow',
          borderColor: 'status-border-yellow',
          animate: 'spinning',
        };
      case 'connected':
        return {
          icon: '✓',
          text: '已连接',
          color: 'status-green',
          bgColor: 'status-bg-green',
          borderColor: 'status-border-green',
          animate: '',
        };
      case 'disconnected':
        return {
          icon: '✗',
          text: '已断开',
          color: 'status-gray',
          bgColor: 'status-bg-gray',
          borderColor: 'status-border-gray',
          animate: '',
        };
      case 'error':
        return {
          icon: '⚠',
          text: '连接错误',
          color: 'status-red',
          bgColor: 'status-bg-red',
          borderColor: 'status-border-red',
          animate: '',
        };
      default:
        return {
          icon: '?',
          text: '未知状态',
          color: 'status-gray',
          bgColor: 'status-bg-gray',
          borderColor: 'status-border-gray',
          animate: '',
        };
    }
  };

  const config = getStatusConfig(status);
  const showRetryButton = (status === 'disconnected' || status === 'error' || !['connecting', 'connected'].includes(status)) && onRetry;

  return (
    <div className={cn('connection-status', config.bgColor, config.borderColor, className)}>
      <span className={cn('status-icon', config.color, config.animate)}>
        {config.icon}
      </span>
      <span className={cn('status-text', config.color)}>
        {config.text}
      </span>
      {showRetryButton && (
        <button
          type="button"
          onClick={onRetry}
          className="connection-retry-btn"
          title="重新连接"
          aria-label="重新连接"
        >
          <svg
            width="12"
            height="12"
            viewBox="0 0 12 12"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            className="connection-retry-icon"
          >
            <path
              d="M10.5 6C10.5 8.48528 8.48528 10.5 6 10.5C3.51472 10.5 1.5 8.48528 1.5 6C1.5 3.51472 3.51472 1.5 6 1.5C7.68246 1.5 9.12703 2.39958 9.79487 3.75"
              stroke="currentColor"
              strokeWidth="1.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <path
              d="M9.75 2.25L9.79487 3.75L8.25 3.70513"
              stroke="currentColor"
              strokeWidth="1.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      )}
    </div>
  );
}

