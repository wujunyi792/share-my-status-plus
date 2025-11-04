import { useState, useEffect, useRef } from 'react';
import type { AppState, StateSnapshot, WSConnectionStatus, AppError, StatsQueryResponse } from '../types';

const initialState: AppState = {
  currentState: null,
  connectionStatus: 'disconnected',
  error: null,
  stats: null,
  loading: false,
};

// 全局状态存储
let globalState: AppState = { ...initialState };
const listeners = new Set<() => void>();

// 通知所有监听器状态已更新
function notifyListeners() {
  listeners.forEach(listener => listener());
}

// 更新全局状态
function updateGlobalState(updater: (prev: AppState) => AppState) {
  const prevState = { ...globalState };
  globalState = updater(globalState);
  console.log('Global state updated:', {
    prev: prevState,
    next: globalState,
    listeners: listeners.size
  });
  notifyListeners();
}

// Actions - 这些函数是稳定的，不会变化
const actions = {
  setCurrentState: (currentState: StateSnapshot | null) => {
    updateGlobalState((prev) => ({ ...prev, currentState, error: null }));
  },
  setConnectionStatus: (connectionStatus: WSConnectionStatus) => {
    updateGlobalState((prev) => ({ ...prev, connectionStatus }));
  },
  setError: (error: AppError | null) => {
    updateGlobalState((prev) => ({ ...prev, error, loading: false }));
  },
  setStats: (stats: StatsQueryResponse | null) => {
    updateGlobalState((prev) => ({ ...prev, stats }));
  },
  setLoading: (loading: boolean) => {
    updateGlobalState((prev) => ({ ...prev, loading }));
  },
  reset: () => {
    updateGlobalState(() => ({ ...initialState }));
  },
};

// 只返回 actions，不会导致重新渲染
export function useAppStoreActions() {
  return actions;
}

// 返回完整状态和 actions（会触发重新渲染）
export function useAppStore() {
  // 使用本地 state 来触发重新渲染
  const [, forceUpdate] = useState({});

  // 注册监听器
  useEffect(() => {
    const listener = () => {
      forceUpdate({});
    };
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  }, []);

  return {
    // State - 从全局状态读取
    ...globalState,
    // Actions
    ...actions,
  };
}

