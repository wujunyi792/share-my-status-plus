# Share My Status Plus - 后端本地开发环境

本文档介绍如何使用 Docker Compose 搭建后端本地开发环境。

## 🚀 快速开始

### 1. 启动开发环境

```bash
# 只启动基础设施服务
docker-compose -f docker-compose.dev.yml up -d mysql redis
```

### 2. 配置后端环境变量

```bash
# 复制开发环境配置
cp backend/.env.example backend/.env.debug

# 根据需要修改配置
vim backend/.env.debug
```

### 3. 运行后端服务

```bash
cd backend

# 安装依赖
go mod download

# 运行服务
APP_ENV=debug go run .
```

## 📋 服务列表

### 核心基础设施

| 服务 | 端口   | 用途 | 访问地址           |
|------|------|------|----------------|
| MySQL | 3306 | 数据库 | localhost:3306 |
| Redis | 6379 | 缓存 | localhost:6379 |

## 🛠️ 常用命令

### Docker Compose 操作

```bash
# 启动所有服务
docker-compose -f docker-compose.yml up -d

# 启动指定服务
docker-compose -f docker-compose.yml up -d mysql redis

# 查看服务状态
docker-compose -f docker-compose.yml ps

# 查看服务日志
docker-compose -f docker-compose.yml logs -f mysql

# 停止所有服务
docker-compose -f docker-compose.yml down

# 停止并删除数据卷（谨慎使用）
docker-compose -f docker-compose.yml down -v
```

## 🔗 相关文档

- [生产环境部署](DEPLOYMENT.md)
- [API文档](backend/README.md)
- [前端开发](frontend/README.md)