# Share My Status Plus

<div>
<text x="50%" y="80%" dominant-baseline="middle" text-anchor="middle" font-size="18" font-family="Inter, system-ui, -apple-system, Segoe UI, Roboto, Arial" fill="#e5e7eb">实时状态 · 推送 · 看板 · 跳转</text>

  <p>
    <img alt="Go" src="https://img.shields.io/badge/Go-1.25-00ADD8?logo=go&logoColor=white" />
    <img alt="Hertz" src="https://img.shields.io/badge/Hertz-0.10.2-ff6f00?logo=apache&logoColor=white" />
    <img alt="React" src="https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=white" />
    <img alt="Vite" src="https://img.shields.io/badge/Vite-5-646CFF?logo=vite&logoColor=white" />
    <img alt="TailwindCSS" src="https://img.shields.io/badge/Tailwind-3-38B2AC?logo=tailwindcss&logoColor=white" />
    <img alt="Thrift" src="https://img.shields.io/badge/Thrift-IDL-1f2937?logo=apache&logoColor=white" />
  </p>

  <p>
    <a href="#快速开始">🚀 快速开始</a> ·
    <a href="#项目结构">📁 项目结构</a> ·
    <a href="#部署">🛠️ 部署</a> ·
    <a href="#反馈与贡献">🤝 贡献</a>
  </p>
</div>

一个用于分享个人/团队实时状态的轻量级全栈项目，包含后端服务、Web 前端与 macOS 桌面客户端。支持实时推送、统计看板与便捷跳转，开箱即用，易于部署。

## 功能亮点
- 实时状态推送（WebSocket）与在线用户同步
- 状态统计与图表展示（前端看板）
- 封面与公共跳转服务（/s 路由）
- macOS 桌面端快速更新状态
- 支持 Docker Compose 与 Kubernetes 部署

## 项目结构
- backend/：Go 后端（Hertz + GORM + DI）
- frontend/：Vite + React + Tailwind 前端
- desktop/macos/：macOS 客户端（Xcode 工程）
- idl/：Thrift IDL（服务接口与数据契约）
- k8s/：Kubernetes 部署清单

## 快速开始
1) 克隆与准备
- 参考 .env.example 与 backend/.env.example 配置环境变量（本地推荐 APP_ENV=debug）。

2) 后端启动
- 生成依赖注入：在项目根目录执行 `make wire`
- 启动服务：在 backend 目录执行 `APP_ENV=debug go run .`
- 健康检查：`GET /healthz`

3) 前端启动
- 进入 frontend 目录：`pnpm install && pnpm dev`
- 默认本地开发端口由 Vite 输出日志可见

4) 桌面端（macOS）
- 打开 `desktop/macos/share-my-status-client.xcodeproj` 运行
- 当前仓库默认发布路线是不使用 `Developer ID`、不做 notarization，只使用 Sparkle 的 `EdDSA` 更新签名
- 首次打开发布版时，建议先把应用移到 `/Applications`，再按 [`desktop/macos/README.md`](./desktop/macos/README.md) 里的 Gatekeeper 指引放行

5) IDL 与路由模型更新
- 修改 idl/*.thrift 后，在项目根目录执行：`make hz-update`
- 新增接口按需在 backend/api/handler/<service>/ 下实现逻辑

## 开发约定（后端）
- 环境选择：通过 APP_ENV 加载 .env 或 .env.<APP_ENV>
- 路由：常规 API 挂载于 `/api/v1`，公共跳转路由在 `/s`
- 鉴权：仅对需要保护的接口启用中间件（如 SecretKeyAuth、SharingKeyAuth）；公开接口不启用鉴权
- 数据库模型：集中在 `backend/model/db.go`，通过 AutoMigrate 自动迁移
- 依赖注入：仅在 `backend/infra/wire.go` 声明依赖，生成文件 `wire_gen.go` 不手动修改
- 响应结构：统一使用 ResponseHelper（基础 code/message + 业务数据）
- 日志：使用 logrus 记录，错误信息清晰不泄露敏感信息

## 部署
- Docker Compose：直接使用项目根目录 `docker-compose.yml`
- Kubernetes：参考 `k8s/` 目录的 Deployment/Service/Ingress/ConfigMap；按需调整配置后应用到集群

<div style="border:1px solid #e5e7eb; border-radius:12px; padding:12px; background:#fafafa;">
  <b>提示：</b> 本地开发推荐使用 <code>APP_ENV=debug</code>，并通过 <code>make wire</code>、<code>make hz-update</code> 同步依赖与路由。
</div>

## 目录速览
- .github/workflows：CI/CD
- docker/：Nginx 与持久化数据目录
- Makefile：常用开发与生成命令（wire、hz-update 等）

## 反馈与贡献
欢迎提交 Issue 或 PR 来完善功能与文档。部署或开发问题请附带日志与环境说明，便于快速定位与协作。
