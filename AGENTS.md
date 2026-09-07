## Purpose

Homelab GitOps repository driven by Argo CD app-of-apps. It defines the entire production
Kubernetes cluster for the `imdevinc.com` domain: GitOps apps (Argo CD, cert-manager, k8up,
CNPG/Postgres, Redis), the home assistant deployment, the media server stack (Plex, Sonarr,
Radarr, etc.), AI/GPU workloads (ollama, comfyui, whisper, open-webui, minions), monitoring
(VictoriaMetrics + Prometheus rules + Grafana), and networking (MetalLB, Traefik Gateway API,
cloudflared, external-dns). Merging to `main` deploys to the cluster because Argo CD
auto-syncs from `main` with `prune: true`.

## Critical workflow rules

- Never change a cluster directly. Never push to `main` directly. The user must explicitly authorize any direct cluster or `main` action.
- Make all changes through a pull request. Merging to `main` deploys to the cluster.
- Argo CD auto-syncs from `main` with `automated` and `prune: true`. A merge is a production deployment.
- Commit plaintext secrets only as SealedSecrets. Never commit raw secrets or credentials.
- Validate Kustomize output before a PR: run `kubectl kustomize <chart-dir>` (builds the rendered manifests). CI is Renovate-only; there is no test job.

## Repository layout

- `apps/` - the Argo CD app-of-apps umbrella (a Helm chart: `apps/Chart.yaml` name `root`). `apps/templates/*.yaml` holds one Argo CD `Application` per app. `apps/templates/root.yaml` bootstraps the tree and points at `apps/`.
- `charts/` - one Kustomize directory per application (55 charts at HEAD). Each is rendered by the matching Argo CD Application.
- `renovate.json` + `.github/workflows/renovate.yaml` - Renovate opens dependency bump PRs (Helm charts, container image tags). This is the ONLY CI workflow; there is no lint/test/build job.
- `.gitignore` - ignores `charts/monitoring/manifests/` (generated monitoring output) and `charts/**/charts/` (vendored Helm chart cache).

## Commands: validate / build / generate

Derived from files actually present in the clone (no root Makefile, Taskfile, package.json, or pyproject.toml exists):

- `kubectl kustomize <chart-dir>` — render + validate any chart's kustomize output (kustomize is available on the cluster admin's machine; NOT installed inside the Hermes pod). Run this on every touched chart before opening a PR. Equivalent: `kustomize build <chart-dir>`.
- `make -C charts/monitoring all` — regenerate PrometheusRules + GrafanaDashboards from the jsonnet mixins (targets: `clean`, `alerts`, `dashboards`, `all`; requires `jsonnet` and `yq`). Generated files `charts/monitoring/opentelemetry-operator/alerts.yaml` and `charts/monitoring/grafana-operator/dashboards.yaml` carry a "DO NOT EDIT" header; `charts/monitoring/manifests/` output is gitignored.
- `charts/traefik/update_crds.sh` and `charts/k8up/update_crds.sh` — zsh scripts that re-vendor GatewayAPI/CRD manifests (`crds/`) from the upstream Helm chart / source repo. Re-run AFTER upgrading those charts, and commit the regenerated files.
- CI: `.github/workflows/renovate.yaml` only — Renovate on a monthly cron (`0 0 1 * *`), `workflow_dispatch`, and `pull_request_target` edits restricted to `renovate/` branches. There is no test, lint, build, or kubeconform job.

## How apps are managed

- Every app is an Argo CD `Application` in `apps/templates/<name>.yaml` with `source.path: charts/<name>`, `targetRevision: main` (verified: 55/57 templates use `main`; the single exception is `sealed-secrets`, which pulls the bitnami chart directly at `targetRevision: 2.7.3`), and the repo URL is either `https://github.com/imdevinc/homelab.git` (38 apps) or the SSH form `git@github.com:ImDevinC/homelab.git` (16 apps).
- `apps/templates/root.yaml` is the bootstrap: one `Application` in namespace `argo-cd` pointing at `path: apps/`, `targetRevision: main`, `automated.prune: true`.
- To add an app: create `charts/<name>/kustomization.yaml` plus its resources, then add the matching Application in `apps/templates/`. Argo CD picks it up from the app-of-apps.
- Chart kustomization files declare upstream Helm charts via `helmCharts:` (repo, version, `valuesFile`), pin image tags via `images:` (not in values.yaml), and add raw manifests (HTTPRoute, PVC, SealedSecret, Middleware, ServiceMonitor) via `resources:`.
- Apps sync into their own namespace (most set `CreateNamespace=true`). Image tags are bumped by Renovate PRs; pinned `newTag` values live in the `images:` block.
- Some charts ship `update_crds.sh` scripts (k8up, traefik) that regenerate vendored CRDs from upstream Helm. Re-run them after upgrading those charts.
- The `monitoring` chart has a `Makefile` that generates PrometheusRules and GrafanaDashboards from jsonnet mixins. Do not hand-edit generated files (they carry a "DO NOT EDIT" header).

## Deployment flow

Argo CD app-of-apps:

1. Root `Application` (apps/templates/root.yaml) → renders `apps/` (Helm chart) → produces the child `Application` objects in `apps/templates/*.yaml`.
2. Each child Application → `charts/<name>` (Kustomize) → renders the upstream Helm chart (`helmCharts:`) plus raw manifests (`resources:`).
3. All Applications use `automated` sync with `prune: true` and finalizer `resources-finalizer.argocd.argoproj.io`; most create their namespace.
4. No sync wave annotations are used in the Application manifests (checked all 57 templates); ordering is managed by the app-of-apps tree itself.

## Conventions

- Branch model: PRs to `main` only; never push to `main` directly; merging to `main` = production deploy. No long-lived branches exist in the clone.
- Commit style (from `git log`): conventional-ish prefixes `feat:`, `fix(scope):`, `chore:` (e.g. `feat: expose hermes kanban dashboard...`, `fix(mediaserver): enable Plex NVENC...`), bare scoped subjects `(app) description` for app-only bumps (e.g. `(tokenizer) update image`, `(all) update targetRevision`), and Renovate's generated `Update all non-major dependencies`. Merge commits follow GitHub `Merge pull request #N from ImDevinC/<branch>`.
- Author/identity: humans commit as Devin Collins `<3997333+ImDevinC@users.noreply.github.com>`; the `minions` assistant (`Minion <minion@imdevinc.com>`) also authors commits. Renovate `gitAuthor` is configured in renovate.json.
- Secrets: never commit raw secrets; only bitnami `SealedSecret` CRs (see Secrets section).
- Generated files from `make` / `update_crds.sh` are committed, but hand-editing them is forbidden.

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

- Secrets are stored as bitnami `SealedSecret` CRs (controller in `kube-system`, deployed from `apps/templates/sealedsecrets.yaml` → bitnami chart `targetRevision: 2.7.3`) inside each app chart. Create them with `kubeseal` and commit only the SealedSecret.
- Verified examples in the clone: `charts/homeassistant/sealed.yaml`, `charts/cert-manager/sealed.yaml`, `charts/cloudflared/kubeseal.yaml`, `charts/imagepullsecret-patcher/sealedsecret.yaml`, `charts/external-dns/secret.yaml`, `charts/dns-updater/secret.yaml`, `charts/argo-cd/sealed.yaml` — all `bitnami.com/v1alpha1 SealedSecret` with `encryptedData` only (no plaintext).
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
- Grafana dashboards and PrometheusRules are generated from the monitoring jsonnet mixins via the Makefile (`make -C charts/monitoring all`).

## Priority classes

- `infrastructure-critical` (1e9) - MetalLB, storage provisioner.
- `critical` (1e6) - Traefik, GPU drivers, imagepullsecret-patcher.
- `important` (1e4) - Argo CD, cert-manager, monitoring, databases.
- Reference them in workloads via `priorityClassName`.

## GPU / AI workloads

- `nvidia-devices` installs GPU drivers; GPUs are requested via `nvidia.com/gpu` limits (e.g. Plex NVENC, `charts/mediaserver/plex/statefulset.yaml`).
- AI workloads: ollama, comfyui, whisper, open-webui.
- `minions` (namespace `minions`) runs the AI assistant stack: orchestrator, discord-bot, control-panel, matrix-bot, github-webhook.

## Do-not-touch zones

- **SealedSecret ciphertext files** — every `sealed.yaml`, `kubeseal.yaml`, `sealedsecret.yaml`, or `secret.yaml` under `charts/` is a bitnami `SealedSecret` with `encryptedData`. Never edit or hand-craft the ciphertext; re-create with `kubeseal` and commit only the new SealedSecret. Never replace them with plaintext secrets.
- **Generated files** — anything carrying a "DO NOT EDIT" header: `charts/monitoring/opentelemetry-operator/alerts.yaml`, `charts/monitoring/grafana-operator/dashboards.yaml`, plus the gitignored `charts/monitoring/manifests/`. Regenerate via `make -C charts/monitoring ...` instead of editing.
- **Vendored CRDs** — `charts/traefik/crds/`, `charts/k8up/crds/` (generated by the `update_crds.sh` scripts). Regenerate from upstream, don't hand-patch.
- **Bootstrap and umbrella manifests** — `apps/templates/root.yaml` (the whole tree bootstraps from here) and `apps/Chart.yaml`/`apps/values.yaml` (the app-of-apps umbrella). Changes here affect every app.
- **Live prod manifests in general** — with `prune: true` on every Application, removing or renaming an Application in `apps/templates/` DELETES the app from the cluster. Review deletions as carefully as additions.
- **Secrets in git history** — the repo convention is SealedSecrets-only; never introduce raw credentials, tokens, or `CLOUDFLARE_API_TOKEN`-style values in plaintext.
- **Cluster state** — never kubectl/apply against the live cluster; this box has no kubeconfig, and cluster changes are forbidden (declare them in the repo instead).
- **Hermes runtime** — `/opt/data` (Hermes home) and `/opt/hermes` (Hermes install) are agent runtime, not repo files; do not register or edit them as project content.

## How a canonical change flows

1. Edit or add a Kustomize chart under `charts/<name>/` (kustomization.yaml + resources/values, `images:` for image pins, `helmCharts:` for upstream charts).
2. Validate locally: `kubectl kustomize charts/<name>` (or `kustomize build`) — render and eyeball the output; regenerate any generated files via `make`/`update_crds.sh` if the chart requires it.
3. For a new app, add `apps/templates/<name>.yaml` (Application, `source.path: charts/<name>`, `targetRevision: main`, `automated.prune: true`, `CreateNamespace=true`) and a chart dir for it.
4. Open a PR (feature branch → `main`); CI runs Renovate only, so validation is on you and human review.
5. Merge to `main` — Argo CD auto-syncs the app-of-apps (automated + prune) and deploys. A merge IS a production deployment.
6. Renovate keeps image tags / chart versions current by opening bump PRs on its monthly schedule (automerge disabled in renovate.json).