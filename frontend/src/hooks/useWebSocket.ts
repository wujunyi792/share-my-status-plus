import { useEffect, useRef, useCallback } from 'react';
import { useAppStore } from '@/store/useAppStore';
import type { WSMessage } from '@/types';
import { WSMessageType } from '@/types';
import { getWebSocketURL } from '@/utils';

interface UseWebSocketOptions {
  sharingKey: string;
  onMessage?: (message: WSMessage) => void;
  onError?: (error: Event) => void;
  reconnectInterval?: number; // 初始重连间隔
  maxReconnectAttempts?: number;
}

// 全局 Map 存储每个 sharingKey 的停止重连状态
// 这样即使组件重新挂载（React Strict Mode），状态也不会丢失
const stopReconnectMap = new Map<string, boolean>();

export function useWebSocket({
  sharingKey,
  onMessage,
  onError,
  reconnectInterval = 1000,
  maxReconnectAttempts = 10,
}: UseWebSocketOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const isManualCloseRef = useRef(false);
  const isConnectingRef = useRef(false);
  const backoffDelayRef = useRef(reconnectInterval);

  const { setCurrentState, setConnectionStatus, setError } = useAppStore();

  // 检查是否应该停止重连（从全局 Map 读取）
  const shouldStopReconnect = useCallback(() => {
    return stopReconnectMap.get(sharingKey) || false;
  }, [sharingKey]);

  const setShouldStopReconnect = useCallback((value: boolean) => {
    if (sharingKey) {
      stopReconnectMap.set(sharingKey, value);
    }
  }, [sharingKey]);

  const connect = useCallback(() => {
    if (!sharingKey) return;

    // 检查是否应该停止重连（不可重试的错误）
    if (shouldStopReconnect()) {
      console.log('Connection blocked due to non-retryable error');
      return;
    }

    // 如果已有连接处于 OPEN 或 CONNECTING，直接跳过，防止重复连接
    const readyState = wsRef.current?.readyState;
    if (
      wsRef.current &&
      (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING)
    ) {
      return;
    }

    if (isConnectingRef.current) return; // 防止并发连接

    const scheduleReconnect = () => {
      if (isManualCloseRef.current) return;
      if (shouldStopReconnect()) {
        // 不可重试的错误，停止重连
        console.log('Reconnection stopped due to non-retryable error');
        return;
      }
      if (reconnectAttemptsRef.current >= maxReconnectAttempts) {
        setError({ message: '连接失败，请检查网络或稍后重试', code: 'CONNECTION_FAILED' });
        setConnectionStatus('error');
        return;
      }
      if (reconnectTimeoutRef.current) return; // 已在等待重连

      reconnectAttemptsRef.current += 1;
      const jitter = Math.random() * 200; // 抖动，避免雪崩
      const delay = Math.min(backoffDelayRef.current + jitter, 30000);
      reconnectTimeoutRef.current = window.setTimeout(() => {
        reconnectTimeoutRef.current = null;
        backoffDelayRef.current = Math.min(backoffDelayRef.current * 1.8, 30000);
        connect();
      }, delay);
    };

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
        backoffDelayRef.current = reconnectInterval; // 重置退避
        // 连接成功后，清理任何待触发的重连计时器，避免后续误触发
        if (reconnectTimeoutRef.current) {
          clearTimeout(reconnectTimeoutRef.current);
          reconnectTimeoutRef.current = null;
        }
        
        // 连接成功后立即请求当前状态快照
        const snapshotRequest = {
          type: WSMessageType.SNAPSHOT,
          timestamp: Date.now()
        };
        console.log('Requesting snapshot:', snapshotRequest);
        ws.send(JSON.stringify(snapshotRequest));
      };

      ws.onmessage = (event) => {
        try {
          const message: WSMessage = JSON.parse(event.data);
          console.log('Received WebSocket message:', message);
          
          switch (message.type) {
            case WSMessageType.STATUS_UPDATE:
              if (message.snapshot) {
                setCurrentState(message.snapshot);
              }
              break;
            case WSMessageType.SNAPSHOT:
              if (message.snapshot) {
                setCurrentState(message.snapshot);
              }
              break;
            case WSMessageType.PONG:
              // 心跳响应 - 无需特殊处理
              console.log('Received pong message');
              break;
            case WSMessageType.ERROR:
              console.error('WebSocket error from server:', message.error, 'errorCode:', message.errorCode, 'retryable:', message.retryable);
              
              // 检查是否可重试
              if (message.retryable === false) {
                // 不可重试的错误，停止重连
                setShouldStopReconnect(true);
                console.log('Non-retryable error received, will stop reconnection');
              }
              
              // 设置错误信息
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
      };

      ws.onclose = (event) => {
        console.log('WebSocket closed:', event.code, event.reason);
        isConnectingRef.current = false;
        setConnectionStatus('disconnected');

        // 置空引用，允许后续正常重连
        if (wsRef.current === ws) {
          wsRef.current = null;
        }

        // 对部分关闭码停止重连（策略违规/资源不足/服务端拒绝）
        // 1008: Policy Violation, 1013: Try Again Later（资源不足/负载），4403/4401：自定义鉴权失败
        const shouldStop = [1008, 1013, 4401, 4403].includes(event.code);
        if (shouldStop) {
          console.log('Stopping reconnection due to close code:', event.code);
          setShouldStopReconnect(true); // 设置停止重连标志
          setError({
            message: event.reason || '服务器拒绝连接或资源不足',
            code: `WS_CLOSE_${event.code}`,
          });
          setConnectionStatus('error'); // 设置为错误状态，而不是断开连接
          return; // 停止重连
        }

        // 可见性优化：页面隐藏时不重连，避免无意义重连
        if (document.visibilityState === 'hidden') {
          console.log('Page hidden, skipping reconnection');
          return;
        }

        if (!isManualCloseRef.current && !shouldStopReconnect()) {
          console.log('Scheduling reconnection...');
          scheduleReconnect();
        }
      };

      ws.onerror = (error) => {
        setConnectionStatus('error');
        setError({ message: 'WebSocket连接错误', code: 'WS_ERROR', details: error });
        onError?.(error);
      };
    } catch (error) {
      isConnectingRef.current = false;
      setConnectionStatus('error');
      setError({ message: '无法建立WebSocket连接', code: 'CONNECTION_ERROR', details: error });
      // 在构造失败时也尝试重连
      const isHMR = typeof import.meta !== 'undefined' && !!(import.meta as any).hot;
      if (!isHMR && !shouldStopReconnect()) {
        // 避免在HMR期间无意义重连，也避免在不可重试错误后重连
        const jitter = Math.random() * 200;
        window.setTimeout(connect, Math.min(backoffDelayRef.current + jitter, 5000));
      }
    }
  }, [sharingKey, onMessage, onError, reconnectInterval, maxReconnectAttempts, setCurrentState, setConnectionStatus, setError, shouldStopReconnect, setShouldStopReconnect]);

  const disconnect = useCallback(() => {
    isManualCloseRef.current = true;
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
      reconnectTimeoutRef.current = null;
    }
    if (wsRef.current) {
      try { wsRef.current.onclose = null; } catch {}
      try { wsRef.current.onerror = null; } catch {}
      try { wsRef.current.onmessage = null; } catch {}
      try { wsRef.current.onopen = null; } catch {}
      wsRef.current.close();
      wsRef.current = null;
    }
  }, []);

  const sendMessage = useCallback((message: any) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
    }
  }, []);

  // 心跳：仅在连接建立后发送
  useEffect(() => {
    const interval = setInterval(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        sendMessage({ type: WSMessageType.PING, timestamp: Date.now() });
      }
    }, 30000);
    return () => clearInterval(interval);
  }, [sendMessage]);

  // 可见性变化时，恢复/暂停重连
  useEffect(() => {
    const onVisibility = () => {
      // 如果有不可重试的错误，不尝试重连
      if (shouldStopReconnect()) {
        console.log('Page visibility changed, but reconnection is blocked due to non-retryable error');
        return;
      }
      
      const readyState = wsRef.current?.readyState;
      if (
        document.visibilityState === 'visible' &&
        (!wsRef.current || (readyState !== WebSocket.OPEN && readyState !== WebSocket.CONNECTING))
      ) {
        // 页面重新可见且没有有效连接时尝试连接
        backoffDelayRef.current = reconnectInterval;
        connect();
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    return () => document.removeEventListener('visibilitychange', onVisibility);
  }, [connect, reconnectInterval, shouldStopReconnect]);

  // 当 sharingKey 变化时，清除旧的错误状态（允许新的连接尝试）
  useEffect(() => {
    if (sharingKey) {
      setShouldStopReconnect(false);
    }
  }, [sharingKey, setShouldStopReconnect]);

  // 组件挂载时连接
  useEffect(() => {
    isManualCloseRef.current = false;
    // 注意：不在这里重置 shouldStopReconnect，避免 React Strict Mode 重新挂载时清除错误状态
    // 只在 sharingKey 变化时清除（见上面的 effect）
    backoffDelayRef.current = reconnectInterval;

    // 初次挂载时，如已有有效连接则跳过
    const readyState = wsRef.current?.readyState;
    if (!(wsRef.current && (readyState === WebSocket.OPEN || readyState === WebSocket.CONNECTING))) {
      connect();
    }

    return () => {
      // 在开发模式下（Vite HMR/React StrictMode），避免在热更新的卸载阶段关闭连接
      const isDev = typeof import.meta !== 'undefined' && (import.meta as any).env && (import.meta as any).env.DEV;
      const isHMR = typeof import.meta !== 'undefined' && !!(import.meta as any).hot;
      if (isDev && isHMR) {
        // 跳过断开，保持现有连接，下一次挂载会复用/重新建立
        return;
      }
      disconnect();
    };
  }, [connect, disconnect, reconnectInterval]);

  return {
    connectionStatus: useAppStore.getState().connectionStatus,
    connect,
    disconnect,
    sendMessage,
  };
}
