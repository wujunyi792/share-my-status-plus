# share-my-status Helm Chart

Production-oriented Helm chart for Share My Status Plus:

- Go backend API on port 8080
- React frontend served by nginx on port 80
- Optional ingress that routes `/api`, `/v1`, `/link`, `/s`, and WebSocket traffic to the backend
- Optional Bitnami MySQL and Redis subcharts, disabled by default

## Distribution

The release workflow publishes this chart as an OCI artifact on GHCR:

```sh
helm pull oci://ghcr.io/wujunyi792/charts/share-my-status --version 1.0.503-b.1.0.5.1.f.1.0.5.2
```

Install directly:

```sh
helm install share-my-status \
  oci://ghcr.io/wujunyi792/charts/share-my-status \
  --version 1.0.503-b.1.0.5.1.f.1.0.5.2 \
  --namespace share-my-status \
  --create-namespace \
  -f values-prod.yaml
```

## Required Production Values

Override at least these values for production:

| Key | Description |
| --- | --- |
| `backend.env` or `backend.extraEnvFrom` | Backend environment variables |
| `backend.env.ENDPOINT` | Public backend endpoint |
| `backend.env.REDIRECT_DEFAULT_TARGET` | Public frontend status URL pattern |
| `backend.env.DB_DSN` | MySQL DSN |
| `backend.env.REDIS_URL` | Redis URL |
| `backend.env.REDIS_PASSWORD` | Redis password |
| `backend.env.FEISHU_APP_ID` | Feishu app ID |
| `backend.env.FEISHU_APP_SECRET` | Feishu app secret |
| `backend.env.LEGACY_CRYPTO_KEY` | Legacy compatibility key |
| `backend.env.LEGACY_CRYPTO_IV` | Legacy compatibility IV |
| `ingress.hosts` / `ingress.tls` | Public hostnames and TLS config |

`backend.extraEnvFrom` can import a whole Secret or ConfigMap, for example:

```yaml
backend:
  env: {}
  extraEnvFrom:
    - secretRef:
        name: share-my-status-config
```

`backend.extraEnv` can be used for individual `valueFrom` entries.

The bundled MySQL and Redis subcharts are disabled by default. Production should normally point `backend.env.DB_DSN` and `backend.env.REDIS_URL` at managed services. For self-contained dev or test installs, enable `mysql.enabled` and `redis.enabled`, then set the backend DSN/Redis URL to the generated in-cluster service names.

## Release Flow

1. Bump `backend`, `frontend`, and/or `chart` in the repository root `release.yml`, using `major.minor.patch-build`.
2. Merge to `main`.
3. GitHub Actions publishes:
   - changed backend images to `ghcr.io/<owner>/share-my-status-backend:<backend>`
   - changed frontend images to `ghcr.io/<owner>/share-my-status-frontend:<frontend>`
   - a chart to `oci://ghcr.io/<owner>/charts/share-my-status:<chart-version>` whenever a component or chart version changes
4. ArgoCD syncs the OCI Helm chart. CI does not deploy directly.

The chart version is derived from the `chart` release version and includes both component versions as pre-release metadata. For example, `chart: 1.0.5-3`, `backend: 1.0.5-1`, and `frontend: 1.0.5-2` becomes `1.0.503-b.1.0.5.1.f.1.0.5.2`.
