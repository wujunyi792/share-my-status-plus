import { useEffect, useRef, useCallback } from 'react';
import { useAppStoreActions } from '@/store/useAppStore';
import type { WSMessage } from '@/types';
import { WSMessageType } from '@/types';
import { getWebSocketURL } from '@/utils';

interface UseWebSocketOptions {
  sharingKey: string;
  onMessage?: (message: WSMessage) => void;
  onError?: (error: Event) => void;
  reconnectInterval?: number;
  maxReconnectAttempts?: number;
}

// Global state management for non-retryable errors
const stopReconnectMap = new Map<string, boolean>();

// Helper: Check if should stop reconnection
const shouldStopReconnect = (sharingKey: string): boolean => {
  return stopReconnectMap.get(sharingKey) || false;
};

const setShouldStopReconnect = (sharingKey: string, value: boolean): void => {
  if (sharingKey) {
    stopReconnectMap.set(sharingKey, value);
  }
};

export function useWebSocket({
  sharingKey,
  onMessage,
  onError,
  reconnectInterval = 1000,
  maxReconnectAttempts = 10,
}: UseWebSocketOptions) {
  // Refs for WebSocket management
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const isManualCloseRef = useRef(false);
  const isConnectingRef = useRef(false);
  const backoffDelayRef = useRef(reconnectInterval);
  const lastReconnectAttemptRef = useRef<number>(0);

  // Get store actions (won't cause re-render)
  const { setCurrentState, setConnectionStatus, setError } = useAppStoreActions();

  // Clear reconnection timer
  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
      reconnectTimeoutRef.current = null;
    }
  }, []);

  // Check if can attempt reconnection
  const canReconnect = useCallback((now: number): boolean => {
    // Check for non-retryable errors
    if (shouldStopReconnect(sharingKey)) {
      console.log('Connection blocked due to non-retryable error');
      return false;
    }

    // Debounce check
    const minInterval = Math.max(500, reconnectInterval / 2);
    if (now - lastReconnectAttemptRef.current < minInterval) {
      console.log('Reconnection attempt too frequent, skipping');
      return false;
    }

    // Check existing connection state
    const readyState = wsRef.current?.readyState;
    if (
      wsRef.current &&
      (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING)
    ) {
      console.log('Connection already exists or connecting, skipping');
      return false;
    }

    // Check if already connecting
    if (isConnectingRef.current) {
      console.log('Already connecting, skipping');
      return false;
    }

    return true;
  }, [sharingKey, reconnectInterval]);

  // Schedule reconnection with exponential backoff
  const scheduleReconnect = useCallback(() => {
    if (isManualCloseRef.current || shouldStopReconnect(sharingKey)) {
      console.log('Reconnection stopped');
      return;
    }

    if (reconnectAttemptsRef.current >= maxReconnectAttempts) {
      setError({ message: '连接失败，请检查网络或稍后重试', code: 'CONNECTION_FAILED' });
      setConnectionStatus('error');
      return;
    }

    if (reconnectTimeoutRef.current) {
      console.log('Reconnection already scheduled, skipping');
      return;
    }

    reconnectAttemptsRef.current += 1;
    const jitter = Math.random() * 200;
    const delay = Math.min(backoffDelayRef.current + jitter, 30000);
    console.log(`Scheduling reconnection attempt ${reconnectAttemptsRef.current} in ${delay}ms`);

    reconnectTimeoutRef.current = window.setTimeout(() => {
      reconnectTimeoutRef.current = null;
      backoffDelayRef.current = Math.min(backoffDelayRef.current * 1.8, 30000);
      connect();
    }, delay);
  }, [sharingKey, maxReconnectAttempts, setError, setConnectionStatus]);

  // Handle WebSocket messages
  const handleMessage = useCallback((event: MessageEvent) => {
    try {
      const message: WSMessage = JSON.parse(event.data);
      console.log('Received WebSocket message:', message);

      switch (message.type) {
        case WSMessageType.STATUS_UPDATE:
        case WSMessageType.SNAPSHOT:
          if (message.snapshot) {
            setCurrentState(message.snapshot);
          }
          break;

        case WSMessageType.PONG:
          console.log('Received pong message');
          break;

        case WSMessageType.ERROR:
          console.error('WebSocket error from server:', message.error, 'errorCode:', message.errorCode, 'retryable:', message.retryable);

          if (message.retryable === false) {
            setShouldStopReconnect(sharingKey, true);
            console.log('Non-retryable error received, will stop reconnection');
          }

          setError({
            message: message.error || '服务器错误',
            code: message.errorCode || 'SERVER_ERROR',
            details: { retryable: message.retryable }
          });
          setConnectionStatus('error');
          break;

        default:
          console.log('Unknown message type:', message.type);
      }

      onMessage?.(message);
    } catch (error) {
      console.error('Failed to parse WebSocket message:', error, 'Raw data:', event.data);
    }
  }, [sharingKey, setCurrentState, setConnectionStatus, setError, onMessage]);

  // Handle WebSocket close
  const handleClose = useCallback((event: CloseEvent) => {
    console.log('WebSocket closed:', event.code, event.reason);
    isConnectingRef.current = false;
    setConnectionStatus('disconnected');

    // Clear reference
    if (wsRef.current) {
      wsRef.current = null;
    }

    // Stop reconnection for certain close codes
    const shouldStop = [1006, 1008, 1013, 4401, 4403].includes(event.code);
    if (shouldStop) {
      console.log('Stopping reconnection due to close code:', event.code);
      setShouldStopReconnect(sharingKey, true);
      setError({
        message: event.reason || '服务器拒绝连接或资源不足',
        code: `WS_CLOSE_${event.code}`,
      });
      setConnectionStatus('error');
      return;
    }

    // Skip reconnection if page is hidden
    if (document.visibilityState === 'hidden') {
      console.log('Page hidden, skipping reconnection');
      return;
    }

    // Schedule reconnection if not manual close
    if (!isManualCloseRef.current && !shouldStopReconnect(sharingKey)) {
      console.log('Connection lost, scheduling reconnection...');
      scheduleReconnect();
    }
  }, [sharingKey, setConnectionStatus, setError, scheduleReconnect]);

  // Handle WebSocket error
  const handleError = useCallback((error: Event) => {
    console.error('WebSocket error:', error);
    setConnectionStatus('error');
    setError({ message: 'WebSocket连接错误', code: 'WS_ERROR', details: error });
    onError?.(error);
  }, [setConnectionStatus, setError, onError]);

  // Connect to WebSocket
  const connect = useCallback(() => {
    if (!sharingKey) return;

    const now = Date.now();
    if (!canReconnect(now)) return;

    lastReconnectAttemptRef.current = now;

    try {
      isConnectingRef.current = true;
      setConnectionStatus('connecting');
      setError(null);

      const wsUrl = getWebSocketURL(sharingKey);
      console.log('Connecting to WebSocket:', wsUrl);
      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onopen = () => {
        console.log('WebSocket connected successfully');
        isConnectingRef.current = false;
        setConnectionStatus('connected');
        reconnectAttemptsRef.current = 0;
        backoffDelayRef.current = reconnectInterval;
        clearReconnectTimer();

        // Request snapshot immediately
        const snapshotRequest = {
          type: WSMessageType.SNAPSHOT,
          timestamp: Date.now()
        };
        console.log('Requesting snapshot:', snapshotRequest);
        ws.send(JSON.stringify(snapshotRequest));
      };

      ws.onmessage = handleMessage;
      ws.onclose = handleClose;
      ws.onerror = handleError;
    } catch (error) {
      isConnectingRef.current = false;
      setConnectionStatus('error');
      setError({ message: '无法建立WebSocket连接', code: 'CONNECTION_ERROR', details: error });

      // Schedule retry if not HMR and not non-retryable error
      const isHMR = typeof import.meta !== 'undefined' && !!(import.meta as any).hot;
      if (!isHMR && !shouldStopReconnect(sharingKey) && !isManualCloseRef.current) {
        console.log('Connection construction failed, scheduling retry...');
        scheduleReconnect();
      }
    }
  }, [
    sharingKey,
    reconnectInterval,
    canReconnect,
    clearReconnectTimer,
    scheduleReconnect,
    handleMessage,
    handleClose,
    handleError,
    setConnectionStatus,
    setError
  ]);

  // Disconnect from WebSocket
  const disconnect = useCallback(() => {
    isManualCloseRef.current = true;
    clearReconnectTimer();

    if (wsRef.current) {
      try { wsRef.current.onclose = null; } catch { }
      try { wsRef.current.onerror = null; } catch { }
      try { wsRef.current.onmessage = null; } catch { }
      try { wsRef.current.onopen = null; } catch { }
      wsRef.current.close();
      wsRef.current = null;
    }
  }, [clearReconnectTimer]);

  // Send message to WebSocket
  const sendMessage = useCallback((message: any) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
    }
  }, []);

  // Heartbeat mechanism
  useEffect(() => {
    const interval = setInterval(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        sendMessage({ type: WSMessageType.PING, timestamp: Date.now() });
      }
    }, 30000);
    return () => clearInterval(interval);
  }, [sendMessage]);

  // Handle visibility changes
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (shouldStopReconnect(sharingKey)) {
        console.log('Page visibility changed, but reconnection is blocked');
        return;
      }

      const readyState = wsRef.current?.readyState;
      if (
        document.visibilityState === 'visible' &&
        (!wsRef.current || (readyState !== WebSocket.OPEN && readyState !== WebSocket.CONNECTING)) &&
        !isManualCloseRef.current
      ) {
        console.log('Page became visible, attempting to reconnect...');
        backoffDelayRef.current = reconnectInterval;
        reconnectAttemptsRef.current = 0;
        connect();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [sharingKey, reconnectInterval, connect]);

  // Reset error state when sharingKey changes
  useEffect(() => {
    if (sharingKey) {
      setShouldStopReconnect(sharingKey, false);
    }
  }, [sharingKey]);

  // Initialize connection on mount
  useEffect(() => {
    isManualCloseRef.current = false;
    backoffDelayRef.current = reconnectInterval;

    const readyState = wsRef.current?.readyState;
    if (!(wsRef.current && (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING))) {
      connect();
    }

    return () => {
      // Skip disconnect in development/HMR mode
      const isDev = typeof import.meta !== 'undefined' && (import.meta as any).env && (import.meta as any).env.DEV;
      const isHMR = typeof import.meta !== 'undefined' && !!(import.meta as any).hot;
      if (isDev && isHMR) {
        return;
      }
      disconnect();
    };
  }, [connect, disconnect, reconnectInterval]);

  return {
    connect,
    disconnect,
    sendMessage,
  };
}
