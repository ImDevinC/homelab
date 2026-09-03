# AGENTS.md

## Critical workflow rules

- Never change a cluster directly. Never push to `main` directly. The user must explicitly authorize any direct cluster or `main` action.
- Make all changes through a pull request. Merging to `main` deploys to the cluster.
- Argo CD auto-syncs from `main` with `automated` and `prune: true`. A merge is a production deployment.
- Commit plaintext secrets only as SealedSecrets. Never commit raw secrets or credentials.
- Validate Kustomize output before a PR: run `kubectl kustomize <chart-dir>` (builds the rendered manifests). CI is Renovate-only; there is no test job.

## Repository layout

- `apps/` - the Argo CD app-of-apps umbrella. `apps/templates/*.yaml` holds one Argo CD `Application` per app. `apps/templates/root.yaml` bootstraps the tree and points at `apps/`.
- `charts/` - one directory per application. Each directory is a Kustomize project that the matching Argo CD Application renders.
- `renovate.json` + `.github/workflows/renovate.yaml` - Renovate opens dependency bump PRs (Helm charts, container image tags).

## How apps are managed

- Every app is an Argo CD `Application` in `apps/templates/<name>.yaml` with `source.path: charts/<name>`, `targetRevision: HEAD`, and repo `https://github.com/imdevinc/homelab.git` (some apps use the SSH form `git@github.com:ImDevinC/homelab.git`).
- To add an app: create `charts/<name>/kustomization.yaml` plus its resources, then add the matching Application in `apps/templates/`. Argo CD picks it up from the app-of-apps.
- Chart kustomization files declare upstream Helm charts via `helmCharts:` (repo, version, `valuesFile`), pin image tags via `images:` (not in values.yaml), and add raw manifests (HTTPRoute, PVC, SealedSecret, Middleware, ServiceMonitor) via `resources:`.
- Apps sync into their own namespace (most set `CreateNamespace=true`). Image tags are bumped by Renovate PRs; pinned `newTag` values live in the `images:` block.
- Some charts ship `update_crds.sh` scripts (k8up, traefik) that regenerate vendored CRDs from upstream Helm. Re-run them after upgrading those charts.
- The `monitoring` chart has a `Makefile` that generates PrometheusRules and GrafanaDashboards from jsonnet mixins. Do not hand-edit generated files (they carry a "DO NOT EDIT" header).

## Networking

- MetalLB (namespace `metallb-system`) assigns LoadBalancer IPs from the pool `192.168.1.64/26` (`charts/metallb/address-pool.yaml`, L2 advertisement).
- Traefik is the ingress controller and uses the Gateway API, not Ingress. The Gateway is `traefik-gateway` in the `traefik` namespace. Listeners:
  - `web` / `websecure` (80/8443): internal `*.int.imdevinc.com`, IP allowlist middleware, wildcard TLS cert, HTTP→HTTPS redirect.
  - `cloudflared` (8090): public `*.imdevinc.com` traffic that arrives via the Cloudflare tunnel.
  - `ssh` (2222): TCP.
- Gateway API CRDs come from `traefik/kustomization.yaml` (experimental-install.yaml from kubernetes-sigs/gateway-api).
- External traffic pattern: an `HTTPRoute` with `parentRefs` pointing at `traefik-gateway` (namespace `traefik`) and `hostnames: <app>.int.imdevinc.com`. This is how every internal app is exposed.
- Public traffic pattern: the cloudflared tunnel (`charts/cloudflared/cloudflared.yaml`) routes `*.imdevinc.com` hostnames either directly to a service or to Traefik's `cloudflared` entrypoint (port 8090) when middleware (e.g. OIDC) must run first. Update the cloudflared ingress rules to expose an app publicly.
- external-dns syncs `int.imdevinc.com` DNS records from `gateway-httproute` sources into Pi-hole at 192.168.1.249 (`charts/external-dns`). The `dns-updater` CronJob keeps the apex A record pointed at the public IP via Cloudflare.
- Certificates come from cert-manager. The `letsencrypt-traefik` ClusterIssuer (DNS01 via Cloudflare) issues the gateway wildcard cert. The `letsencrypt` ClusterIssuer (http01) is legacy/nginx.
- HTTPRoutes carry `gethomepage.dev/*` annotations that power the Homepage dashboard (group, name, icon).

## Storage

- Default StorageClass is `hostpath-csi` (KubeVirt hostpath-provisioner), backed by the host path `/mnt/media` (`charts/hostpath-provisioner`). It uses `ReclaimPolicy: Retain` and `WaitForFirstConsumer`.
- Media apps mount the host path `/mnt/media` directly with `subPath` (e.g. `config/sonarr`, `media/tv`) via a single `hostPath` volume. See `charts/mediaserver/<app>/deployment.yaml`.
- Stateful apps use ReadWriteOnce PVCs, often with an explicit `storageClassName: hostpath-csi` (e.g. `charts/ollama/pvc.yaml`, `charts/pocket-id`).
- Database and app credentials are passed to pods via `envFrom: secretRef` or `secretKeyRef`.

## Backups (k8up)

- k8up (namespace `k8up`) is the backup operator. It stores restic backups in S3 and is configured with `skipWithoutAnnotation: true` (`charts/k8up/values.yaml`). Global S3 credentials and the restic repo password are SealedSecrets in the `k8up` namespace.
- PVC backup: annotate the PVC with `k8up.io/backup: 'true'` and add a k8up `Schedule` CR in the same namespace.
- Logical backup: annotate the Pod/Deployment template with `k8up.io/backupcommand` and `k8up.io/file-extension` (e.g. Plex tars its library, Tautulli tars `/config/backups/`, Forgejo runs `forgejo dump -f -`).
- `Schedule` CRs (k8up.io/v1) define `backup` / `check` / `prune`, typically `@daily-random` with `keepLast: 2` (e.g. `charts/sure/schedule.yaml`, `charts/mediaserver/plex/schedule.yaml`).

## Secrets

- Secrets are stored as bitnami `SealedSecret` CRs (controller in `kube-system`) inside each app chart. Create them with `kubeseal` and commit only the SealedSecret.
- `imagepullsecret-patcher` copies the `dockerauth` dockerconfigjson secret into every ServiceAccount so private images (ghcr.io/imdevinc/*) can be pulled without per-app imagePullSecrets.

## Databases

- CloudNativePG (CNPG) operator runs in the `cnpg` namespace.
- One postgres `Cluster` lives in `charts/postgres` (namespace `postgres`); apps get one `Database` CR each under `charts/postgres/databases/`.
- Apps reach Postgres at `postgres-rw.postgres.svc.cluster.local` (the cluster service). The cluster loads `vchord` (vector) and `postgis` extensions.
- Redis is a cluster in the `redis` namespace; apps reach it at `redis-master.redis`.

## Identity / auth

- Pocket-ID (`login.int.imdevinc.com`) is the OIDC provider (`charts/pocket-id`).
- Apps integrate with OIDC by pointing at the Pocket-ID discovery URL (open-webui, dawarich, forgejo, mealie, grafana, argo-cd, minions).
- The Traefik plugin `traefik-oidc-auth` provides middleware-based OIDC protection. Middleware references secrets with the `urn:k8s:secret:<name>:<key>` syntax (see `charts/pr-queue/middleware.yaml`, `charts/silverbullet/httproute.yaml`).

## Monitoring

- Stack in the `monitoring` namespace: VictoriaMetrics, Prometheus operator CRDs, Grafana operator, kube-state-metrics, node-exporter, OpenTelemetry operator.
- Apps expose metrics through `ServiceMonitor` CRs (e.g. `exportarr` sidecars for Sonarr/Radarr, `traefik` serviceMonitor, dcgm-exporter for GPUs).
- Grafana dashboards and PrometheusRules are generated from the monitoring jsonnet mixins via the Makefile.

## Priority classes

- `infrastructure-critical` (1e9) - MetalLB, storage provisioner.
- `critical` (1e6) - Traefik, GPU drivers, imagepullsecret-patcher.
- `important` (1e4) - Argo CD, cert-manager, monitoring, databases.
- Reference them in workloads via `priorityClassName`.

## GPU / AI workloads

- `nvidia-devices` installs GPU drivers; GPUs are requested via `nvidia.com/gpu` limits (e.g. Plex NVENC, `charts/mediaserver/plex/statefulset.yaml`).
- AI workloads: ollama, comfyui, whisper, open-webui.
- `minions` (namespace `minions`) runs the AI assistant stack: orchestrator, discord-bot, control-panel, matrix-bot, github-webhook.