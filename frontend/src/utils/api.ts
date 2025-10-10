import axios from 'axios';
import type { APIResponse, StateSnapshot, StatsQueryRequest, StatsQueryResponse } from '@/types';
import { handleError } from './index';

// 创建axios实例
const api = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    // 可以在这里添加认证token等
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response.data;
  },
  (error) => {
    const errorMessage = handleError(error);
    return Promise.reject(new Error(errorMessage));
  }
);

// API接口定义
export const apiClient = {
  // 查询状态
  async queryState(sharingKey: string): Promise<StateSnapshot> {
    const response: APIResponse<StateSnapshot> = await api.get(`/v1/state/query?sharingKey=${sharingKey}`);
    if (response.code !== 0) {
      throw new Error(response.message);
    }
    return response.data;
  },

  // 查询统计信息
  async queryStats(request: StatsQueryRequest, sharingKey?: string): Promise<StatsQueryResponse> {
    const url = sharingKey ? `/v1/stats/query?sharingKey=${sharingKey}` : '/v1/stats/query';
    const response: StatsQueryResponse = await api.post(url, request);
    if (response.base.code !== 0) {
      throw new Error(response.base.message || 'Failed to query stats');
    }
    return response;
  },

  // 检查封面是否存在
  async checkCoverExists(md5: string): Promise<{ exists: boolean; url?: string }> {
    try {
      const response = await api.get(`/v1/cover/exists?md5=${md5}`);
      const responseData = response as any;
      return { exists: true, url: responseData.url };
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        return { exists: false };
      }
      throw error;
    }
  },

  // 获取封面URL
  getCoverUrl(hash: string, size?: number): string {
    // 直接返回API端点的完整URL
    const baseUrl = window.location.origin;
    const path = size ? `/api/v1/cover/${hash}?size=${size}` : `/api/v1/cover/${hash}`;
    return `${baseUrl}${path}`;
  },

  // 上传封面
  async uploadCover(base64Data: string): Promise<{ hash: string }> {
    const response: APIResponse<{ hash: string }> = await api.post('/v1/cover/upload', {
      b64: base64Data,
    });
    if (response.code !== 0) {
      throw new Error(response.message);
    }
    return response.data;
  },
};

export default apiClient;
