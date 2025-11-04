import axios from 'axios';
import type { APIResponse, StateSnapshot, StatsQueryRequest, StatsQueryResponse } from '../types';
import { handleError } from './index';

// 创建axios实例
const api = axios.create({
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
  async queryState(sharingKey: string, apiBaseUrl: string): Promise<StateSnapshot> {
    const baseUrl = apiBaseUrl.replace(/\/$/, ''); // 移除尾部斜杠
    const response: APIResponse<StateSnapshot> = await api.get(
      `${baseUrl}/api/v1/state/query?sharingKey=${encodeURIComponent(sharingKey)}`
    );
    if (response.code !== 0) {
      throw new Error(response.message);
    }
    return response.data;
  },

  // 查询统计信息
  async queryStats(request: StatsQueryRequest, sharingKey: string, apiBaseUrl: string): Promise<StatsQueryResponse> {
    const baseUrl = apiBaseUrl.replace(/\/$/, ''); // 移除尾部斜杠
    const url = `${baseUrl}/api/v1/stats/query?sharingKey=${encodeURIComponent(sharingKey)}`;
    const response: StatsQueryResponse = await api.post(url, request);
    // 对于未授权的音乐统计（403），不抛出错误，直接返回响应以便前端显示空状态
    if (response.base.code === 403) {
      return response;
    }
    if (response.base.code !== 0) {
      throw new Error(response.base.message || 'Failed to query stats');
    }
    return response;
  },

  // 获取封面URL
  getCoverUrl(hash: string, apiBaseUrl: string, size?: number): string {
    const baseUrl = apiBaseUrl.replace(/\/$/, ''); // 移除尾部斜杠
    const path = size ? `/api/v1/cover/${hash}?size=${size}` : `/api/v1/cover/${hash}`;
    return `${baseUrl}${path}`;
  },
};

export default apiClient;

