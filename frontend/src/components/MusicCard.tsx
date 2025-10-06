import React, { useState, useEffect } from 'react';
import { Music, Play, Volume2 } from 'lucide-react';
import type { MusicState } from '@/types';
import { apiClient } from '@/utils/api';
import { cn } from '@/utils';

interface MusicCardProps {
  music: MusicState;
  className?: string;
}

export function MusicCard({ music, className }: MusicCardProps) {
  const [coverUrl, setCoverUrl] = useState<string | null>(null);
  const [coverLoading, setCoverLoading] = useState(false);

  // 加载封面
  useEffect(() => {
    if (music.coverHash && music.coverHash !== 'demo-cover-hash') {
      loadCover(music.coverHash);
    } else if (music.coverHash === 'demo-cover-hash') {
      // 演示模式使用占位图
      setCoverUrl(null);
      setCoverLoading(false);
    }
  }, [music.coverHash]);

  const loadCover = (hash: string) => {
    try {
      setCoverLoading(true);
      const url = apiClient.getCoverUrl(hash, 128);
      setCoverUrl(url);
      console.log('Loaded cover URL:', url);
    } catch (error) {
      console.error('Failed to get cover URL:', error);
      setCoverUrl(null);
    } finally {
      setCoverLoading(false);
    }
  };

  const getDisplayText = () => {
    if (music.artist && music.title) {
      return `${music.artist} - ${music.title}`;
    } else if (music.title) {
      return music.title;
    } else if (music.artist) {
      return music.artist;
    }
    return '未知音乐';
  };

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 p-4 transition-all duration-200 hover:shadow-md",
      className
    )}>
      <div className="flex items-center space-x-4">
        {/* 封面图片 */}
        <div className="relative flex-shrink-0">
          <div className="w-12 h-12 rounded-lg bg-gray-100 flex items-center justify-center overflow-hidden">
            {coverLoading ? (
              <div className="w-full h-full bg-gray-200 animate-pulse" />
            ) : coverUrl ? (
              <img
                src={coverUrl}
                alt="音乐封面"
                className="w-full h-full object-cover"
                onError={() => setCoverUrl(null)}
              />
            ) : (
              <Music className="w-6 h-6 text-gray-400" />
            )}
          </div>
          
          {/* 播放状态指示器 */}
          <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
            <Play className="w-2.5 h-2.5 text-white fill-white" />
          </div>
        </div>

        {/* 音乐信息 */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center space-x-2 mb-1">
            <Volume2 className="w-4 h-4 text-green-500" />
            <span className="text-sm font-medium text-gray-900 truncate">
              {getDisplayText()}
            </span>
          </div>
          
          {music.album && (
            <p className="text-sm text-gray-500 truncate">
              专辑：{music.album}
            </p>
          )}
        </div>
      </div>

      {/* 波浪动画效果 */}
      <div className="flex items-center justify-center space-x-1 mt-3">
        {[...Array(5)].map((_, i) => (
          <div
            key={i}
            className="w-1 bg-green-400 rounded-full animate-pulse"
            style={{
              height: `${Math.random() * 12 + 4}px`,
              animationDelay: `${i * 0.1}s`,
              animationDuration: `${Math.random() * 0.5 + 0.8}s`,
            }}
          />
        ))}
      </div>
    </div>
  );
}
