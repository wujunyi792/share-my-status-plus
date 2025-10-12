目录结构：
1. 后端：backend/
2. 前端：frontend/
3. 桌面端：desktop/
4. 后端接口IDL定义（thrift）：idl/

环境与运行：
- 通过 APP_ENV 选择环境，加载 .env 或 .env.<APP_ENV>（推荐本地使用 APP_ENV=debug）。
- 启动后端：在 backend 目录执行 APP_ENV=<env> go run .。
- 健康检查：GET /healthz。
- 依赖注入代码生成：在项目根目录执行 make wire（生成 backend/infra/wire_gen.go）。

通用后端新功能开发流程：
1. 设计接口与数据契约（IDL）：在 idl/ 目录新增或修改 Thrift IDL（*.thrift），定义服务接口与请求/响应结构。
2. 代码生成与路由更新：在项目根目录执行 make hz-update，根据 IDL 自动生成/更新后端的模型与路由代码。
3. 领域逻辑与处理器实现：在 backend/api/handler/<service>/ 下实现具体处理逻辑（handler），按需调用 domain 层与 infra 依赖。
4. 路由与中间件配置：在 backend/api/router/<service>/middleware.go 中按接口分组配置中间件；公开接口不加鉴权，需要鉴权的接口启用 SecretKeyAuth、SharingKeyAuth 等。
5. 数据库模型与迁移（如需）：在 backend/model/db.go 中新增/调整 GORM 模型并指定 TableName；确保模型被包含在 model.CreateTables(db) 中以自动迁移。数据库初始化与迁移逻辑在 backend/infra/database/database.go。
6. 依赖注入：在 backend/infra/wire.go 中将新服务与依赖纳入 ProviderSet 与 AppDependencies；在项目根目录执行 make wire 生成依赖注入代码（backend/infra/wire_gen.go），该生成文件不手动修改。
7. 启动与验证：在 backend 目录启动服务（APP_ENV=<env> go run .），通过 Debug 日志确认路由注册与监听端口；健康检查 /healthz 通过。
8. 测试数据与验收：准备必要的测试数据（如数据库初始数据），使用 curl 或客户端进行端到端验证；统一使用 ResponseHelper 组织返回结构（基础 code/message 与业务 payload）。

IDL 约定：
- 聚合入口文件：idl/api.thrift（通过 include 引入各服务 IDL）。
- 每次修改 IDL 后必须在项目根目录执行 make hz-update，以保持路由与模型同步更新。

路由与中间件约定：
- 常规 API 路由挂载于 /api/v1；公共跳转路由在 /s。
- 鉴权中间件仅对需要保护的接口启用；公开接口必须确保未启用鉴权中间件。
- 在生成的 middleware 扩展点中进行分组管理，避免在 handler 内部直接处理鉴权。

数据库模型与迁移：
- 所有模型集中在 backend/model/db.go，并通过 model.CreateTables(db) 统一执行 AutoMigrate。
- 数据库连接、连接池配置、健康检查与迁移在 backend/infra/database/database.go 完成。

响应规范与错误处理：
- 统一使用 ResponseHelper（backend/api/handler/share_my_status/helper.go）设置基础返回（code/message），并附带业务数据。
- 错误信息需清晰但不泄露敏感信息；日志通过 logrus 记录，便于排查。

测试与验收建议：
- 以 Debug 模式运行，观察 Hertz 路由注册与监听日志。
- 编写覆盖常规路径与异常路径的测试用例（参数校验、鉴权、数据库读写、外部依赖失败等）。
- 使用 /healthz 验证服务存活；对关键接口进行集成测试。

安全与规范：
- 禁止提交任何敏感凭据与密钥到仓库；配置通过环境变量管理。
- 遵循依赖注入规范：仅在 wire.go 中声明依赖，自动生成的 wire_gen.go 不修改。
- 代码风格与结构遵循现有项目模式，公共能力抽象放在 infra/domain/pkg 层，避免在 handler 中堆积复杂逻辑。