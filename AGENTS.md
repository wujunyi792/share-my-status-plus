# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Share My Status Plus — a real-time personal status sharing platform (Go backend + React frontend + MySQL + Redis). See `README.md` for architecture and `README.dev.md` for local dev commands.

### Services

| Service | How to start | Port |
|---|---|---|
| MySQL + Redis | `sudo docker compose up -d mysql redis` (from repo root) | 3306 / 6379 |
| Go Backend | `cd backend && APP_ENV=debug go run .` | 8080 |
| React Frontend | `cd frontend && pnpm dev` | 3000 |

### Non-obvious caveats

- **Go version**: The project requires Go 1.25.1 (`go.mod`). The VM snapshot installs it to `/usr/local/go`; the PATH is set in `~/.bashrc`.
- **Backend env file**: The backend loads `.env.debug` when `APP_ENV=debug`. The file must point MySQL/Redis to `localhost` (not the Docker service name `mysql`/`redis`) because the backend runs outside Docker.
- **Docker daemon**: The VM runs inside a Firecracker micro-VM. Docker requires `fuse-overlayfs` storage driver and `iptables-legacy`. Start dockerd with `sudo dockerd &>/tmp/dockerd.log &` if it is not already running.
- **Wire code generation**: `wire_gen.go` is already committed. Only re-run `make wire` after modifying `backend/infra/wire.go`.
- **ESLint config**: The frontend `.eslintrc.cjs` extends `@typescript-eslint/recommended` which should be `plugin:@typescript-eslint/recommended` for eslint-plugin v6. This is a pre-existing issue; `pnpm lint` will fail. Use `pnpm type-check` or `pnpm build` to verify TypeScript correctness.
- **esbuild build scripts**: pnpm blocks esbuild postinstall by default. The `package.json` includes `pnpm.onlyBuiltDependencies: ["esbuild"]` to allow it.
- **Health check**: `GET http://localhost:8080/healthz` — returns `{"status":"ok"}` when backend is ready.
- **Frontend proxy**: Vite dev server proxies `/api` to `http://localhost:8080` (configured in `vite.config.ts`).
- **Feishu integration**: Requires `FEISHU_APP_ID` / `FEISHU_APP_SECRET` env vars. Backend starts without them (logs a warning). Not needed for local dev/testing.
