# Share My Status Plus

一个现代化的实时状态分享平台。支持分享音乐播放状态与系统活动，提供隐私控制、统计分析与容器化部署方案。

## 特性
- 实时音乐状态分享与系统活动监控
- 细粒度隐私与安全：JWT、加密、审计日志
- 数据统计与分析
- 多平台支持（macOS/Windows/Linux）
- 容器化与备份恢复，一键部署

## 技术栈
- 后端：Go + Hertz
- 数据库：MySQL 8.4.x
- 缓存：Redis 7.4
- 基础设施：Docker / Docker Compose

## 快速开始（开发）
1) 克隆与进入项目
- git clone <your-repo-url>
- cd share-my-status-plus

## Kubernetes 部署说明

本项目已将原先的 `k8s.yaml` 拆分至 `k8s/` 目录，按资源类型独立管理，便于维护与按需应用。

### 前置条件
- 已有可用的 Kubernetes 集群，并安装了 Ingress 控制器（当前配置使用 `ingressClassName: higress`）。
- 已安装并配置 cert-manager，且集群中存在名为 `mjclouds-com` 的 ClusterIssuer（用于自动签发与续期证书）。
- 域名 `lark.mjclouds.com`、`status-sharing.mjclouds.com` 已解析到 Ingress 的入口地址（LoadBalancer 或边缘入口）。

### 目录结构（k8s/）
- 命名空间：`k8s/namespace.yaml`
- 应用配置：`k8s/configmap.yaml`
- 后端：`k8s/backend-deployment.yaml`、`k8s/backend-service.yaml`
- 前端：`k8s/frontend-deployment.yaml`、`k8s/frontend-service.yaml`、`k8s/frontend-nginx-configmap.yaml`
- 数据库与缓存：`k8s/mysql-deployment.yaml`、`k8s/mysql-service.yaml`、`k8s/redis-deployment.yaml`、`k8s/redis-service.yaml`
- Ingress：`k8s/ingress.yaml`

### 快速部署
1. 按需修改镜像地址（默认为 DockerHub：
   - 后端镜像：`backend-deployment.yaml` 中的 `image: wujunyi792/share-my-status-backend:v1.0.1`
   - 前端镜像：`frontend-deployment.yaml` 中的 `image: wujunyi792/share-my-status-frontend:latest`
   如使用私有仓库，请为 Deployment 增加 `imagePullSecrets`。
2. 如需修改应用变量，请编辑 `k8s/configmap.yaml`（例如 `DB_DSN`、`REDIS_URL`、`FEISHU_APP_*` 等）。
3. 如需修改域名与证书配置，请编辑 `k8s/ingress.yaml`（`rules.hosts`、`tls.hosts`、`annotations.cert-manager.io/cluster-issuer`）。当前配置已设置：
   - 注解：`cert-manager.io/cluster-issuer: mjclouds-com`
   - TLS：`tls.secretName: share-my-status-cert`（固定证书 Secret 名称）
4. 一键部署：
   ```bash
   kubectl apply -f k8s/
   ```

### 路由与证书
- Ingress 路由划分：
  - `/api/v1/ws`、`/link`、`/api`、`/v1` → 后端服务 `share-my-status-svc:8080`
  - `/` → 前端服务 `share-my-status-frontend-svc:80`
- 证书：由 cert-manager 基于 `ClusterIssuer` 自动签发与续期；Ingress 中已配置 `tls.secretName: share-my-status-cert`，无需手动声明 `Certificate`。

### 验证部署
- 查看资源状态：
  ```bash
  kubectl -n share-my-status get pods,svc,ingress
  kubectl -n share-my-status describe ingress share-my-status-ingress
  ```
- 访问前端：`https://lark.mjclouds.com` 或 `https://status-sharing.mjclouds.com`
- 校验接口与 WebSocket：前端页面加载后，接口 `GET /api/...` 与 WebSocket `/api/v1/ws` 应能正常连通。

### 注意事项（生产建议）
- 当前 MySQL 与 Redis 使用 `emptyDir` 作为临时存储，重启即丢失数据；生产环境请改为 `PersistentVolumeClaim (PVC)`。
- 将敏感配置（例如数据库与 Redis 密码、第三方密钥）迁移至 Secret，并在 Deployment 中以 `envFrom` 或 `env` 引用。
- 若使用不同的 Ingress 控制器（非 Higress），可能需要调整注解或 IngressClass。
- 若需要前端 Nginx 直接代理 `/api` 或 `/api/v1/ws`，可选择让 Ingress 的 `/api/*` 先指向前端服务，再由前端 Nginx 反代到后端；当前配置是直接在 Ingress 层分流到后端，减少一次转发。

### 升级与回滚
- 升级：修改对应 yaml 后再次执行 `kubectl apply -f k8s/`
- 回滚：可通过 `kubectl rollout undo deployment/<name> -n share-my-status` 或按需调整镜像标签回退。

