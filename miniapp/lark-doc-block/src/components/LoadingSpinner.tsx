import { cn } from '../utils';
import './LoadingSpinner.css';

interface LoadingSpinnerProps {
  size?: 'sm' | 'md' | 'lg';
  text?: string;
  className?: string;
}

export function LoadingSpinner({ size = 'md', text, className }: LoadingSpinnerProps) {
  const sizeClasses = {
    sm: 'spinner-sm',
    md: 'spinner-md',
    lg: 'spinner-lg',
  };

  return (
    <div className={cn('loading-spinner', className)}>
      <div className={cn('spinner', sizeClasses[size])} />
      {text && (
        <p className="loading-text">{text}</p>
      )}
    </div>
  );
}

