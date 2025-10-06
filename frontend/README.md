# Share My Status Plus - Frontend

实时状态分享平台的前端应用，基于 React + TypeScript + TailwindCSS 构建。

## 🚀 特性

- **实时状态展示**: 通过 WebSocket 实时显示音乐播放、系统状态、活动信息
- **响应式设计**: 完美适配桌面端和移动端
- **现代化UI**: 基于 TailwindCSS 的现代化界面设计
- **类型安全**: 完整的 TypeScript 类型定义
- **状态管理**: 使用 Zustand 进行状态管理
- **错误处理**: 完善的错误处理和用户反馈

## 🛠️ 技术栈

- **框架**: React 18.2
- **语言**: TypeScript 5.2
- **样式**: TailwindCSS 3.3
- **状态管理**: Zustand 4.4
- **路由**: React Router 6.20
- **构建工具**: Vite 5.0
- **HTTP客户端**: Axios 1.6
- **图标**: Lucide React

## 📦 安装依赖

```bash
npm install
```

## 🚀 开发

```bash
# 启动开发服务器
npm run dev

# 类型检查
npm run type-check

# 代码检查
npm run lint

# 构建生产版本
npm run build

# 预览生产构建
npm run preview
```

## 📁 项目结构

```
src/
├── components/          # 可复用组件
│   ├── MusicCard.tsx   # 音乐状态卡片
│   ├── SystemCard.tsx  # 系统状态卡片
│   ├── ActivityCard.tsx # 活动状态卡片
│   ├── ConnectionStatus.tsx # 连接状态组件
│   ├── ErrorAlert.tsx  # 错误提示组件
│   └── LoadingSpinner.tsx # 加载组件
├── pages/              # 页面组件
│   ├── HomePage.tsx    # 首页
│   └── StatusPage.tsx  # 状态展示页面
├── hooks/              # 自定义Hooks
│   └── useWebSocket.ts # WebSocket连接管理
├── store/              # 状态管理
│   └── useAppStore.ts  # 应用状态Store
├── types/              # 类型定义
│   └── index.ts        # 全局类型定义
├── utils/              # 工具函数
│   ├── index.ts        # 通用工具函数
│   └── api.ts          # API客户端
├── App.tsx             # 应用根组件
├── main.tsx           # 应用入口
├── index.css          # 全局样式
└── App.css            # 应用样式
```

## 🔌 API集成

### WebSocket连接

前端通过 WebSocket 与后端实时通信：

```typescript
// 连接WebSocket
const { connectionStatus, connect, disconnect } = useWebSocket({
  sharingKey: 'your-sharing-key',
  onMessage: (message) => {
    // 处理消息
  },
  onError: (error) => {
    // 处理错误
  }
});
```

### REST API

使用封装的API客户端进行HTTP请求：

```typescript
import { apiClient } from '@/utils/api';

// 查询状态
const state = await apiClient.queryState(sharingKey);

// 查询统计信息
const stats = await apiClient.queryStats(sharingKey, {
  windowType: 'rolling_7d',
  topN: 10
});
```

## 🎨 组件说明

### MusicCard
音乐状态展示卡片，显示当前播放的音乐信息：
- 歌曲名、艺术家、专辑
- 音乐封面
- 播放状态指示器

### SystemCard
系统状态展示卡片，显示系统信息：
- 电池状态和电量
- CPU使用率
- 内存使用率
- 充电状态

### ActivityCard
活动状态展示卡片，显示当前活动：
- 活动标签
- 活动图标
- 活动状态指示器

### ConnectionStatus
连接状态指示器，显示WebSocket连接状态：
- 连接中
- 已连接
- 已断开
- 连接错误

## 📱 响应式设计

应用采用响应式设计，支持多种设备：

- **桌面端**: 完整功能展示，多列布局
- **平板端**: 适配中等屏幕，优化布局
- **移动端**: 单列布局，触摸友好的界面

## 🔧 配置

### 环境变量

创建 `.env.local` 文件配置环境变量：

```env
VITE_API_BASE_URL=http://localhost:8080
VITE_WS_URL=ws://localhost:8080
```

### 代理配置

开发环境下，Vite 会自动代理 API 请求到后端：

```typescript
// vite.config.ts
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8080',
      changeOrigin: true,
    },
    '/v1': {
      target: 'http://localhost:8080',
      changeOrigin: true,
    },
  },
}
```

## 🚀 部署

### 构建

```bash
npm run build
```

构建产物将生成在 `dist/` 目录中。

### Docker部署

```dockerfile
# Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

## 📄 许可证

MIT License - 详见 [LICENSE](../../LICENSE) 文件。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request
