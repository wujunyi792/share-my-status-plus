# Share My Status Backend

这是一个基于Go和Hertz框架的状态分享后端服务。

## 功能特性

- 状态上报和查询
- 音乐统计和分析
- 封面管理和去重
- WebSocket实时通信（使用Hertz WebSocket）
- 飞书集成（消息命令、链接预览）
- Redis缓存
- MySQL数据库

## 技术栈

- **框架**: Hertz (CloudWeGo)
- **数据库**: MySQL 8.0 + GORM
- **缓存**: Redis
- **WebSocket**: hertz-contrib/websocket
- **飞书SDK**: larksuite/oapi-sdk-go
- **日志**: logrus

## 项目结构

```
backend/
├── api/                    # API定义和处理器
│   ├── handler/           # HTTP处理器
│   └── model/             # Thrift生成的模型
├── internal/              # 内部包
│   ├── cache/            # Redis缓存
│   ├── config/           # 配置管理
│   ├── database/         # 数据库连接
│   ├── lark/             # 飞书SDK集成
│   ├── middleware/       # 中间件
│   ├── model/            # 数据库模型
│   └── service/          # 业务逻辑服务
├── main.go               # 应用入口
└── go.mod               # Go模块定义
```

## 环境配置

创建 `.env` 文件：

```env
# 应用配置
APP_NAME=share-my-status
APP_VERSION=1.0.0
APP_ENV=dev
HTTP_PORT=8080
DEBUG=true
DEFAULT_TZ=Asia/Shanghai

# 数据库配置
DB_DSN=user:password@tcp(localhost:3306)/share_my_status?charset=utf8mb4&parseTime=True&loc=Local
DB_MAX_IDLE_CONNS=10
DB_MAX_OPEN_CONNS=100
DB_CONN_MAX_LIFETIME=3600

# Redis配置
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=
REDIS_DB=0

# 飞书配置
FEISHU_APP_ID=your_app_id
FEISHU_APP_SECRET=your_app_secret

# 日志配置
LOG_LEVEL=info
LOG_FORMAT=json
```

## 数据库初始化

```sql
CREATE DATABASE share_my_status CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

应用启动时会自动创建表结构。

## 运行

1. 安装依赖：
```bash
go mod tidy
```

2. 启动服务：
```bash
go run main.go
```

或者编译后运行：
```bash
go build -o share-my-status .
./share-my-status
```

## API接口

### 状态管理

- `POST /v1/state/report` - 批量上报状态
- `GET /v1/state/query` - 查询状态

### 统计查询

- `POST /v1/stats/query` - 查询音乐统计

### 封面管理

- `GET /v1/cover/exists` - 检查封面是否存在
- `POST /v1/cover/upload` - 上传封面
- `GET /v1/cover/{hash}` - 获取封面

### WebSocket

- `GET /v1/ws` - WebSocket连接（使用Hertz WebSocket）

### 飞书集成

- 消息命令处理：支持 `/status` 命令
- 链接预览：自动生成状态预览卡片

### 健康检查

- `GET /healthz` - 健康检查

## 认证

- **Secret Key**: 用于客户端状态上报，通过 `X-Secret-Key` 头部传递
- **Sharing Key**: 用于公开访问，通过 `sharingKey` 查询参数传递

## 飞书机器人命令

支持以下飞书机器人命令：

- `/status revoke` - 撤销当前公开链接并生成新的SharingKey
- `/status rotate` - 轮转SecretKey（需要重新配置客户端）
- `/status publish on|off` - 开启/关闭公开访问
- `/status info` - 查看账户信息和当前状态

## WebSocket功能

使用Hertz WebSocket + Redis Pub/Sub实现分布式WebSocket：

- **分布式架构**: 基于Redis Pub/Sub支持横向扩容
- **实时推送**: 支持跨节点的状态更新推送
- **连接管理**: 按用户分组的连接管理，支持多节点部署
- **心跳机制**: 每54秒发送ping保持连接活跃
- **消息路由**: 自动路由消息到正确的节点和连接
- **故障容错**: 节点故障不影响其他节点的连接

## 分布式部署

### WebSocket横向扩容

系统支持多节点部署，WebSocket连接可以分布在不同的节点上：

1. **Redis Pub/Sub**: 使用Redis作为消息中间件
2. **节点标识**: 每个节点有唯一的nodeID
3. **消息路由**: 状态更新通过Redis广播到所有节点
4. **连接管理**: 每个节点只管理本地的WebSocket连接

### 部署架构

```
[客户端] -> [负载均衡器] -> [节点1] [节点2] [节点3]
                             |      |      |
                             v      v      v
                            [Redis Pub/Sub]
                                    ^
                                    |
                                [状态更新]
```

## 开发说明

1. `backend/model` 和 `backend/router` 目录是代码生成目录，请勿手动修改
2. 数据库操作使用GORM，支持JSON字段和自动迁移
3. WebSocket使用Hertz专用的websocket库，支持完整的连接管理
4. 分布式WebSocket基于Redis Pub/Sub实现，支持横向扩容
5. 飞书集成支持消息命令处理、链接预览和WebSocket事件处理
6. 飞书事件处理器实现了用户绑定、命令执行和状态预览功能

## 部署

支持Docker和Kubernetes部署，具体配置请参考部署文档。
