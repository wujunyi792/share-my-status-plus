import { AlertCircle, X } from 'lucide-react';
import type { AppError } from '@/types';
import { cn } from '@/utils';

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
    <div className={cn(
      "bg-red-50 border border-red-200 rounded-lg p-4",
      className
    )}>
      <div className="flex items-start">
        <div className="flex-shrink-0">
          <AlertCircle className="w-5 h-5 text-red-400" />
        </div>
        <div className="ml-3 flex-1">
          <h3 className="text-sm font-medium text-red-800">
            {isRetryable ? '连接错误' : '无法连接'}
          </h3>
          <div className="mt-2 text-sm text-red-700">
            <p>{error.message}</p>
            {error.code && (
              <p className="mt-1 font-mono text-xs text-red-600">
                错误代码: {error.code}
              </p>
            )}
            <p className="mt-2 text-xs text-red-600">
              {getErrorHint(error.code)}
            </p>
            {!isRetryable && (
              <p className="mt-2 text-xs font-semibold text-red-700 bg-red-100 px-2 py-1 rounded">
                ⚠️ 此错误无法自动重试
              </p>
            )}
          </div>
        </div>
        {onDismiss && (
          <div className="ml-auto pl-3">
            <div className="-mx-1.5 -my-1.5">
              <button
                type="button"
                className={cn(
                  "inline-flex rounded-md p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50"
                )}
                onClick={onDismiss}
              >
                <span className="sr-only">关闭</span>
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
