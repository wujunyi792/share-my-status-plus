import React, { useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { useWebSocket } from '@/hooks/useWebSocket';
import { useAppStore } from '@/store/useAppStore';
import { MusicCard } from '@/components/MusicCard';
import { SystemCard } from '@/components/SystemCard';
import { ActivityCard } from '@/components/ActivityCard';
import { ConnectionStatus } from '@/components/ConnectionStatus';
import { ErrorAlert } from '@/components/ErrorAlert';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { formatRelativeTime } from '@/utils';
import { cn } from '@/utils';

export function StatusPage() {
  const { sharingKey } = useParams<{ sharingKey: string }>();
  const { currentState, connectionStatus, error, loading, setError } = useAppStore();

  // 演示模式：如果没有sharingKey，使用模拟数据
  const isDemoMode = !sharingKey || sharingKey === 'demo';
  
  // 模拟数据
  const demoState = {
    ts: Date.now(),
    music: {
      title: "Yellow",
      artist: "Coldplay",
      album: "Parachutes",
      coverHash: "demo-cover-hash"
    },
    system: {
      batteryPct: 0.82,
      charging: true,
      cpuPct: 0.23,
      memoryPct: 0.58
    },
    activity: {
      label: "在工作"
    }
  };

  // 初始化WebSocket连接（仅在非演示模式下）
  useWebSocket({
    sharingKey: isDemoMode ? '' : sharingKey || '',
    onMessage: (message) => {
      console.log('Received message:', message);
    },
    onError: (error) => {
      console.error('WebSocket error:', error);
    },
  });

  // 演示模式下设置模拟数据
  React.useEffect(() => {
    if (isDemoMode && !currentState) {
      useAppStore.getState().setCurrentState(demoState);
      useAppStore.getState().setConnectionStatus('connected');
    }
  }, [isDemoMode, currentState]);

  // 清除错误
  const handleDismissError = () => {
    setError(null);
  };

  // 如果没有sharingKey，显示错误
  if (!sharingKey) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">无效的分享链接</h1>
          <p className="text-gray-600">请检查链接是否正确</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* 头部 */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                {isDemoMode ? '演示模式 - 实时状态' : '实时状态'}
              </h1>
              <p className="text-gray-600 mt-1">
                {isDemoMode ? '演示数据展示' : `分享链接: /s/${sharingKey}`}
              </p>
            </div>
            <ConnectionStatus status={connectionStatus} />
          </div>
        </div>
      </div>

      {/* 主要内容 */}
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* 错误提示 */}
        {error && (
          <div className="mb-6">
            <ErrorAlert error={error} onDismiss={handleDismissError} />
          </div>
        )}

        {/* 加载状态 */}
        {loading && !currentState && (
          <div className="flex items-center justify-center py-12">
            <LoadingSpinner size="lg" text="正在加载状态..." />
          </div>
        )}

        {/* 状态内容 */}
        {currentState && (
          <div className="space-y-6">
            {/* 状态卡片网格 */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {/* 音乐状态 */}
              {currentState.music && (
                <div className="md:col-span-2 lg:col-span-2">
                  <MusicCard music={currentState.music} />
                </div>
              )}

              {/* 系统状态 */}
              {currentState.system && (
                <SystemCard system={currentState.system} />
              )}

              {/* 活动状态 */}
              {currentState.activity && (
                <div className="md:col-span-2 lg:col-span-3">
                  <ActivityCard activity={currentState.activity} />
                </div>
              )}
            </div>

            {/* 状态信息 */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">状态信息</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <dt className="text-sm font-medium text-gray-500">最后更新时间</dt>
                  <dd className="mt-1 text-sm text-gray-900">
                    {formatRelativeTime(currentState.ts)}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">连接状态</dt>
                  <dd className="mt-1">
                    <ConnectionStatus status={connectionStatus} />
                  </dd>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 无数据状态 */}
        {!loading && !currentState && !error && (
          <div className="text-center py-12">
            <div className="mx-auto h-24 w-24 text-gray-400 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">暂无状态数据</h3>
            <p className="text-gray-600">
              等待设备上报状态信息...
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
