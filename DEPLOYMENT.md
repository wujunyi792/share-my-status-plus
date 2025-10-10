# Share My Status - 部署文档

本文档详细介绍了 Share My Status 项目的 Docker 部署配置和使用方法。

## 📋 目录

- [项目概述](#项目概述)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [开发环境](#开发环境)
- [生产环境](#生产环境)
- [可观测性](#可观测性)
- [备份与恢复](#备份与恢复)
- [故障排除](#故障排除)
- [常用命令](#常用命令)

## 🎯 项目概述

Share My Status 是一个实时状态分享平台，支持：
- 实时音乐播放状态分享
- 系统活动监控
- 用户隐私控制
- 数据统计分析
- 完整的可观测性支持

### 架构组件

- **后端服务**: Go + Hertz 框架
- **数据库**: MySQL 8.4.5
- **缓存**: Redis 7.4


## 💻 系统要求

### 最低要求
- **操作系统**: Linux/macOS/Windows
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 4GB RAM
- **存储**: 10GB 可用空间

### 推荐配置
- **内存**: 8GB+ RAM
- **CPU**: 4 核心+
- **存储**: 50GB+ SSD

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd share-my-status-plus
```

### 2. 使用 Makefile（推荐）
```bash
# 查看所有可用命令
make help

# 快速启动开发环境
make quick-start

# 快速部署生产环境
make quick-deploy
```

### 3. 手动配置
```bash
# 复制环境配置文件
cp .env.docker.example .env.docker

# 编辑配置文件
vim .env.docker

# 启动服务
./scripts/deploy.sh
```

## 🛠️ 开发环境

### 启动开发环境

```bash
# 使用 Makefile
make dev-start

# 或使用脚本
./scripts/dev.sh start
```

### 开发环境特性

- **数据库**: MySQL (localhost:3306)
- **缓存**: Redis (localhost:6379)
- **链路追踪**: Jaeger (http://localhost:16686)
- **热重载**: 支持后端代码热重载
- **调试模式**: 启用详细日志输出

### 本地运行后端

```bash
# 启动基础设施服务
make dev-start

# 在另一个终端运行后端
make dev-backend
# 或
./scripts/dev.sh backend
```

### 开发环境管理

```bash
# 查看服务状态
make dev-status
./scripts/dev.sh status

# 查看日志
make dev-logs
./scripts/dev.sh logs [service-name]

# 重启服务
./scripts/dev.sh restart

# 清理数据
make dev-clean
./scripts/dev.sh clean
```

## 🏭 生产环境

### 部署前准备

1. **配置环境变量**
```bash
cp .env.docker.example .env.docker
```

2. **编辑配置文件**
```bash
vim .env.docker
```

重要配置项：
```bash
# 数据库配置
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_PASSWORD=your_secure_password

# 飞书配置
FEISHU_APP_ID=your_feishu_app_id
FEISHU_APP_SECRET=your_feishu_app_secret

# 安全配置
JWT_SECRET=your_jwt_secret_key_here
ENCRYPTION_KEY=your_encryption_key_32_chars_long
```

### 部署到生产环境

```bash
# 完整部署（推荐）
make deploy
# 或
./scripts/deploy.sh

# 跳过备份部署
./scripts/deploy.sh --skip-backup

# 跳过构建部署
./scripts/deploy.sh --skip-build
```

### 生产环境管理

```bash
# 启动服务
make prod-start
./scripts/start.sh start

# 查看状态
make prod-status
./scripts/start.sh status

# 监控服务
make prod-monitor
./scripts/start.sh monitor

# 查看日志
make prod-logs
./scripts/start.sh logs [service-name]

# 更新部署
make prod-update
./scripts/start.sh update

# 停止服务
make prod-stop
./scripts/start.sh stop
```

## 📊 可观测性

### 访问地址

| 服务 | 地址 | 用途 |
|------|------|------|
| 后端 API | http://localhost:8080 | 应用接口 |
| Jaeger | http://localhost:16686 | 链路追踪 |

### 监控指标

- **应用指标**: HTTP 请求、响应时间、错误率
- **系统指标**: CPU、内存、磁盘、网络

### 日志聚合

所有服务日志通过 Promtail 收集到 Loki：
- 应用日志（结构化 JSON）
- 系统日志
- 容器日志
- 数据库日志

## 💾 备份与恢复

### 创建备份

```bash
# 创建备份
make backup
./scripts/backup.sh create

# 创建命名备份
./scripts/backup.sh create before_upgrade
```

### 查看备份

```bash
# 列出所有备份
make backup-list
./scripts/backup.sh list

# 验证备份完整性
./scripts/backup.sh verify backup_name
```

### 恢复备份

```bash
# 恢复指定备份
make restore BACKUP_NAME=20240101_120000
./scripts/backup.sh restore 20240101_120000
```

### 清理旧备份

```bash
# 清理 7 天前的备份
make backup-clean
./scripts/backup.sh clean

# 清理 30 天前的备份
./scripts/backup.sh clean 30
```

## 🔧 故障排除

### 常见问题

#### 1. 端口冲突
```bash
# 检查端口占用
lsof -i :8080
lsof -i :3306

# 修改端口配置
vim .env.docker
```

#### 2. 权限问题
```bash
# 修复数据目录权限
sudo chown -R 999:999 data/mysql
```

#### 3. 内存不足
```bash
# 检查内存使用
docker stats
free -h

# 调整服务配置
vim .env.docker
```

#### 4. 磁盘空间不足
```bash
# 清理 Docker 资源
make clean
docker system prune -f

# 清理日志
docker logs --tail 100 container_name
```

### 调试命令

```bash
# 显示调试信息
make debug

# 检查服务健康状态
make health

# 查看容器状态
docker-compose ps

# 查看容器日志
docker-compose logs -f [service-name]
```

### 日志位置

- **应用日志**: `./logs/`
- **容器日志**: `docker-compose logs`
- **系统日志**: `/var/log/`（容器内）

## 📚 常用命令

### Makefile 命令

```bash
# 开发环境
make dev-start          # 启动开发环境
make dev-stop           # 停止开发环境
make dev-logs           # 查看开发日志
make dev-clean          # 清理开发数据

# 生产环境
make prod-start         # 启动生产环境
make prod-stop          # 停止生产环境
make prod-status        # 查看生产状态
make prod-monitor       # 监控生产环境

# 部署相关
make build              # 构建镜像
make deploy             # 部署到生产
make backup             # 创建备份
make restore            # 恢复备份

# 工具命令
make clean              # 清理资源
make health             # 健康检查
make version            # 版本信息
```

### Docker Compose 命令

```bash
# 基本操作
docker-compose up -d                    # 启动所有服务
docker-compose down                     # 停止所有服务
docker-compose ps                       # 查看服务状态
docker-compose logs -f [service]        # 查看日志

# 服务管理
docker-compose restart [service]        # 重启服务
docker-compose stop [service]           # 停止服务
docker-compose start [service]          # 启动服务

# 数据管理
docker-compose down -v                  # 停止并删除数据卷
docker-compose pull                     # 拉取最新镜像
```

### 脚本命令

```bash
# 开发脚本
./scripts/dev.sh start                  # 启动开发环境
./scripts/dev.sh backend                # 运行后端
./scripts/dev.sh logs mysql-dev         # 查看特定服务日志

# 生产脚本
./scripts/start.sh start                # 启动生产环境
./scripts/start.sh monitor              # 监控服务
./scripts/start.sh update               # 更新部署

# 部署脚本
./scripts/deploy.sh                     # 完整部署
./scripts/deploy.sh --skip-backup       # 跳过备份部署

# 备份脚本
./scripts/backup.sh create              # 创建备份
./scripts/backup.sh list                # 列出备份
./scripts/backup.sh restore backup_name # 恢复备份
```

## 🔐 安全注意事项

1. **修改默认密码**: 生产环境必须修改所有默认密码
2. **网络安全**: 生产环境建议使用防火墙限制端口访问
3. **SSL/TLS**: 生产环境建议配置 HTTPS
4. **定期备份**: 建议每日自动备份重要数据
5. **监控告警**: 配置监控系统告警规则
6. **日志审计**: 定期检查访问日志和错误日志

## 📞 支持与反馈

如遇到问题，请：
1. 查看本文档的故障排除部分
2. 检查服务日志：`make prod-logs` 或 `docker-compose logs`
3. 提交 Issue 到项目仓库

---

**最后更新**: 2024年1月
**版本**: 1.0.0