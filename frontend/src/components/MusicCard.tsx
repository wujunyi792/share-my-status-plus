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

  // 检查是否为空状态
  const isEmpty = !music.ts || music.ts === 0 || !music.title;

  // 加载封面
  useEffect(() => {
    if (music.coverHash && music.coverHash !== 'demo-cover-hash' && !isEmpty) {
      loadCover(music.coverHash);
    } else if (music.coverHash === 'demo-cover-hash') {
      // 演示模式使用占位图
      setCoverUrl(null);
      setCoverLoading(false);
    }
  }, [music.coverHash, isEmpty]);

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
      {/* 左侧：黑胶唱片 - 响应式宽度 */}
      <div className="relative flex-shrink-0 w-32 sm:w-40 md:w-48 bg-gray-50 flex items-center justify-center">
        {/* 黑胶唱片外圈 - 响应式尺寸 */}
        <div className="relative w-24 h-24 sm:w-32 sm:h-32 md:w-40 md:h-40">
          {/* 旋转的黑胶唱片 */}
          <div className={cn(
            "absolute inset-0 rounded-full bg-gradient-to-br from-gray-900 via-black to-gray-900 shadow-2xl",
            isEmpty ? "" : "animate-spin-slow"
          )}>
            {/* 唱片纹路 - 响应式间距 */}
            {[...Array(8)].map((_, i) => (
              <div
                key={i}
                className="absolute inset-0 rounded-full border border-gray-700/30"
                style={{
                  margin: `${i * 3}px`,
                }}
              />
            ))}
            
            {/* 中心封面（跟随旋转） - 响应式尺寸 */}
            <div className="absolute inset-0 flex items-center justify-center">
              <div 
                className={cn(
                  "relative w-10 h-10 sm:w-14 sm:h-14 md:w-16 md:h-16 rounded-full overflow-hidden shadow-lg transition-transform",
                  isEmpty ? "cursor-default" : "cursor-pointer hover:scale-105"
                )}
                onClick={isEmpty ? undefined : handleCoverClick}
              >
                {coverLoading ? (
                  <div className="w-full h-full bg-gray-200 animate-pulse" />
                ) : coverUrl && !isEmpty ? (
                  <img
                    src={coverUrl}
                    alt="音乐封面"
                    className="w-full h-full object-cover"
                    onError={() => setCoverUrl(null)}
                  />
                ) : (
                  <div className={cn(
                    "w-full h-full flex items-center justify-center",
                    isEmpty ? "bg-gray-300" : "bg-gray-200"
                  )}>
                    <Music className={cn("w-4 h-4 sm:w-5 sm:h-5", isEmpty ? "text-gray-500" : "text-gray-400")} />
                  </div>
                )}
              </div>
            </div>

            {/* 中心小圆点 */}
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
              <div className="w-2 h-2 rounded-full bg-gray-600 shadow-inner" />
            </div>

            {/* 禁止标志（空状态时显示） - 响应式尺寸 */}
            {isEmpty && (
              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                <div className="w-20 h-20 sm:w-28 sm:h-28 md:w-32 md:h-32 border-2 sm:border-2 md:border-4 border-red-500 rounded-full opacity-60" />
                <div className="absolute w-20 sm:w-28 md:w-32 h-0.5 sm:h-1 bg-red-500 rotate-45 opacity-60" />
              </div>
            )}
          </div>
        </div>

        {/* 播放指示器 - 响应式 */}
        <div className="absolute bottom-2 sm:bottom-3 md:bottom-4 left-1/2 transform -translate-x-1/2">
          {isEmpty ? (
            <div className="flex items-center space-x-1 sm:space-x-2 bg-gray-500/50 backdrop-blur-sm rounded-full px-2 sm:px-3 py-0.5 sm:py-1">
              <div className="w-1.5 h-1.5 sm:w-2 sm:h-2 bg-gray-400 rounded-full" />
              <span className="text-[10px] sm:text-xs text-white font-medium hidden sm:inline">Not Playing</span>
              <span className="text-[10px] text-white font-medium sm:hidden">暂停</span>
            </div>
          ) : (
            <div className="flex items-center space-x-1 sm:space-x-2 bg-black/50 backdrop-blur-sm rounded-full px-2 sm:px-3 py-0.5 sm:py-1">
              <div className="w-1.5 h-1.5 sm:w-2 sm:h-2 bg-green-500 rounded-full animate-pulse" />
              <span className="text-[10px] sm:text-xs text-white font-medium hidden sm:inline">Playing</span>
              <span className="text-[10px] text-white font-medium sm:hidden">播放中</span>
            </div>
          )}
        </div>
      </div>

      {/* 右侧：音乐信息 - 响应式内边距和字体 */}
      <div className="flex-1 flex flex-col justify-center p-3 sm:p-4 md:p-6 min-w-0">
        {/* 音乐标题 */}
        <div className="mb-2 sm:mb-3 md:mb-4">
          <div className="flex items-center space-x-1.5 sm:space-x-2 mb-1 sm:mb-2">
            <Volume2 className={cn("w-4 h-4 sm:w-5 sm:h-5 flex-shrink-0", isEmpty ? "text-gray-400" : "text-green-500")} />
            <h3 className={cn("text-sm sm:text-base md:text-lg font-semibold truncate", isEmpty ? "text-gray-500" : "text-gray-900")}>
              {isEmpty ? '未在听歌' : (music.title || '未知曲目')}
            </h3>
          </div>
          
          {/* 艺术家 */}
          {!isEmpty && (
            <p className="text-xs sm:text-sm md:text-base text-gray-600 truncate ml-5 sm:ml-7">
              {music.artist || '-'}
            </p>
          )}
          
          {/* 专辑 */}
          {!isEmpty && (
            <p className="text-xs sm:text-sm text-gray-500 truncate ml-5 sm:ml-7 mt-0.5 sm:mt-1">
              专辑：{music.album || '-'}
            </p>
          )}
        </div>

        {/* 更新时间 - 响应式布局 */}
        <div className="mt-auto">
          <div className="flex items-center justify-between text-[10px] sm:text-xs text-gray-500">
            <div className="flex items-center space-x-1 min-w-0 flex-1">
              <Clock className="w-3 h-3 flex-shrink-0" />
              <span className="truncate">更新于 {formatRelativeTime(music.ts)}</span>
            </div>
            {!isEmpty && (
              <div className="flex items-center space-x-1 text-green-500 flex-shrink-0 ml-2">
                <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
                <span className="hidden sm:inline">实时</span>
              </div>
            )}
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
