# Share My Status Plus 🎵

一个现代化的实时状态分享平台，让用户可以分享他们的音乐播放状态、系统活动等信息，同时提供完整的隐私控制和数据分析功能。

## ✨ 特性

### 🎵 核心功能
- **实时音乐状态分享**: 支持多种音乐播放器的状态获取和分享
- **系统活动监控**: 监控用户的系统活动状态
- **隐私控制**: 细粒度的隐私设置，用户完全控制分享内容
- **数据统计**: 详细的音乐播放统计和活动分析
- **多平台支持**: 支持 macOS、Windows、Linux

### 🔧 技术特性
- **高性能后端**: 基于 Go + Hertz 框架
- **现代化架构**: 微服务架构，容器化部署
- **完整可观测性**: 监控、日志、链路追踪一体化
- **数据安全**: 端到端加密，安全的数据存储
- **高可用性**: 支持集群部署，自动故障恢复

## 🏗️ 技术栈

### 后端
- **框架**: [Hertz](https://github.com/cloudwego/hertz) - 高性能 Go HTTP 框架
- **数据库**: MySQL 8.4.5
- **缓存**: Redis 7.4
- **认证**: JWT + 飞书 OAuth

### 基础设施
- **容器化**: Docker + Docker Compose
- **监控**: Prometheus + Grafana
- **日志**: Loki + Promtail
- **链路追踪**: Jaeger
- **指标导出**: Node Exporter, Redis Exporter, MySQL Exporter

### 开发工具
- **构建**: Make
- **部署**: 自动化脚本
- **备份**: 自动化备份恢复

## 🚀 快速开始

### 前置要求
- Docker 20.10+
- Docker Compose 2.0+
- Make (可选，推荐)

### 1. 克隆项目
```bash
git clone <repository-url>
cd share-my-status-plus
```

### 2. 配置环境
```bash
# 复制环境配置文件
cp .env.docker.example .env.docker

# 编辑配置文件（重要！）
vim .env.docker
```

### 3. 启动服务

#### 使用 Makefile（推荐）
```bash
# 查看所有可用命令
make help

# 快速启动开发环境
make quick-start

# 快速部署生产环境
make quick-deploy
```

#### 使用脚本
```bash
# 开发环境
./scripts/dev.sh start

# 生产环境
./scripts/deploy.sh
```

### 4. 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| 后端 API | http://localhost:8080 | 应用接口 |
| Grafana | http://localhost:3000 | 监控面板 |
| Prometheus | http://localhost:9090 | 指标收集 |
| Jaeger | http://localhost:16686 | 链路追踪 |

## 📖 文档

- [部署文档](DEPLOYMENT.md) - 详细的部署和运维指南
- [API 文档](docs/api.md) - API 接口文档
- [开发指南](docs/development.md) - 开发环境搭建和开发规范

## 🛠️ 开发

### 开发环境设置

```bash
# 启动开发基础设施
make dev-start

# 在另一个终端运行后端
make dev-backend
```

### 常用开发命令

```bash
# 查看开发环境状态
make dev-status

# 查看日志
make dev-logs

# 清理开发数据
make dev-clean

# 运行测试
make test

# 代码格式化
make format

# 代码检查
make lint
```

## 🏭 生产部署

### 环境配置

1. **数据库配置**
```bash
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_PASSWORD=your_secure_password
```

2. **飞书配置**
```bash
FEISHU_APP_ID=your_feishu_app_id
FEISHU_APP_SECRET=your_feishu_app_secret
```

3. **安全配置**
```bash
JWT_SECRET=your_jwt_secret_key_here
ENCRYPTION_KEY=your_encryption_key_32_chars_long
```

### 部署命令

```bash
# 完整部署
make deploy

# 查看生产状态
make prod-status

# 监控服务
make prod-monitor

# 创建备份
make backup

# 恢复备份
make restore BACKUP_NAME=backup_name
```

## 📊 监控与可观测性

### Grafana 面板
- **应用监控**: HTTP 请求、响应时间、错误率
- **系统监控**: CPU、内存、磁盘、网络
- **数据库监控**: 连接数、查询性能、慢查询
- **缓存监控**: Redis 性能、内存使用、命中率

### 日志聚合
- 结构化应用日志
- 系统日志收集
- 容器日志聚合
- 数据库日志分析

### 链路追踪
- HTTP 请求追踪
- 数据库查询追踪
- 缓存操作追踪
- 外部 API 调用追踪

## 🔒 安全特性

- **数据加密**: 敏感数据端到端加密
- **访问控制**: 基于角色的权限管理
- **审计日志**: 完整的操作审计记录
- **安全认证**: JWT + OAuth 双重认证
- **网络安全**: 容器网络隔离

## 📈 性能特性

- **高并发**: 支持万级并发连接
- **低延迟**: 毫秒级响应时间
- **高可用**: 99.9% 服务可用性
- **弹性扩展**: 支持水平扩展
- **缓存优化**: 多层缓存策略

## 🤝 贡献

我们欢迎所有形式的贡献！

### 贡献方式
1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 开发规范
- 遵循 Go 代码规范
- 编写单元测试
- 更新相关文档
- 通过所有 CI 检查

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Hertz](https://github.com/cloudwego/hertz) - 高性能 Go HTTP 框架
- [Prometheus](https://prometheus.io/) - 监控和告警工具
- [Grafana](https://grafana.com/) - 可视化和监控平台
- [Jaeger](https://www.jaegertracing.io/) - 分布式链路追踪

## 📞 支持

- 📧 邮箱: support@example.com
- 💬 讨论: [GitHub Discussions](https://github.com/your-org/share-my-status-plus/discussions)
- 🐛 问题: [GitHub Issues](https://github.com/your-org/share-my-status-plus/issues)

---

<div align="center">

**Share My Status Plus** - 让分享更简单，让隐私更安全

[开始使用](DEPLOYMENT.md) • [API 文档](docs/api.md) • [贡献指南](#贡献)

</div>