import type { StorageConfig } from '../types';

/**
 * 解析分享链接，提取域名和sharingKey
 * 支持格式：
 * - https://domain.com/status/{sharingKey}
 * - https://domain.com/s/{sharingKey}
 */
export function parseShareLink(url: string): StorageConfig | null {
  try {
    const urlObj = new URL(url.trim());
    const pathParts = urlObj.pathname.split('/').filter(Boolean);
    
    let sharingKey: string | null = null;
    
    // 检查 /status/{key} 格式
    if (pathParts.length >= 2 && pathParts[0] === 'status') {
      sharingKey = pathParts[1];
    }
    // 检查 /s/{key} 格式
    else if (pathParts.length >= 2 && pathParts[0] === 's') {
      sharingKey = pathParts[1];
    }
    // 如果只有一段路径，也可能是key（兼容处理）
    else if (pathParts.length === 1) {
      sharingKey = pathParts[0];
    }
    
    if (!sharingKey) {
      return null;
    }
    
    // 构建API基础URL（协议 + 域名）
    const apiBaseUrl = `${urlObj.protocol}//${urlObj.host}`;
    
    return {
      apiBaseUrl,
      sharingKey,
    };
  } catch (error) {
    console.error('Failed to parse share link:', error);
    return null;
  }
}

