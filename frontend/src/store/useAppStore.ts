import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import type { AppState, StateSnapshot, WSConnectionStatus, AppError, MusicStats } from '@/types';

interface AppStore extends AppState {
  // Actions
  setCurrentState: (state: StateSnapshot | null) => void;
  setConnectionStatus: (status: WSConnectionStatus) => void;
  setError: (error: AppError | null) => void;
  setStats: (stats: MusicStats | null) => void;
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
    (set, get) => ({
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

// Selectors
export const useCurrentState = () => useAppStore((state) => state.currentState);
export const useConnectionStatus = () => useAppStore((state) => state.connectionStatus);
export const useError = () => useAppStore((state) => state.error);
export const useStats = () => useAppStore((state) => state.stats);
export const useLoading = () => useAppStore((state) => state.loading);
