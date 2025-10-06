import React from 'react';
import { AlertCircle, X } from 'lucide-react';
import type { AppError } from '@/types';
import { cn } from '@/utils';

interface ErrorAlertProps {
  error: AppError;
  onDismiss?: () => void;
  className?: string;
}

export function ErrorAlert({ error, onDismiss, className }: ErrorAlertProps) {
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
            发生错误
          </h3>
          <div className="mt-2 text-sm text-red-700">
            <p>{error.message}</p>
            {error.code && (
              <p className="mt-1 font-mono text-xs text-red-600">
                错误代码: {error.code}
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
