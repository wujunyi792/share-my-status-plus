import { useState, useEffect } from 'react';
import { Music, Volume2, Clock } from 'lucide-react';
import type { MusicState } from '@/types';
import { apiClient } from '@/utils/api';
import { cn, formatRelativeTime } from '@/utils';

interface MusicCardProps {
  music: MusicState;
  className?: string;
}

export function MusicCard({ music, className }: MusicCardProps) {
  const [coverUrl, setCoverUrl] = useState<string | null>(null);
  const [coverLoading, setCoverLoading] = useState(false);
  const [showPreview, setShowPreview] = useState(false);

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

  const handleCoverClick = () => {
    if (coverUrl) {
      setShowPreview(true);
    }
  };

  return (
    <div className={cn(
      "bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden transition-all duration-200 hover:shadow-md h-full flex",
      className
    )}>
      {/* 左侧：黑胶唱片 */}
      <div className="relative flex-shrink-0 w-48 bg-gray-50 flex items-center justify-center">
        {/* 黑胶唱片外圈 */}
        <div className="relative w-40 h-40">
          {/* 旋转的黑胶唱片 */}
          <div className="absolute inset-0 rounded-full bg-gradient-to-br from-gray-900 via-black to-gray-900 shadow-2xl animate-spin-slow">
            {/* 唱片纹路 */}
            {[...Array(8)].map((_, i) => (
              <div
                key={i}
                className="absolute inset-0 rounded-full border border-gray-700/30"
                style={{
                  margin: `${i * 5}px`,
                }}
              />
            ))}
            
            {/* 中心封面（跟随旋转） */}
            <div className="absolute inset-0 flex items-center justify-center">
              <div 
                className="relative w-16 h-16 rounded-full overflow-hidden shadow-lg cursor-pointer hover:scale-105 transition-transform"
                onClick={handleCoverClick}
              >
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
                  <div className="w-full h-full flex items-center justify-center bg-gray-200">
                    <Music className="w-5 h-5 text-gray-400" />
                  </div>
                )}
              </div>
            </div>

            {/* 中心小圆点 */}
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
              <div className="w-2 h-2 rounded-full bg-gray-600 shadow-inner" />
            </div>
          </div>
        </div>

        {/* 播放指示器 */}
        <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2">
          <div className="flex items-center space-x-2 bg-black/50 backdrop-blur-sm rounded-full px-3 py-1">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
            <span className="text-xs text-white font-medium">Playing</span>
          </div>
        </div>
      </div>

      {/* 右侧：音乐信息 */}
      <div className="flex-1 flex flex-col justify-center p-6 min-w-0">
        {/* 音乐标题 */}
        <div className="mb-4">
          <div className="flex items-center space-x-2 mb-2">
            <Volume2 className="w-5 h-5 text-green-500 flex-shrink-0" />
            <h3 className="text-lg font-semibold text-gray-900 truncate">
              {music.title || '未知曲目'}
            </h3>
          </div>
          
          {/* 艺术家 */}
          {music.artist && (
            <p className="text-base text-gray-600 truncate ml-7">
              {music.artist}
            </p>
          )}
          
          {/* 专辑 */}
          {music.album && (
            <p className="text-sm text-gray-500 truncate ml-7 mt-1">
              专辑：{music.album}
            </p>
          )}
        </div>

        {/* 更新时间 */}
        <div className="mt-auto pt-4 border-t border-gray-100 ml-7">
          <div className="flex items-center space-x-1 text-gray-500">
            <Clock className="w-3 h-3" />
            <span className="text-xs">{formatRelativeTime(music.ts)}</span>
          </div>
        </div>
      </div>

      {/* 封面预览大图 */}
      {showPreview && coverUrl && (
        <div 
          className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-4 md:p-8"
          onClick={() => setShowPreview(false)}
        >
          <div className="relative w-full h-full flex items-center justify-center">
            <img
              src={apiClient.getCoverUrl(music.coverHash || '', 512)}
              alt="音乐封面预览"
              className="max-w-full max-h-full object-contain rounded-lg shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            />
            <button
              className="absolute top-2 right-2 md:top-4 md:right-4 w-10 h-10 bg-white/10 hover:bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white transition-colors"
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
