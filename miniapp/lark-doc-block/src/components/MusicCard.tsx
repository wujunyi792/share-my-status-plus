import { useState, useEffect } from 'react';
import type { MusicState } from '../types';
import { apiClient } from '../utils/api';
import { cn, formatRelativeTime } from '../utils';
import './MusicCard.css';

interface MusicCardProps {
  music: MusicState;
  className?: string;
  apiBaseUrl: string;
}

export function MusicCard({ music, className, apiBaseUrl }: MusicCardProps) {
  const [coverUrl, setCoverUrl] = useState<string | null>(null);
  const [coverLoading, setCoverLoading] = useState(false);
  const [showPreview, setShowPreview] = useState(false);

  // 检查是否为空状态
  const isEmpty = !music.ts || music.ts === 0 || !music.title;

  // 加载封面
  useEffect(() => {
    if (music.coverHash && music.coverHash !== 'demo-cover-hash' && !isEmpty) {
      loadCover(music.coverHash);
    } else if (music.coverHash === 'demo-cover-hash') {
      setCoverUrl(null);
      setCoverLoading(false);
    }
  }, [music.coverHash, isEmpty]);

  const loadCover = async (hash: string) => {
    try {
      setCoverLoading(true);
      const url = apiClient.getCoverUrl(hash, apiBaseUrl, 128);
      setCoverUrl(url);
      console.log('Loaded cover URL:', url);
    } catch (error) {
      console.error('Failed to get cover URL:', error);
      setCoverUrl(null);
    } finally {
      setCoverLoading(false);
    }
  };

  const handleCoverClick = () => {
    if (coverUrl) {
      setShowPreview(true);
    }
  };

  return (
    <div className={cn('music-card', className)}>
      {/* 左侧：黑胶唱片 */}
      <div className="music-cover-wrapper">
        <div className="music-vinyl-container">
          {/* 旋转的黑胶唱片 */}
          <div className={cn('music-vinyl', isEmpty ? '' : 'music-vinyl-spinning')}>
            {/* 唱片纹路 */}
            {[...Array(8)].map((_, i) => (
              <div
                key={i}
                className="music-vinyl-ring"
                style={{
                  margin: `${i * 3}px`,
                }}
              />
            ))}
            
            {/* 中心封面 */}
            <div className="music-cover-center">
              <div 
                className={cn(
                  'music-cover-image-wrapper',
                  isEmpty ? '' : 'music-cover-clickable'
                )}
                onClick={isEmpty ? undefined : handleCoverClick}
              >
                {coverLoading ? (
                  <div className="music-cover-loading" />
                ) : coverUrl && !isEmpty ? (
                  <img
                    src={coverUrl}
                    alt="音乐封面"
                    className="music-cover-img"
                    onError={() => setCoverUrl(null)}
                  />
                ) : (
                  <div className={cn('music-cover-placeholder', isEmpty ? 'music-cover-placeholder-empty' : '')}>
                    🎵
                  </div>
                )}
              </div>
            </div>

            {/* 中心小圆点 */}
            <div className="music-vinyl-center-dot" />

            {/* 禁止标志（空状态时显示） */}
            {isEmpty && (
              <div className="music-vinyl-disabled">
                <div className="music-vinyl-disabled-circle" />
                <div className="music-vinyl-disabled-line" />
              </div>
            )}
          </div>
        </div>

        {/* 播放指示器 */}
        <div className="music-indicator">
          {isEmpty ? (
            <div className="music-indicator-paused">
              <div className="music-indicator-dot music-indicator-gray" />
              <span className="music-indicator-text">暂停</span>
            </div>
          ) : (
            <div className="music-indicator-playing">
              <div className="music-indicator-dot music-indicator-green music-indicator-pulse" />
              <span className="music-indicator-text">播放中</span>
            </div>
          )}
        </div>
      </div>

      {/* 右侧：音乐信息 */}
      <div className="music-info">
        {/* 音乐标题 */}
        <div className="music-header">
          <div className="music-header-top">
            <svg
              className={cn('music-icon', isEmpty ? 'music-icon-gray' : 'music-icon-green')}
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
              <path d="M15.54 8.46a5 5 0 0 1 0 7.07" />
              <path d="M19.07 4.93a10 10 0 0 1 0 14.14" />
            </svg>
            <h3 className={cn('music-title', isEmpty ? 'music-title-empty' : '')}>
              {isEmpty ? '未在听歌' : (music.title || '未知曲目')}
            </h3>
          </div>
          
          {/* 艺术家 */}
          {!isEmpty && (
            <p className="music-artist">
              {music.artist || '-'}
            </p>
          )}
          
          {/* 专辑 */}
          {!isEmpty && (
            <p className="music-album">
              专辑：{music.album || '-'}
            </p>
          )}
        </div>

        {/* 更新时间 */}
        <div className="music-footer">
          <div className="music-footer-item">
            <span className="music-footer-icon">🕐</span>
            <span className="music-footer-text">更新于 {formatRelativeTime(music.ts)}</span>
          </div>
          {!isEmpty && (
            <div className="music-footer-item music-footer-active">
              <div className="music-indicator-dot music-indicator-green music-indicator-pulse" />
              <span className="music-footer-active-text">实时</span>
            </div>
          )}
        </div>
      </div>

      {/* 封面预览大图 */}
      {showPreview && coverUrl && (
        <div 
          className="music-preview-overlay"
          onClick={() => setShowPreview(false)}
        >
          <div className="music-preview-content">
            <img
              src={apiClient.getCoverUrl(music.coverHash || '', apiBaseUrl, 512)}
              alt="音乐封面预览"
              className="music-preview-img"
              onClick={(e) => e.stopPropagation()}
            />
            <button
              className="music-preview-close"
              onClick={() => setShowPreview(false)}
            >
              ✕
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

