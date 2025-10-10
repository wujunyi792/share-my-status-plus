import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { shallow } from 'zustand/shallow';
import type { AppState, StateSnapshot, WSConnectionStatus, AppError, StatsQueryResponse } from '@/types';

interface AppStore extends AppState {
  // Actions
  setCurrentState: (state: StateSnapshot | null) => void;
  setConnectionStatus: (status: WSConnectionStatus) => void;
  setError: (error: AppError | null) => void;
  setStats: (stats: StatsQueryResponse | null) => void;
  setLoading: (loading: boolean) => void;
  reset: () => void;
}

const initialState: AppState = {
  currentState: null,
  connectionStatus: 'disconnected',
  error: null,
  stats: null,
  loading: false,
};

export const useAppStore = create<AppStore>()(
  devtools(
    (set) => ({
      ...initialState,

      setCurrentState: (state) => {
        set({ currentState: state, error: null });
      },

      setConnectionStatus: (status) => {
        set({ connectionStatus: status });
      },

      setError: (error) => {
        set({ error, loading: false });
      },

      setStats: (stats) => {
        set({ stats });
      },

      setLoading: (loading) => {
        set({ loading });
      },

      reset: () => {
        set(initialState);
      },
    }),
    {
      name: 'share-my-status-store',
    }
  )
);

// Selectors - 精确订阅，避免不必要的重新渲染
export const useCurrentState = () => useAppStore((state) => state.currentState);
export const useConnectionStatus = () => useAppStore((state) => state.connectionStatus);
export const useError = () => useAppStore((state) => state.error);
export const useStats = () => useAppStore((state) => state.stats);
export const useLoading = () => useAppStore((state) => state.loading);

// Actions selectors - 不会触发重新渲染，因为actions不会变化
export const useAppStoreActions = () => useAppStore(
  (state) => ({
    setCurrentState: state.setCurrentState,
    setConnectionStatus: state.setConnectionStatus,
    setError: state.setError,
    setStats: state.setStats,
    setLoading: state.setLoading,
    reset: state.reset,
  }),
  shallow
);

// 组合selectors - 当需要多个状态时使用
export const useStatusPageState = () => useAppStore(
  (state) => ({
    currentState: state.currentState,
    connectionStatus: state.connectionStatus,
    error: state.error,
    loading: state.loading,
  }),
  shallow
);
