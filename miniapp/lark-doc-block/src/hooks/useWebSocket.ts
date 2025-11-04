import { useEffect, useRef, useCallback } from 'react';
import type { WSMessage } from '../types';
import { WSMessageType } from '../types';
import { getWebSocketURL } from '../utils';
import { useAppStoreActions } from '../store/useAppStore';

interface UseWebSocketOptions {
  apiBaseUrl: string;
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
  apiBaseUrl,
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
  const connectRef = useRef<() => void>();

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
      console.log('WebSocket canReconnect: Connection blocked due to non-retryable error');
      return false;
    }

    // Debounce check - 但对于初始化连接，允许更短的间隔
    const minInterval = Math.max(500, reconnectInterval / 2);
    const timeSinceLastAttempt = now - lastReconnectAttemptRef.current;
    if (timeSinceLastAttempt < minInterval && reconnectAttemptsRef.current > 0) {
      console.log(`WebSocket canReconnect: Reconnection attempt too frequent (${timeSinceLastAttempt}ms < ${minInterval}ms), skipping`);
      return false;
    }

    // Check existing connection state
    const readyState = wsRef.current?.readyState;
    if (
      wsRef.current &&
      (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING)
    ) {
      console.log(`WebSocket canReconnect: Connection already exists (state: ${readyState}), skipping`);
      return false;
    }

    // Check if already connecting
    if (isConnectingRef.current) {
      console.log('WebSocket canReconnect: Already connecting (isConnectingRef=true), skipping');
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
      // 使用最新的 connect 函数，通过 ref 避免循环依赖
      connectRef.current?.();
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
            console.log('WebSocket: Received snapshot, updating state:', message.snapshot);
            setCurrentState(message.snapshot);
            console.log('WebSocket: State updated via setCurrentState');
          } else {
            console.warn('WebSocket: Received SNAPSHOT/STATUS_UPDATE but no snapshot data:', message);
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
    // 如果是因为连接失败而关闭，设置为 disconnected 而不是保持 connecting
    if (event.code !== 1000 && event.code !== 1001) {
      setConnectionStatus('disconnected');
      console.log('WebSocket: Connection closed with error, status set to disconnected');
    } else {
    setConnectionStatus('disconnected');
    }

    // Clear reference
    if (wsRef.current) {
      wsRef.current = null;
    }

    // Stop reconnection for certain close codes
    const shouldStop = [1008, 1013, 4401, 4403].includes(event.code);
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
    console.error('WebSocket error event:', error);
    isConnectingRef.current = false;
    // 注意：WebSocket 的错误通常会在 onclose 中处理
    // 这里只处理真正的错误情况
    setConnectionStatus('error');
    setError({ message: 'WebSocket连接错误', code: 'WS_ERROR', details: error });
    onError?.(error);
  }, [setConnectionStatus, setError, onError]);

  // Connect to WebSocket
  const connect = useCallback(() => {
    if (!sharingKey || !apiBaseUrl) {
      console.log('WebSocket connect: Missing sharingKey or apiBaseUrl');
      return;
    }

    const now = Date.now();
    if (!canReconnect(now)) {
      console.log('WebSocket connect: Reconnection blocked by canReconnect check');
      return;
    }

    lastReconnectAttemptRef.current = now;

    try {
      isConnectingRef.current = true;
      setConnectionStatus('connecting');
      setError(null);

      const wsUrl = getWebSocketURL(apiBaseUrl, sharingKey);
      console.log('Connecting to WebSocket:', wsUrl);
      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onopen = () => {
        console.log('WebSocket connected successfully');
        isConnectingRef.current = false;
        setConnectionStatus('connected');
        console.log('WebSocket: Connection status set to connected');
        reconnectAttemptsRef.current = 0;
        backoffDelayRef.current = reconnectInterval;
        clearReconnectTimer();

        // Request snapshot immediately
        const snapshotRequest = {
          type: WSMessageType.SNAPSHOT,
          timestamp: Date.now()
        };
        console.log('WebSocket: Requesting snapshot:', snapshotRequest);
        try {
        ws.send(JSON.stringify(snapshotRequest));
        } catch (err) {
          console.error('WebSocket: Failed to send snapshot request:', err);
        }
      };

      ws.onmessage = handleMessage;
      ws.onclose = handleClose;
      ws.onerror = handleError;
    } catch (error) {
      isConnectingRef.current = false;
      setConnectionStatus('error');
      setError({ message: '无法建立WebSocket连接', code: 'CONNECTION_ERROR', details: error });

      // Schedule retry
      if (!shouldStopReconnect(sharingKey) && !isManualCloseRef.current) {
        console.log('Connection construction failed, scheduling retry...');
        scheduleReconnect();
      }
    }
  }, [
    apiBaseUrl,
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

  // 更新 connect ref（立即更新，不等待 useEffect）
  connectRef.current = connect;

  // Disconnect from WebSocket
  const disconnect = useCallback((isManual = true) => {
    if (isManual) {
      isManualCloseRef.current = true;
    }
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

  // Handle page unload - clean up WebSocket connection
  useEffect(() => {
    const handleBeforeUnload = () => {
      console.log('Page unloading - closing WebSocket');
      disconnect(true); // Manual close
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [disconnect]);

  // 使用 ref 存储配置，用于检测配置变化
  const configRef = useRef<{ apiBaseUrl: string; sharingKey: string } | null>(null);

  // Initialize connection on mount and when apiBaseUrl or sharingKey changes
  useEffect(() => {
    // 如果配置为空，断开现有连接
    if (!apiBaseUrl || !sharingKey) {
      console.log('WebSocket: Missing apiBaseUrl or sharingKey, disconnecting existing connection');
      configRef.current = null;
      
      // 断开现有连接
      if (wsRef.current) {
        console.log('WebSocket: Disconnecting because config is empty');
        const oldWs = wsRef.current;
        oldWs.onclose = null;
        oldWs.onerror = null;
        oldWs.onmessage = null;
        oldWs.close();
        wsRef.current = null;
      }
      
      clearReconnectTimer();
      isConnectingRef.current = false;
      isManualCloseRef.current = false;
      setConnectionStatus('disconnected');
      
      return;
    }

    // 检查配置是否真的变化了
    const currentConfig = { apiBaseUrl, sharingKey };
    const configChanged = !configRef.current || 
      configRef.current.apiBaseUrl !== apiBaseUrl || 
      configRef.current.sharingKey !== sharingKey;
    
    if (!configChanged) {
      // 配置没变化，但可能因为其他依赖变化导致重复执行，需要检查连接状态
      const readyState = wsRef.current?.readyState;
      if (wsRef.current && (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING)) {
        console.log('WebSocket: Config unchanged and connection active, skipping');
        return;
      }
    } else {
      console.log('WebSocket: Config changed from', configRef.current, 'to', currentConfig);
      configRef.current = currentConfig;
      
      // 配置变化时，强制断开旧连接
      if (wsRef.current) {
        const currentReadyState = wsRef.current.readyState;
        console.log('WebSocket: Config changed, closing existing connection (state:', currentReadyState, ')');
        const oldWs = wsRef.current;
        oldWs.onclose = null;
        oldWs.onerror = null;
        oldWs.onmessage = null;
        oldWs.onopen = null;
        if (currentReadyState === WebSocket.OPEN || currentReadyState === WebSocket.CONNECTING) {
          oldWs.close();
        }
        wsRef.current = null;
      }
      isConnectingRef.current = false;
      clearReconnectTimer();
    }
    
    // Always reset manual close flag and reconnect state
    isManualCloseRef.current = false;
    backoffDelayRef.current = reconnectInterval;
    reconnectAttemptsRef.current = 0;
    setShouldStopReconnect(sharingKey, false);

    clearReconnectTimer();

    // 使用 ref 中的 connect 函数，避免依赖变化导致重复执行
    console.log('WebSocket: Initializing connection with', { apiBaseUrl, sharingKey });
    connectRef.current?.();

    return () => {
      clearReconnectTimer();
    };
    // 只依赖 apiBaseUrl 和 sharingKey，不依赖 connect 避免重复执行
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [apiBaseUrl, sharingKey]);

  return {
    connect,
    disconnect,
    sendMessage,
  };
}

