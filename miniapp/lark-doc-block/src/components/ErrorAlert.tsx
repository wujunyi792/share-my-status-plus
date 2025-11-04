import type { AppError } from '../types';
import { cn } from '../utils';
import './ErrorAlert.css';

interface ErrorAlertProps {
  error: AppError;
  onDismiss?: () => void;
  className?: string;
}

export function ErrorAlert({ error, onDismiss, className }: ErrorAlertProps) {
  // 检查是否为不可重试的错误
  const isRetryable = error.details?.retryable !== false;
  
  // 根据错误代码生成友好的提示信息
  const getErrorHint = (code?: string) => {
    switch (code) {
      case 'UNAUTHORIZED':
        return '请检查您的访问链接是否正确，或联系管理员获取新的分享链接。';
      case 'INVALID_REQUEST':
        return '请求参数有误，请刷新页面重试。';
      case 'CONNECTION_FAILED':
        return '网络连接失败，请检查网络连接后刷新页面重试。';
      case 'SERVER_ERROR':
        return '服务器出现错误，请稍后再试。';
      default:
        return isRetryable ? '请稍后再试或刷新页面。' : '请联系管理员或检查访问权限。';
    }
  };

  return (
    <div className={cn('error-alert', className)}>
      <div className="error-content">
        <div className="error-icon">⚠</div>
        <div className="error-main">
          <h3 className="error-title">
            {isRetryable ? '连接错误' : '无法连接'}
          </h3>
          <div className="error-message">
            <p>{error.message}</p>
            {error.code && (
              <p className="error-code">
                错误代码: {error.code}
              </p>
            )}
            <p className="error-hint">
              {getErrorHint(error.code)}
            </p>
            {!isRetryable && (
              <p className="error-warning">
                ⚠️ 此错误无法自动重试
              </p>
            )}
          </div>
        </div>
        {onDismiss && (
          <div className="error-dismiss">
            <button
              type="button"
              className="error-dismiss-btn"
              onClick={onDismiss}
            >
              <span className="sr-only">关闭</span>
              ✕
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

