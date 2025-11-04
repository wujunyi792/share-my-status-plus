import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../utils/api';
import { useAppStore } from '../store/useAppStore';
import type { StatsQueryRequest, TopItem, WindowType } from '../types';
import { WindowType as WT } from '../types';
import { cn } from '../utils';
import './StatsCard.css';

interface StatsCardProps {
  className?: string;
  sharingKey: string;
  apiBaseUrl: string;
  enabled?: boolean; // 是否启用统计功能
}

const windowTypeOptions = [
  { value: WT.ROLLING_3D, label: '最近3天' },
  { value: WT.ROLLING_7D, label: '最近7天' },
  { value: WT.MONTH_TO_DATE, label: '本月至今' },
  { value: WT.YEAR_TO_DATE, label: '今年至今' },
] as const;

const topNOptions = [
  { value: 3, label: 'Top 3' },
  { value: 5, label: 'Top 5' },
  { value: 10, label: 'Top 10' },
  { value: 20, label: 'Top 20' },
] as const;

export function StatsCard({ className, sharingKey, apiBaseUrl, enabled = true }: StatsCardProps) {
  const [selectedWindow, setSelectedWindow] = useState<WindowType>(WT.ROLLING_7D);
  const [topN, setTopN] = useState<number>(5);
  const [isExpanded, setIsExpanded] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const { stats, setStats } = useAppStore();

  const loadStats = useCallback(async () => {
    if (!enabled || !sharingKey) {
      return;
    }
    
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

      const response = await apiClient.queryStats(request, sharingKey, apiBaseUrl);
      setStats(response);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : '加载统计数据失败';
      setError(errorMessage);
      console.error('Failed to load stats:', err);
    } finally {
      setIsLoading(false);
    }
  }, [sharingKey, selectedWindow, topN, setStats, enabled, apiBaseUrl]);

  useEffect(() => {
    if (enabled && sharingKey) {
      loadStats();
    }
  }, [enabled, loadStats, sharingKey]);

  const formatCount = (count: number) => {
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}k`;
    }
    return count.toString();
  };

  const renderTopList = (items: TopItem[] | undefined, title: string, icon: string) => {
    if (!items || items.length === 0) {
      return (
        <div className="stats-top-empty">
          <div className="stats-top-empty-icon">{icon}</div>
          <p className="stats-top-empty-text">暂无{title}数据</p>
        </div>
      );
    }

    return (
      <div className="stats-top-list">
        <div className="stats-top-header">
          <span className="stats-top-icon">{icon}</span>
          <span className="stats-top-title">{title}</span>
        </div>
        <div className="stats-top-items">
          {items.slice(0, Math.min(topN, items.length)).map((item, index) => (
            <div key={index} className="stats-top-item">
              <span className="stats-top-item-name" title={item.name}>
                {item.name}
              </span>
              <span className="stats-top-item-count">
                {formatCount(item.count)}
              </span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className={cn('stats-card', className)}>
      {/* 头部 */}
      <div className="stats-header">
        <div className="stats-header-left">
          <div className="stats-header-icon">📊</div>
          <div>
            <h3 className="stats-title">音乐统计</h3>
            <p className="stats-subtitle">聚合播放数据</p>
          </div>
        </div>
        
        {/* 右侧控制按钮 */}
        <div className="stats-controls">
          {/* 刷新按钮 */}
          <button
            onClick={loadStats}
            className="stats-control-btn"
            disabled={isLoading}
            title="刷新统计数据"
          >
            <span className={cn('stats-refresh-icon', isLoading ? 'spinning' : '')}>
              🔄
            </span>
          </button>
          
          {/* 时间窗口选择器 */}
          <select
            value={selectedWindow}
            onChange={(e) => setSelectedWindow(Number(e.target.value) as WindowType)}
            className="stats-select"
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
            className="stats-select"
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
            className="stats-control-btn"
            disabled={isLoading}
          >
            <span className="stats-expand-icon">{isExpanded ? '▲' : '▼'}</span>
          </button>
        </div>
      </div>

      {/* 内容区域 */}
      <div className="stats-body">
        {isLoading && (
          <div className="stats-loading">
            <div className="spinner spinner-md" />
            <span className="stats-loading-text">加载中...</span>
          </div>
        )}

        {error && (
          <div className="stats-error">
            <p className="stats-error-text">{error}</p>
            <button
              onClick={loadStats}
              className="stats-error-retry"
            >
              重试
            </button>
          </div>
        )}

        {/* 未授权提示 */}
        {!isLoading && !error && stats?.base?.code === 403 && (
          <div className="stats-unauthorized">
            <span className="stats-unauthorized-icon">🎵</span>
            <span className="stats-unauthorized-text">音乐统计未授权，暂不展示统计数据</span>
          </div>
        )}

        {!isLoading && !error && stats && stats.base?.code === 0 && (
          <div className="stats-content">
            {/* 统计摘要 */}
            {stats.summary && (
              <div className="stats-summary">
                {stats.summary.plays !== undefined && (
                  <div className="stats-summary-item stats-summary-blue">
                    <div className="stats-summary-value">
                      {formatCount(stats.summary.plays)}
                    </div>
                    <div className="stats-summary-label">总播放次数</div>
                  </div>
                )}
                
                {stats.summary.uniqueTracks !== undefined && (
                  <div className="stats-summary-item stats-summary-green">
                    <div className="stats-summary-value">
                      {formatCount(stats.summary.uniqueTracks)}
                    </div>
                    <div className="stats-summary-label">不同歌曲</div>
                  </div>
                )}
              </div>
            )}

            {/* 详细统计 - 可展开 */}
            {isExpanded && (
              <div className="stats-details">
                <div className="stats-details-grid">
                  {/* 艺术家 */}
                  <div className="stats-details-item">
                    {renderTopList(
                      stats.topArtists,
                      '艺术家',
                      '🎤'
                    )}
                  </div>

                  {/* 歌曲 */}
                  <div className="stats-details-item">
                    {renderTopList(
                      stats.topTracks,
                      '歌曲',
                      '📈'
                    )}
                  </div>

                  {/* 专辑 */}
                  <div className="stats-details-item">
                    {renderTopList(
                      stats.topAlbums,
                      '专辑',
                      '💿'
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* 空状态 */}
            {!stats.summary && !stats.topArtists && !stats.topTracks && !stats.topAlbums && (
              <div className="stats-empty">
                <div className="stats-empty-icon">📊</div>
                <p className="stats-empty-text">暂无统计数据</p>
                <p className="stats-empty-hint">播放音乐后且开启统计授权后，将显示统计信息</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

