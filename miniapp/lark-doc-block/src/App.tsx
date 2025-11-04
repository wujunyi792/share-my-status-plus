import { useState, useEffect, useCallback, useRef } from 'react';
import { BlockitClient } from '@lark-opdev/block-docs-addon-api';
import { useAppStore } from './store/useAppStore';
import { useWebSocket } from './hooks/useWebSocket';
import { loadConfig, saveConfig, clearConfig } from './utils/storage';
import { parseShareLink } from './utils/linkParser';
import { MusicCard } from './components/MusicCard';
import { SystemCard } from './components/SystemCard';
import { ActivityCard } from './components/ActivityCard';
import { StatsCard } from './components/StatsCard';
import { ConnectionStatus } from './components/ConnectionStatus';
import { ErrorAlert } from './components/ErrorAlert';
import { LoadingSpinner } from './components/LoadingSpinner';
import type { StorageConfig, DisplayOptions } from './types';
import './index.css';

// 默认显示选项：全部显示
const DEFAULT_DISPLAY_OPTIONS: DisplayOptions = {
  music: true,
  system: true,
  activity: true,
  stats: true,
};

export default function App() {
  const [config, setConfig] = useState<StorageConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [inputUrl, setInputUrl] = useState('');
  const [inputError, setInputError] = useState<string | null>(null);
  const [displayOptions, setDisplayOptions] = useState<DisplayOptions>(DEFAULT_DISPLAY_OPTIONS);
  const [docMiniApp, setDocMiniApp] = useState<any>(null);
  const [hasEditPermission, setHasEditPermission] = useState<boolean>(false);
  const containerRef = useRef<HTMLDivElement>(null);
  
  const { currentState, connectionStatus, error, setError } = useAppStore();

  // 动态调整组件高度的函数
  const updateHeight = useCallback((docMiniApp: any) => {
    if (!docMiniApp) return;
    
    // 使用 Bridge.updateHeight API
    if (docMiniApp.Bridge && typeof docMiniApp.Bridge.updateHeight === 'function') {
      // 如果连接错误，固定高度为250px
      if (error || connectionStatus === 'error') {
        docMiniApp.Bridge.updateHeight();
        return;
      }
      
      // 获取内容实际高度，加上一些边距
      if (containerRef.current) {
        const height = containerRef.current.scrollHeight + 16;
        // 限制最大高度为400px
        docMiniApp.Bridge.updateHeight(height);
      } else {
        // 如果没有容器引用，使用自动高度（不传参数）
        docMiniApp.Bridge.updateHeight();
      }
    }
  }, [error, connectionStatus]);

  // 初始化 BlockitClient
  useEffect(() => {
    try {
      const app = new BlockitClient().initAPI();
      setDocMiniApp(app);
    } catch (err) {
      console.error('Failed to initialize BlockitClient:', err);
    }
  }, []);

  // 获取文档权限
  useEffect(() => {
    const checkPermission = async () => {
      if (!docMiniApp) return;
      
      try {
        // 检查是否有 Service.Permission API
        if (docMiniApp.Service && docMiniApp.Service.Permission && typeof docMiniApp.Service.Permission.getDocumentPermission === 'function') {
          // 先获取文档引用
          if (typeof docMiniApp.getActiveDocumentRef === 'function') {
            const ref = await docMiniApp.getActiveDocumentRef();
            console.log('Document ref:', ref);
            
            // 使用文档引用获取权限
            const permission = await docMiniApp.Service.Permission.getDocumentPermission(ref);
            console.log('Document permission:', permission);
            
            // 检查是否有编辑权限
            const editable = permission?.editable === true || permission?.editable === 'true';
            setHasEditPermission(editable);
          } else {
            console.warn('getActiveDocumentRef not available, defaulting to editable');
            setHasEditPermission(true);
          }
        } else {
          // 如果没有权限 API，默认允许编辑（向后兼容）
          console.warn('Service.Permission.getDocumentPermission not available, defaulting to editable');
          setHasEditPermission(true);
        }
      } catch (err) {
        console.error('Failed to get document permission:', err);
        // 出错时默认不允许编辑，更安全
        setHasEditPermission(false);
      }
    };
    
    checkPermission();
  }, [docMiniApp]);

  // 加载配置
  useEffect(() => {
    const load = async () => {
      if (!docMiniApp) return;
      try {
        const savedConfig = await loadConfig(docMiniApp);
        if (savedConfig) {
          setConfig(savedConfig);
          // 加载显示选项，如果不存在则使用默认值
          setDisplayOptions(savedConfig.displayOptions || DEFAULT_DISPLAY_OPTIONS);
        }
      } catch (err) {
        console.error('Failed to load config:', err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [docMiniApp]);

  // 当内容变化时动态调整高度
  useEffect(() => {
    if (!docMiniApp || loading) return;
    
    // 使用 setTimeout 确保 DOM 已更新
    const timer = setTimeout(() => {
      updateHeight(docMiniApp);
    }, 100);

    return () => clearTimeout(timer);
  }, [docMiniApp, config, loading, currentState, error, connectionStatus, updateHeight]);

  // 使用 ResizeObserver 监听内容高度变化
  useEffect(() => {
    if (!containerRef.current || !docMiniApp) return;

    const resizeObserver = new ResizeObserver(() => {
      updateHeight(docMiniApp);
    });

    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
    };
  }, [docMiniApp, updateHeight]);

  // 检查是否需要连接 WebSocket（音乐/系统/状态至少选一个）
  const shouldConnectWebSocket = config && (
    displayOptions.music || displayOptions.system || displayOptions.activity
  );

  // WebSocket连接（仅在需要时连接）
  const { connect: reconnectWebSocket } = useWebSocket({
    apiBaseUrl: shouldConnectWebSocket ? (config?.apiBaseUrl || '') : '',
    sharingKey: shouldConnectWebSocket ? (config?.sharingKey || '') : '',
    onError: (err) => {
      console.error('WebSocket error:', err);
    },
  });

  // 处理链接提交
  const handleSubmit = useCallback(async (e: React.FormEvent) => {
    e.preventDefault();
    setInputError(null);

    if (!inputUrl.trim()) {
      setInputError('请输入分享链接');
      return;
    }

    if (!docMiniApp) {
      setInputError('初始化中，请稍候...');
      return;
    }

    // 检查编辑权限
    if (!hasEditPermission) {
      setInputError('您没有编辑权限，无法保存配置');
      return;
    }

    const parsed = parseShareLink(inputUrl.trim());
    if (!parsed) {
      setInputError('链接格式错误，请检查链接是否正确。支持格式：https://domain.com/status/{key} 或 https://domain.com/s/{key}');
      return;
    }

    try {
      // 保存配置，包含显示选项和原始URL
      const configToSave: StorageConfig = {
        ...parsed,
        displayOptions,
        originalUrl: inputUrl.trim(), // 保存原始输入的网址
      };
      await saveConfig(configToSave, docMiniApp);
      setConfig(configToSave);
      setInputUrl('');
      
      // 保存成功后，延迟调整高度以确保 DOM 已更新
      setTimeout(() => {
        updateHeight(docMiniApp);
      }, 100);
    } catch (err) {
      console.error('Failed to save config:', err);
      setInputError('保存配置失败，请重试');
    }
  }, [inputUrl, docMiniApp, updateHeight, displayOptions, hasEditPermission]);

  // 清除配置（重新输入）
  const handleClear = useCallback(async () => {
    if (!docMiniApp || !config) return;
    try {
      // 保留之前的原始网址和显示选项，用于重新配置
      const previousUrl = config.originalUrl || `${config.apiBaseUrl}/s/${config.sharingKey}`;
      const previousDisplayOptions = config.displayOptions || DEFAULT_DISPLAY_OPTIONS;
      
      await clearConfig(docMiniApp);
      setConfig(null);
      setError(null);
      
      // 恢复之前输入的原始网址和显示选项
      setInputUrl(previousUrl);
      setDisplayOptions(previousDisplayOptions);
      
      // 清除配置后，延迟调整高度以确保 DOM 已更新
      setTimeout(() => {
        updateHeight(docMiniApp);
      }, 100);
    } catch (err) {
      console.error('Failed to clear config:', err);
    }
  }, [setError, docMiniApp, updateHeight, config]);

  // 处理显示选项变化
  const handleDisplayOptionChange = useCallback((key: keyof DisplayOptions, checked: boolean) => {
    setDisplayOptions((prev) => ({
      ...prev,
      [key]: checked,
    }));
  }, []);

  // 加载中
  if (loading) {
    return (
      <div className="app-container" ref={containerRef}>
        <LoadingSpinner size="lg" text="加载中..." />
      </div>
    );
  }

  // 无配置时显示输入界面
  if (!config) {
    return (
      <div className="app-container" ref={containerRef}>
        <div className="input-container">
          <div className="input-header">
            <div className="input-title-row">
              <h2 className="input-title">配置分享链接</h2>
              <button
                type="button"
                onClick={() => {
                  const docsUrl = process.env.DOCS_URL || 'https://example.com';
                  window.open(docsUrl, '_blank');
                }}
                className="input-docs-link"
                title="说明文档"
              >
                说明文档
              </button>
            </div>
            <p className="input-subtitle">请粘贴您的状态分享链接</p>
          </div>
          
          <form onSubmit={handleSubmit} className="input-form">
            <div className="input-group">
              <label htmlFor="share-link" className="input-label">
                分享链接
              </label>
              <input
                id="share-link"
                type="text"
                value={inputUrl}
                onChange={(e) => {
                  setInputUrl(e.target.value);
                  setInputError(null);
                }}
                placeholder="https://xxx.com/status/xxx"
                className={inputError ? 'input-field input-error' : 'input-field'}
              />
              {inputError && (
                <p className="input-error-text">{inputError}</p>
              )}
            </div>

            {/* 显示选项配置 */}
            <div className="input-group">
              <label className="input-label">展示内容</label>
              <div className="display-options">
                <label className="display-option-item">
                  <input
                    type="checkbox"
                    checked={displayOptions.music}
                    onChange={(e) => handleDisplayOptionChange('music', e.target.checked)}
                  />
                  <span>音乐</span>
                </label>
                <label className="display-option-item">
                  <input
                    type="checkbox"
                    checked={displayOptions.system}
                    onChange={(e) => handleDisplayOptionChange('system', e.target.checked)}
                  />
                  <span>系统</span>
                </label>
                <label className="display-option-item">
                  <input
                    type="checkbox"
                    checked={displayOptions.activity}
                    onChange={(e) => handleDisplayOptionChange('activity', e.target.checked)}
                  />
                  <span>状态</span>
                </label>
                <label className="display-option-item">
                  <input
                    type="checkbox"
                    checked={displayOptions.stats}
                    onChange={(e) => handleDisplayOptionChange('stats', e.target.checked)}
                  />
                  <span>统计</span>
                </label>
              </div>
            </div>
            
            <button type="submit" className="input-submit">
              保存
            </button>
          </form>
          
          <div className="input-help">
            <p className="input-help-title">支持的链接格式：</p>
            <ul className="input-help-list">
              <li>https://domain.com/status/{'{key}'}</li>
              <li>https://domain.com/s/{'{key}'}</li>
            </ul>
          </div>
        </div>
      </div>
    );
  }

  // 有配置时显示实时状态界面
  return (
    <div className="app-container" ref={containerRef}>
      {/* 主要内容 */}
      <div className="app-content">
        {/* 错误提示 */}
        {error && (
          <div className="app-error">
            <ErrorAlert error={error} onDismiss={() => setError(null)} />
          </div>
        )}

        {/* 状态内容 */}
        {!error && (
          <div className="app-cards">
            {/* 状态卡片网格 */}
            {(displayOptions.music || displayOptions.system || displayOptions.activity) && (
              <div className={`app-cards-grid ${
                !displayOptions.music 
                  ? 'no-music' 
                  : (!displayOptions.system && !displayOptions.activity)
                    ? 'music-only'
                    : (displayOptions.system && displayOptions.activity)
                      ? 'music-system-activity'
                      : 'music-with-single'
              }`}>
                {/* 音乐状态 */}
                {displayOptions.music && (
                  <div className="app-card-music">
                    <MusicCard music={currentState?.music || { ts: 0 }} apiBaseUrl={config.apiBaseUrl} />
                  </div>
                )}

                {/* 系统状态和活动状态列 */}
                {(displayOptions.system || displayOptions.activity) && (
                  <div className="app-card-system-activity">
                    {/* 系统状态 */}
                    {displayOptions.system && (
                      <div className="app-card-system">
                        <SystemCard system={currentState?.system || { ts: 0 }} />
                      </div>
                    )}

                    {/* 活动状态 */}
                    {displayOptions.activity && (
                      <div className="app-card-activity">
                        <ActivityCard activity={currentState?.activity || { ts: 0 }} />
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* 统计数据卡片 */}
            {displayOptions.stats && (
              <StatsCard 
                sharingKey={config.sharingKey} 
                apiBaseUrl={config.apiBaseUrl}
                enabled={displayOptions.stats}
              />
            )}
          </div>
        )}
      </div>

      {/* 底部 */}
      <div className="app-footer">
        <div className="app-footer-left">
          <h1 className="app-title">Share My Status</h1>
        </div>
        <div className="app-footer-right">
        <ConnectionStatus 
          status={connectionStatus} 
          onRetry={shouldConnectWebSocket ? reconnectWebSocket : undefined}
        />
        {hasEditPermission ? (
          <button
            onClick={() => {
              const docsUrl = process.env.DOCS_URL || 'https://example.com';
              window.open(docsUrl, '_blank');
            }}
            className="app-help-btn"
            title="说明文档"
          >
            说明文档
          </button>
        ) : (
          <button
            onClick={() => {
              const docsUrl = process.env.DOCS_URL || 'https://example.com';
              window.open(docsUrl, '_blank');
            }}
            className="app-need-help-btn"
            title="我也要用"
          >
            🎶 我也要用
          </button>
        )}
          {hasEditPermission && (
            <button
              onClick={handleClear}
              className="app-clear-btn"
              title="重新配置"
            >
              重新配置
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
