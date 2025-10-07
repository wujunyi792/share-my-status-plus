// 系统状态类型
export interface SystemState {
  batteryPct?: number; // 0-1
  charging?: boolean;
  cpuPct?: number; // 0-1
  memoryPct?: number; // 0-1
  ts: number; // 毫秒时间戳
}

// 音乐状态类型
export interface MusicState {
  title?: string;
  artist?: string;
  album?: string;
  coverHash?: string;
  ts: number; // 毫秒时间戳，0表示无数据
}

// 活动状态类型
export interface ActivityState {
  label?: string;
  ts: number; // 毫秒时间戳，0表示无数据
}

// 状态快照类型
export interface StateSnapshot {
  system?: SystemState;
  music?: MusicState;
  activity?: ActivityState;
  lastUpdateTs: number; // 最后更新时间戳（毫秒）
}

// WebSocket消息类型
export interface WSMessage {
  type: number; // 1=PING, 2=PONG, 3=STATUS_UPDATE, 4=SNAPSHOT, 5=ERROR
  id?: string;
  snapshot?: StateSnapshot;
  error?: string;
  errorCode?: string; // 错误代码
  retryable?: boolean; // 是否可重试
  timestamp: number;
}

// WebSocket消息类型枚举
export const WSMessageType = {
  PING: 1,
  PONG: 2,
  STATUS_UPDATE: 3,
  SNAPSHOT: 4,
  ERROR: 5,
} as const;

// WebSocket连接状态
export type WSConnectionStatus = 'connecting' | 'connected' | 'disconnected' | 'error';

// 统计数据类型
export interface MusicStats {
  topArtist?: string;
  topTitle?: string;
  uniqueTracks?: number;
  playCountWindow?: string;
}

// 统计查询请求
export interface StatsQueryRequest {
  windowType: 'rolling_3d' | 'rolling_7d' | 'month_to_date' | 'year_to_date' | 'custom';
  startTime?: number;
  endTime?: number;
  tz?: string;
  topN?: number;
}

// API响应类型
export interface APIResponse<T> {
  code: number;
  message: string;
  data: T;
}

// 封面资源类型
export interface CoverAsset {
  b64: string;
}

// 错误类型
export interface AppError {
  message: string;
  code?: string;
  details?: any;
}

// 应用状态类型
export interface AppState {
  // 当前状态快照
  currentState: StateSnapshot | null;
  // 连接状态
  connectionStatus: WSConnectionStatus;
  // 错误信息
  error: AppError | null;
  // 统计信息
  stats: MusicStats | null;
  // 是否正在加载
  loading: boolean;
}
