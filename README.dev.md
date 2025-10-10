# Share My Status Plus - 后端本地开发环境

本文档介绍如何使用 Docker Compose 搭建后端本地开发环境。

## 🚀 快速开始

### 1. 启动开发环境

```bash
# 启动所有开发服务
docker-compose -f docker-compose.dev.yml up -d

# 或者只启动基础设施服务（推荐）
docker-compose -f docker-compose.dev.yml up -d mysql-dev redis-dev adminer redis-commander
```

### 2. 配置后端环境变量

```bash
# 复制开发环境配置
cp .env.dev backend/.env

# 根据需要修改配置
vim backend/.env
```

### 3. 运行后端服务

```bash
cd backend

# 安装依赖
go mod download

# 运行服务
go run main.go
```

## 📋 服务列表

### 核心基础设施

| 服务 | 端口 | 用途 | 访问地址 |
|------|------|------|----------|
| MySQL | 3307 | 数据库 | localhost:3307 |
| Redis | 6380 | 缓存 | localhost:6380 |

### 开发工具

| 服务 | 端口 | 用途 | 访问地址 |
|------|------|------|----------|
| Adminer | 8082 | 数据库管理 | http://localhost:8082 |
| Redis Commander | 8083 | Redis管理 | http://localhost:8083 |
| MailHog | 8025 | 邮件测试 | http://localhost:8025 |

### 监控工具（可选）

| 服务 | 端口 | 用途 | 访问地址 |
|------|------|------|----------|
| Jaeger | 16687 | 链路追踪 | http://localhost:16687 |

## 🔧 配置说明

### 简化的MySQL配置

为了简化开发环境，我们移除了复杂的MySQL配置：

- ❌ **不再需要** `my.cnf` 配置文件
- ❌ **不再需要** `init.sql` 初始化脚本  
- ✅ **使用** GORM AutoMigrate 自动创建表结构
- ✅ **使用** MySQL 8.4 默认配置
- ✅ **使用** Golang定时任务替代MySQL Event Scheduler

### GORM AutoMigrate

应用启动时会自动创建和更新数据库表结构：

```go
// 在应用启动时
db.AutoMigrate(&User{}, &StatusSnapshot{}, &MusicStats{}, &CoverAsset{}, &UserPermission{}, &AuditLog{})
```

### 定时任务

原来的MySQL `cleanup_expired_snapshots` 事件已改为Golang定时任务实现。详细信息请参考：
- 📖 [Golang定时任务实现指南](docs/golang-scheduler.md)

### 数据库连接

开发环境的数据库连接字符串：
```
dev_user:dev123@tcp(localhost:3307)/share_my_status_dev?charset=utf8mb4&parseTime=True&loc=Local
```

### Redis连接

开发环境的Redis连接：
```
redis://localhost:6380
```

### 环境变量

主要的开发环境变量：

```bash
# 数据库
MYSQL_HOST=localhost
MYSQL_PORT=3307
MYSQL_USER=dev_user
MYSQL_PASSWORD=dev123
MYSQL_DATABASE=share_my_status_dev

# Redis
REDIS_HOST=localhost
REDIS_PORT=6380

# 应用
APP_ENV=development
LOG_LEVEL=debug
LOG_FORMAT=text
```

## 🛠️ 常用命令

### Docker Compose 操作

```bash
# 启动所有服务
docker-compose -f docker-compose.dev.yml up -d

# 启动指定服务
docker-compose -f docker-compose.dev.yml up -d mysql-dev redis-dev

# 查看服务状态
docker-compose -f docker-compose.dev.yml ps

# 查看服务日志
docker-compose -f docker-compose.dev.yml logs -f mysql-dev

# 停止所有服务
docker-compose -f docker-compose.dev.yml down

# 停止并删除数据卷（谨慎使用）
docker-compose -f docker-compose.dev.yml down -v
```

### 数据库操作

```bash
# 连接到MySQL容器
docker exec -it share-my-status-mysql-dev mysql -u dev_user -p

# 备份数据库
docker exec share-my-status-mysql-dev mysqldump -u dev_user -pdev123 share_my_status_dev > backup.sql

# 恢复数据库
docker exec -i share-my-status-mysql-dev mysql -u dev_user -pdev123 share_my_status_dev < backup.sql
```

### Redis操作

```bash
# 连接到Redis容器
docker exec -it share-my-status-redis-dev redis-cli

# 查看Redis信息
docker exec share-my-status-redis-dev redis-cli info
```

## 🐛 故障排除

### 端口冲突

如果遇到端口冲突，可以修改 `.env.dev` 文件中的端口配置：

```bash
# 修改MySQL端口
MYSQL_PORT=3308

# 修改Redis端口  
REDIS_PORT=6381
```

### 数据库连接失败

1. 确认MySQL容器已启动：
   ```bash
   docker-compose -f docker-compose.dev.yml ps mysql-dev
   ```

2. 检查健康状态：
   ```bash
   docker-compose -f docker-compose.dev.yml logs mysql-dev
   ```

3. 测试连接：
   ```bash
   docker exec share-my-status-mysql-dev mysqladmin ping -h localhost -u dev_user -pdev123
   ```

### Redis连接失败

1. 确认Redis容器已启动：
   ```bash
   docker-compose -f docker-compose.dev.yml ps redis-dev
   ```

2. 测试连接：
   ```bash
   docker exec share-my-status-redis-dev redis-cli ping
   ```

### 清理环境

如果需要完全重置开发环境：

```bash
# 停止所有服务
docker-compose -f docker-compose.dev.yml down

# 删除数据卷
docker volume rm share-my-status-plus_mysql_dev_data
docker volume rm share-my-status-plus_redis_dev_data

# 重新启动
docker-compose -f docker-compose.dev.yml up -d
```

## 📝 开发建议

### 1. 推荐的开发流程

1. 启动基础设施服务（MySQL、Redis）
2. 在本地运行后端服务进行开发
3. 使用Adminer管理数据库
4. 使用Redis Commander查看缓存
5. 使用MailHog测试邮件功能

### 2. 性能优化

- 开发环境已经优化了资源使用
- MySQL缓冲池设置为128M
- Redis最大内存设置为128MB
- 连接池大小适合开发环境

### 3. 安全注意事项

- 开发环境配置较为宽松，请勿在生产环境使用
- 密码和密钥仅用于开发，生产环境需要更换
- CORS配置允许本地前端访问

## 🔗 相关文档

- [生产环境部署](DEPLOYMENT.md)
- [API文档](backend/README.md)
- [前端开发](frontend/README.md)

## 💡 提示

- 建议将 `.env.dev` 文件加入 `.gitignore`，避免提交个人配置
- 可以根据需要启用或禁用监控服务
- 开发完成后记得停止Docker服务以释放资源