import React, { useState, useEffect, useCallback } from 'react';
import { BarChart3, TrendingUp, Music, Calendar, ChevronDown, ChevronUp, Database, RefreshCw, Disc3 } from 'lucide-react';
import { apiClient } from '@/utils/api';
import { useStats, useAppStoreActions } from '@/store/useAppStore';
import type { StatsQueryRequest, TopItem } from '@/types';
import { WindowType } from '@/types';
import { cn } from '@/utils';

interface StatsCardProps {
  className?: string;
  sharingKey?: string;
}

const windowTypeOptions = [
  { value: WindowType.ROLLING_3D, label: '最近3天' },
  { value: WindowType.ROLLING_7D, label: '最近7天' },
  { value: WindowType.MONTH_TO_DATE, label: '本月至今' },
  { value: WindowType.YEAR_TO_DATE, label: '今年至今' },
] as const;

const topNOptions = [
  { value: 3, label: 'Top 3' },
  { value: 5, label: 'Top 5' },
  { value: 10, label: 'Top 10' },
  { value: 20, label: 'Top 20' },
] as const;

export function StatsCard({ className, sharingKey }: StatsCardProps) {
  const [selectedWindow, setSelectedWindow] = useState<WindowType>(WindowType.ROLLING_7D);
  const [topN, setTopN] = useState<number>(5);
  const [isExpanded, setIsExpanded] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // Use precise selectors to avoid unnecessary re-renders
  const stats = useStats();
  const { setStats } = useAppStoreActions();

  const loadStats = useCallback(async () => {
    console.log('Loading stats for sharingKey:', sharingKey);
    setIsLoading(true);
    setError(null);
    
    try {
      const request: StatsQueryRequest = {
        window: {
          type: selectedWindow,
          tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
        },
        metrics: ['plays', 'unique_tracks', 'top_artists', 'top_tracks', 'top_albums'],
        topN: topN,
      };

      const response = await apiClient.queryStats(request, sharingKey);
      setStats(response);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : '加载统计数据失败';
      setError(errorMessage);
      console.error('Failed to load stats:', err);
    } finally {
      setIsLoading(false);
    }
  }, [sharingKey, selectedWindow, topN, setStats]);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  const formatCount = (count: number) => {
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}k`;
    }
    return count.toString();
  };

  const renderTopList = (items: TopItem[] | undefined, title: string, icon: React.ReactNode) => {
    if (!items || items.length === 0) {
      return (
        <div className="text-center py-4 text-gray-500">
          <div className="mb-2">{icon}</div>
          <p className="text-sm">暂无{title}数据</p>
        </div>
      );
    }

    return (
      <div className="space-y-2">
        <div className="flex items-center gap-2 text-sm font-medium text-gray-700">
          {icon}
          <span>{title}</span>
        </div>
        <div className="space-y-1">
          {items.slice(0, Math.min(topN, items.length)).map((item, index) => (
            <div key={index} className="flex items-center justify-between text-sm">
              <span className="truncate flex-1 mr-2" title={item.name}>
                {item.name}
              </span>
              <span className="text-gray-500 font-mono text-xs">
                {formatCount(item.count)}
              </span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden",
      className
    )}>
      {/* 头部 */}
      <div className="p-4 border-b border-gray-100">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-2 bg-purple-100 rounded-lg">
              <BarChart3 className="w-5 h-5 text-purple-600" />
            </div>
            <div>
              <h3 className="font-semibold text-gray-900">音乐统计</h3>
              <p className="text-sm text-gray-500">聚合播放数据</p>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            {/* 刷新按钮 */}
            <button
              onClick={loadStats}
              className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
              disabled={isLoading}
              title="刷新统计数据"
            >
              <RefreshCw className={cn(
                "w-4 h-4 text-gray-500",
                isLoading && "animate-spin"
              )} />
            </button>
            
            {/* 时间窗口选择器 */}
            <select
              value={selectedWindow}
              onChange={(e) => setSelectedWindow(Number(e.target.value) as WindowType)}
              className="text-sm border border-gray-200 rounded-lg px-3 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              disabled={isLoading}
            >
              {windowTypeOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            
            {/* TopN选择器 */}
            <select
              value={topN}
              onChange={(e) => setTopN(Number(e.target.value))}
              className="text-sm border border-gray-200 rounded-lg px-3 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              disabled={isLoading}
            >
              {topNOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            
            {/* 展开/收起按钮 */}
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
              disabled={isLoading}
            >
              {isExpanded ? (
                <ChevronUp className="w-4 h-4 text-gray-500" />
              ) : (
                <ChevronDown className="w-4 h-4 text-gray-500" />
              )}
            </button>
          </div>
        </div>
      </div>

      {/* 内容区域 */}
      <div className="p-4">
        {isLoading && (
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-600"></div>
            <span className="ml-2 text-sm text-gray-500">加载中...</span>
          </div>
        )}

        {error && (
          <div className="text-center py-4">
            <p className="text-sm text-red-600 mb-2">{error}</p>
            <button
              onClick={loadStats}
              className="text-sm text-purple-600 hover:text-purple-700 font-medium"
            >
              重试
            </button>
          </div>
        )}

        {!isLoading && !error && stats && (
          <div className="space-y-4">
            {/* 统计摘要 */}
            {stats.summary && (
              <div className="grid grid-cols-2 gap-4">
                {stats.summary.plays !== undefined && (
                  <div className="text-center p-3 bg-gradient-to-br from-blue-50 to-cyan-50 rounded-lg">
                    <div className="text-2xl font-bold text-blue-600">
                      {formatCount(stats.summary.plays)}
                    </div>
                    <div className="text-sm text-gray-600">总播放次数</div>
                  </div>
                )}
                
                {stats.summary.uniqueTracks !== undefined && (
                  <div className="text-center p-3 bg-gradient-to-br from-green-50 to-emerald-50 rounded-lg">
                    <div className="text-2xl font-bold text-green-600">
                      {formatCount(stats.summary.uniqueTracks)}
                    </div>
                    <div className="text-sm text-gray-600">不同歌曲</div>
                  </div>
                )}
              </div>
            )}

            {/* 详细统计 - 可展开 */}
            {isExpanded && (
              <div className="space-y-4 pt-2 border-t border-gray-100">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* 艺术家 */}
                  <div className="p-3 bg-gray-50 rounded-lg">
                    {renderTopList(
                      stats.topArtists,
                      '艺术家',
                      <Music className="w-4 h-4 text-purple-600" />
                    )}
                  </div>

                  {/* 歌曲 */}
                  <div className="p-3 bg-gray-50 rounded-lg">
                    {renderTopList(
                      stats.topTracks,
                      '歌曲',
                      <TrendingUp className="w-4 h-4 text-purple-600" />
                    )}
                  </div>

                  {/* 专辑 */}
                  <div className="p-3 bg-gray-50 rounded-lg">
                    {renderTopList(
                      stats.topAlbums,
                      '专辑',
                      <Disc3 className="w-4 h-4 text-purple-600" />
                    )}
                  </div>
                </div>

                {/* 统计窗口信息 */}
                {stats.window && (
                  <div className="text-xs text-gray-500 flex items-center gap-1 mb-2">
                    <Calendar className="w-3 h-3" />
                    <span>
                      统计时间: {windowTypeOptions.find(opt => opt.value === stats.window?.type)?.label}
                      {stats.window.fromTs && stats.window.toTs && (
                        <span className="ml-1">
                          ({new Date(stats.window.fromTs).toLocaleString()} - {new Date(stats.window.toTs).toLocaleString()})
                        </span>
                      )}
                    </span>
                  </div>
                )}

                {/* 缓存状态指示器 */}
                {stats.cached !== undefined && (
                  <div className="text-xs flex items-center gap-1">
                    <Database className="w-3 h-3" />
                    <span className={cn(
                      "px-2 py-1 rounded-full text-xs font-medium",
                      stats.cached 
                        ? "bg-green-100 text-green-700" 
                        : "bg-blue-100 text-blue-700"
                    )}>
                      {stats.cached ? "缓存数据" : "实时数据"}
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* 空状态 */}
            {!stats.summary && !stats.topArtists && !stats.topTracks && !stats.topAlbums && (
              <div className="text-center py-8 text-gray-500">
                <BarChart3 className="w-12 h-12 mx-auto mb-3 text-gray-300" />
                <p className="text-sm">暂无统计数据</p>
                <p className="text-xs text-gray-400 mt-1">播放音乐后且开启统计授权后，将显示统计信息</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}