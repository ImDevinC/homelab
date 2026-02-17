# PRD: Kubernetes Resource Request Implementation

**Date:** 2026-02-16

---

## Problem Statement

### What problem are we solving?

Currently, 62 pods across the homelab Kubernetes cluster lack resource requests, causing unpredictable scheduling behavior and stability issues. This creates several critical problems:

1. **Unpredictable OOM Kills**: The `argo-cd-repo-server` restarts every ~40 hours, likely due to OOM kills. Without resource requests, the kubelet has no baseline for when to evict pods under memory pressure.

2. **Poor Scheduler Decisions**: The Kubernetes scheduler cannot make informed placement decisions when pods lack resource requests, leading to potential resource contention and performance degradation.

3. **No Resource Visibility**: Without requests, `kubectl top nodes` and capacity planning tools cannot show accurate resource commitments, making it impossible to predict when the cluster will run out of capacity.

4. **Increased Risk During Node Maintenance**: Without Pod Disruption Budgets (which depend on proper resource allocation), critical services can experience downtime during node drains or updates.

### Current State

- **Total pods**: 100+ across all namespaces
- **Pods without resource requests**: 62 pods
- **Pods with requests**: ~40 pods (mediaserver namespace, control plane, some monitoring)
- **Node capacity**: 12 CPU cores, 48GB RAM
- **Current utilization**: 12% CPU, 50% memory (good headroom available)
- **Known issues**: argo-cd-repo-server restarts every ~40 hours

### Why Now?

The cluster has been running for 2+ years without resource requests, but recent growth in services (80+ pods) and the recurring repo-server restarts have made this issue critical. Establishing resource baselines now will prevent future stability issues as the cluster scales.

### Who is Affected?

- **Primary**: All applications in the cluster (unpredictable performance)
- **Critical services**: ArgoCD (deployment management), Traefik (all ingress), HomeAssistant (smart home), Postgres (data persistence)
- **Secondary**: Future capacity planning and cluster scaling decisions

---

## Proposed Solution

### Overview

Add resource requests to all 62 pods based on actual 7-day average Prometheus usage data with 20% headroom. Resource requests will be added using the formula: `request = avg_usage × 1.2`, rounded to nearest increment (128Mi for memory, 10m for CPU <100m). No resource limits will be added (except for existing GPU limits) to avoid artificial throttling. Each namespace will be implemented in a separate git branch to enable independent review and deployment.

---

## End State

When this PRD is complete, the following will be true:

- [ ] All 62 pods across 31 namespaces have resource requests defined
- [ ] All resource requests are based on actual Prometheus usage data with 20% headroom
- [ ] No resource limits added (except existing GPU limits remain)
- [ ] 9 Pod Disruption Budgets created for critical services (ArgoCD, Traefik, HomeAssistant, Postgres, CouchDB, Redis, Pocket-ID, Open-WebUI, Cloudflared)
- [ ] 9 orphaned Persistent Volumes deleted and disk space reclaimed
- [ ] Prometheus alerts configured for pod stability monitoring (PodRestartingFrequently, PodOOMKilled, PodCrashLooping, PodNotReady)
- [ ] All changes committed in 34 separate git branches (one per namespace + monitoring + cleanup)
- [ ] argo-cd-repo-server restart interval increases from ~40h to >7 days
- [ ] Node resource capacity accurately reflected in `kubectl top nodes`
- [ ] Zero OOM kills on pods with resource requests

---

## Success Metrics

### Quantitative

| Metric | Current | Target | Measurement Method |
|--------|---------|--------|-------------------|
| Pods with resource requests | 40/100+ | 100+/100+ | `kubectl get pods --all-namespaces -o json \| jq '[.items[] \| select(.spec.containers[].resources.requests)] \| length'` |
| argo-cd-repo-server restart interval | ~40 hours | >7 days | `kubectl get pod -n argo-cd -l app.kubernetes.io/name=argocd-repo-server -o json \| jq '.items[0].status.containerStatuses[0].restartCount'` |
| OOM kills per week | Unknown (>0) | 0 | Prometheus alert: `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}` |
| Node resource commitment visibility | Inaccurate | Accurate | `kubectl describe node` shows realistic allocatable resources |

### Qualitative

- Improved confidence in cluster stability
- Better capacity planning capabilities
- Reduced troubleshooting time for resource-related issues
- Established baseline for future resource optimization

---

## Acceptance Criteria

### Resource Requests - Priority 1: Critical Infrastructure (6 namespaces)

- [ ] **argo-cd** (6 pods): application-controller (50m CPU, 1Gi mem), repo-server (10m, 512Mi), server (10m, 256Mi), redis (10m, 128Mi), applicationset-controller (10m, 128Mi), notifications-controller (10m, 128Mi)
- [ ] **traefik** (1 pod): traefik (20m CPU, 256Mi memory)
- [ ] **homeassistant** (3 pods): home-assistant (20m, 1408Mi), esphome (10m, 128Mi), zwavejsui (20m, 256Mi)
- [ ] **postgres** (2 pods): postgres (10m, 384Mi), postgres-exporter (10m, 128Mi)
- [ ] **open-webui** (3 pods): open-webui (10m, 1024Mi), pipelines (10m, 128Mi), tika (10m, 384Mi)
- [ ] **pocket-id** (1 pod): pocket-id (10m, 128Mi)

### Resource Requests - Priority 2: Important Services (4 namespaces)

- [ ] **dawarich** (2 pods): dawarich (10m, 640Mi), sidekiq (10m, 384Mi)
- [ ] **loki** (2 pods): loki (10m, 512Mi), promtail (60m, 384Mi)
- [ ] **couchdb** (1 pod): couchdb (20m, 256Mi)
- [ ] **wallabag** (1 deployment + 1 cronjob): wallabag (10m, 256Mi), wallabag-tagger (10m, 128Mi)

### Resource Requests - Priority 3: Standard Services (21 namespaces)

- [ ] **cert-manager** (3 pods): cert-manager (10m, 256Mi), webhook (10m, 128Mi), cainjector (10m, 256Mi)
- [ ] **cloudflared** (2 replicas): cloudflared (10m, 128Mi per pod)
- [ ] **external-dns** (1 pod): external-dns (10m, 128Mi)
- [ ] **speedtest** (1 pod): speedtest (10m, 128Mi)
- [ ] **kube-system** (1 pod): sealed-secrets-controller (10m, 128Mi)
- [ ] **homepage** (1 pod): homepage (10m, 256Mi)
- [ ] **umami** (1 pod): umami (10m, 384Mi)
- [ ] **btc-tracker** (1 pod): btc-tracker (10m, 256Mi)
- [ ] **sure** (2 pods): sure (10m, 640Mi), sure-worker (10m, 640Mi)
- [ ] **rss-server** (1 pod): rss-server (10m, 128Mi)
- [ ] **scrutiny** (1 pod): scrutiny (10m, 256Mi)
- [ ] **nutweb** (1 pod): nutweb (10m, 128Mi)
- [ ] **dnd-proxy** (1 pod): dnd-proxy (10m, 128Mi)
- [ ] **macro-track** (1 pod): macro-track (10m, 128Mi)
- [ ] **mockery-ai** (1 pod): mockery-ai (10m, 128Mi)
- [ ] **lego-ai** (1 pod): legoai (10m, 128Mi)
- [ ] **dns-duration** (1 pod): dns-duration (10m, 128Mi)
- [ ] **eero-metrics** (1 pod): eero-metrics (10m, 128Mi)
- [ ] **metallb-system** (5 containers): controller (10m, 256Mi), speaker (10m, 128Mi), speaker-frr (10m, 128Mi), speaker-frr-metrics (10m, 128Mi), speaker-reloader (10m, 128Mi)
- [ ] **monitoring** (3 pods - excluding otelcol): grafana (10m, 384Mi), kube-state-metrics (10m, 128Mi), prometheus-node-exporter (10m, 128Mi)

### Resource Requests - Priority 4: CronJobs (7 cronjobs)

- [ ] **bl-shifts**: 10m CPU, 128Mi memory
- [ ] **dns-updater**: 10m CPU, 128Mi memory
- [ ] **dead-mans-snitch**: 10m CPU, 128Mi memory
- [ ] **maxmind-downloader**: 10m CPU, 128Mi memory
- [ ] **pmm-missing**: 250m CPU, 512Mi memory (CPU-intensive processing)
- [ ] **wallabag-tagger**: Already covered in wallabag namespace
- [ ] **off-deck**: Already in mediaserver namespace (has requests)

### Pod Disruption Budgets

- [ ] **argo-cd**: 3 PDBs (application-controller, repo-server, server) with maxUnavailable: 0
- [ ] **traefik**: 1 PDB with maxUnavailable: 0
- [ ] **homeassistant**: 1 PDB (home-assistant) with maxUnavailable: 0
- [ ] **postgres**: 1 PDB with maxUnavailable: 0
- [ ] **couchdb**: 1 PDB with maxUnavailable: 0
- [ ] **redis**: 1 PDB with maxUnavailable: 0
- [ ] **pocket-id**: 1 PDB with maxUnavailable: 0
- [ ] **open-webui**: 1 PDB with maxUnavailable: 0
- [ ] **cloudflared**: 1 PDB with minAvailable: 1 (has 2 replicas)

### Prometheus Alerts

- [ ] Create `/home/devin/Projects/homelab/charts/monitoring/mixins/kubernetes/` directory structure
- [ ] Create `mixin.libsonnet` with config
- [ ] Create `alerts/pod-stability.libsonnet` with 4 alert rules:
  - PodRestartingFrequently: rate > 0.05 restarts/hour for 15m
  - PodOOMKilled: OOMKilled reason detected for 1m
  - PodCrashLooping: CrashLoopBackOff state for 5m
  - PodNotReady: Non-ready state for 5m
- [ ] Update main `mixin.libsonnet` to import kubernetes mixin
- [ ] Generate alerts with `make alerts` in monitoring directory

### Cleanup Tasks

- [ ] Delete 9 orphaned Persistent Volumes:
  - 4x dendrite-* (6 days old)
  - 3x hunyuan3d-* (20-21 days old)
  - 2x comfyui-* (38 days old)
  - 1x free-games-claimer (405 days old)
- [ ] Verify no active PVCs reference these PVs before deletion
- [ ] Confirm disk space reclaimed on `/mnt/media` mount

### Git Branch Structure

- [ ] 34 total branches created: 31 namespace branches + 1 monitoring-alerts + 1 cronjobs + 1 cleanup-pvs
- [ ] Branch naming: `resource-requests/<namespace>`
- [ ] Each branch contains only changes for that namespace
- [ ] All branches pushed to origin for independent review/merge

---

## Technical Context

### Existing Patterns

**Pattern 1: Mediaserver namespace (all pods have requests)**
- Location: `/home/devin/Projects/homelab/charts/mediaserver/`
- Example: Jellyfin, Plex, Sonarr, Radarr all have resource requests defined
- Why relevant: This is the template for what "done" looks like

**Pattern 2: Redis statefulset (already has requests)**
- Location: `/home/devin/Projects/homelab/charts/redis/statefulset.yaml:49-57`
- Already configured with requests (100m CPU, 128Mi memory) and limits
- Why relevant: Should be excluded from work scope

**Pattern 3: Helm values.yaml format**
- Location: Multiple charts use Helm with `values.yaml` (argo-cd, traefik, cert-manager, etc.)
- Resources added via `resources.requests` key in values
- Why relevant: Primary modification pattern for Helm-based deployments

**Pattern 4: Raw manifest format**
- Location: postgres, btc-tracker, rss-server use raw Kubernetes manifests
- Resources added directly in deployment spec under `containers[].resources.requests`
- Why relevant: Secondary modification pattern for non-Helm deployments

**Pattern 5: Grafana operator-managed**
- Location: `/home/devin/Projects/homelab/charts/monitoring/grafana-operator/grafana.yaml`
- Uses Grafana CRD with `deployment.spec.template.spec.containers[].resources`
- Why relevant: Special handling needed for operator-managed resources

### Key Files

- `/home/devin/Projects/homelab/charts/` - Root directory for all application charts
- `/home/devin/Projects/homelab/charts/*/values.yaml` - Helm chart values (most common modification target)
- `/home/devin/Projects/homelab/charts/*/manifest.yaml` - Raw Kubernetes manifests
- `/home/devin/Projects/homelab/charts/*/deployment.yaml` - Standalone deployments
- `/home/devin/Projects/homelab/charts/*/kustomization.yaml` - Kustomize resource lists (need updates for PDBs)
- `/home/devin/Projects/homelab/charts/monitoring/mixins/` - Prometheus alert definitions (jsonnet)
- `/home/devin/Projects/homelab/charts/monitoring/Makefile` - Alert generation (`make alerts`)

### System Dependencies

**External Services:**
- Prometheus API: `https://prometheus.int.imdevinc.com/api/v1/query` - Source of actual usage data
- ArgoCD: Auto-syncs from git repository, applies changes to cluster
- Grafana: Monitors pod metrics and resource usage trends

**Infrastructure:**
- Single-node Arch Linux cluster running Kubernetes v1.31.1
- Storage: hostpath-provisioner using `/mnt/media` (37.4TB pool, 56% used)
- Monitoring: Prometheus with 180-day retention (currently 30 days of data available)
- Alerting: Alertmanager sends alerts to Pushover

**Package Requirements:**
- `kubectl` - Cluster interaction
- `jq` - JSON parsing for validation
- `jsonnet` - Alert mixin compilation
- `yq` - YAML processing for alerts

### Data Sources

**Prometheus Queries Used:**
```promql
# 7-day average memory usage
avg_over_time(container_memory_working_set_bytes{container!="",pod!=""}[7d]) / 1024 / 1024

# 7-day average CPU usage (millicores)
avg_over_time(rate(container_cpu_usage_seconds_total{container!="",pod!=""}[5m])[7d:5m]) * 1000
```

**Resource Request Calculation:**
- Formula: `request = avg_usage × 1.2` (20% headroom)
- Memory rounding: Round up to nearest 128Mi increment
- CPU rounding: <100m → nearest 10m, ≥100m → nearest 50m
- Philosophy: Requests-only (no limits except existing GPU limits)

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| argo-cd-repo-server continues restarting after adding 512Mi request | Medium | High | Start at 512Mi, monitor for 48h. If restarts continue, increment to 768Mi → 1Gi. Document investigation steps in commit. |
| Pod fails to schedule due to insufficient node resources | Low | Medium | Current node has 88% CPU and 50% memory free. Calculated requests total well below capacity. If occurs, reduce request incrementally. |
| ArgoCD fails to sync, blocking all deployments | Low | Critical | Test ArgoCD namespace first, verify sync works before proceeding. Keep ArgoCD branch separate for quick rollback. |
| Traefik restart causes brief ingress outage | Medium | High | Deploy during low-traffic window. PDB prevents disruption during future maintenance. Monitor ingress latency post-deployment. |
| Critical service (HomeAssistant, Postgres) fails to restart | Low | High | Manual validation required per acceptance criteria. Test service functionality before merging. Git branch strategy enables instant rollback. |
| Prometheus alerts generate false positives | Medium | Low | Tune alert thresholds post-deployment. Start with conservative thresholds (15m for restarts, 5m for crashloop). |
| PDB prevents legitimate pod evictions during maintenance | Low | Medium | PDBs use maxUnavailable: 0 for single-replica services, minAvailable: 1 for multi-replica. Cluster has only 1 node, so eviction isn't common. |
| Orphaned PV deletion removes data still in use | Low | High | Verify no active PVCs reference PVs before deletion. Check kubectl get pvc --all-namespaces output. |

---

## Alternatives Considered

### Alternative 1: Add both resource requests AND limits

- **Description:** Configure both `resources.requests` and `resources.limits` for all pods
- **Pros:** 
  - Prevents runaway resource consumption
  - Enforces hard caps on memory/CPU usage
  - More "complete" resource configuration
- **Cons:** 
  - CPU limits cause unnecessary throttling even when node has spare capacity
  - Memory limits trigger OOM kills instead of allowing kernel to manage memory pressure
  - Reduces cluster utilization efficiency
  - Homelab environment has spare capacity, hard limits provide little benefit
- **Decision:** Rejected. Limits cause more problems than they solve in this environment. Requests-only approach provides scheduling guarantees without artificial constraints.

### Alternative 2: Use static baseline values (e.g., 10m/128Mi for everything)

- **Description:** Apply uniform "small" resource requests to all pods without analyzing actual usage
- **Pros:**
  - Much faster to implement
  - No need to query Prometheus or analyze usage patterns
  - Simple, consistent approach
- **Cons:**
  - Doesn't reflect actual usage (home-assistant uses 1.1GB, would be severely under-requested)
  - High-usage pods (pmm-missing uses 200m CPU) would be under-allocated
  - Low-usage pods would be over-allocated, wasting schedulable resources
  - Defeats the purpose of establishing realistic baselines
- **Decision:** Rejected. Data-driven approach ensures requests match reality.

### Alternative 3: Implement one namespace at a time in a single branch

- **Description:** Create a single long-lived branch, implement all namespaces sequentially, merge when complete
- **Pros:**
  - Only one branch to track
  - Simpler git history
  - Single PR for review
- **Cons:**
  - All-or-nothing merge - can't deploy critical services first
  - Cannot cherry-pick specific namespaces for testing
  - Higher risk of conflicts if main branch changes
  - Harder to review (massive PR)
  - Loss of granular deployment control
- **Decision:** Rejected. Branch-per-namespace enables independent review, testing, and deployment scheduling.

### Alternative 4: Automated rollout with GitOps

- **Description:** Merge all branches at once, let ArgoCD auto-sync everything simultaneously
- **Pros:**
  - Fastest deployment
  - Least manual work
  - "Rip the bandaid off" approach
- **Cons:**
  - High blast radius if issues occur
  - Impossible to isolate which namespace caused problems
  - No ability to validate critical services before proceeding
  - Goes against homelab experimental/cautious approach
- **Decision:** Rejected. Manual, gradual rollout with validation enables learning and quick rollback.

### Alternative 5: Skip CronJobs entirely

- **Description:** Only add resource requests to long-running deployments/statefulsets, ignore CronJob templates
- **Pros:**
  - Fewer changes required
  - CronJobs run infrequently, less impact
  - Simpler scope
- **Cons:**
  - pmm-missing CronJob uses 200m CPU during runs - can starve other pods
  - Incomplete solution - scheduler still can't account for CronJob resource needs
  - Future capacity planning remains inaccurate
  - User indicated CronJobs "run frequently enough that they matter"
- **Decision:** Rejected. Include CronJobs for completeness.

---

## Non-Goals (v1)

Explicitly out of scope for this PRD:

- **Resource limits** - Not adding limits except for existing GPU allocations. Limits cause throttling and OOM issues; requests-only approach is intentional.

- **Stash and Whisparr services** - User wants to investigate these separately later. Skip entirely.

- **NVIDIA device plugin components** - Vendor-managed DaemonSets, leave as-is.

- **OTel Collector resource optimization** - Currently uses 54m CPU and 521Mi memory (high usage). Investigate separately later.

- **Grafana dashboards for resource visualization** - Prometheus alerts are required, but visual dashboards are deferred.

- **Automated testing** - User will manually validate each namespace after deployment. No automated test suite required.

- **Resource rightsizing after deployment** - This PRD establishes initial baseline requests. Future optimization based on actual usage trends is a separate effort.

- **Multi-node cluster considerations** - Single-node cluster, no need to consider pod anti-affinity, topology spread, etc.

- **Vertical Pod Autoscaler (VPA)** - Automatic resource adjustment is out of scope. Manual request values are intentional.

- **Documentation updates** - No user-facing docs, runbooks, or ADRs required per user request.

- **Redis namespace** - Already has resource requests configured. Explicitly excluded from work scope.

---

## Open Questions

| Question | Owner | Due Date | Status |
|----------|-------|----------|--------|
| Should sealed-secrets-controller modification be done via Helm chart values or raw manifest edit? | Implementation | TBD | Open |
| What is the source of btc-tracker deployment (ArgoCD shows it exists, but no obvious deployment.yaml in repo)? | Implementation | TBD | Resolved - Found in service.yaml |
| Can Grafana resources be set via operator CRD, or is it fully operator-managed? | Implementation | TBD | Resolved - CRD has deployment.spec.template.spec.containers[].resources |
| Should metallb-speaker DaemonSet resources be per-container or shared? | Implementation | TBD | Open - Need to check Helm chart format |
| Exact label selectors for all PDBs - do they match actual pod labels? | Implementation | TBD | Open - Verify with kubectl |

---

## Implementation Overview

### Git Workflow

Each namespace will be implemented in a separate branch following this pattern:

```bash
git checkout main
git pull
git checkout -b resource-requests/<namespace>
# Make changes for that namespace only
git add charts/<namespace>/
git commit -m "Add resource requests and PDB to <namespace>"
git push origin resource-requests/<namespace>
# User reviews, tests, merges when ready
```

### Branch List (34 branches)

**Priority 1 - Critical (Branches 1-6):**
1. `resource-requests/argo-cd`
2. `resource-requests/traefik`
3. `resource-requests/homeassistant`
4. `resource-requests/postgres`
5. `resource-requests/open-webui`
6. `resource-requests/pocket-id`

**Priority 2 - Important (Branches 7-10):**
7. `resource-requests/dawarich`
8. `resource-requests/loki`
9. `resource-requests/couchdb`
10. `resource-requests/wallabag`

**Priority 3 - Standard (Branches 11-29):**
11. `resource-requests/cert-manager`
12. `resource-requests/cloudflared`
13. `resource-requests/external-dns`
14. `resource-requests/speedtest`
15. `resource-requests/kube-system`
16. `resource-requests/homepage`
17. `resource-requests/umami`
18. `resource-requests/btc-tracker`
19. `resource-requests/sure`
20. `resource-requests/rss-server`
21. `resource-requests/scrutiny`
22. `resource-requests/nutweb`
23. `resource-requests/dnd-proxy`
24. `resource-requests/macro-track`
25. `resource-requests/mockery-ai`
26. `resource-requests/lego-ai`
27. `resource-requests/dns-duration`
28. `resource-requests/eero-metrics`
29. `resource-requests/metallb-system`

**Special Branches (30-34):**
30. `resource-requests/monitoring-stack` - Grafana, kube-state-metrics, prometheus-node-exporter
31. `resource-requests/cronjobs` - All CronJob template modifications
32. `resource-requests/monitoring-alerts` - Prometheus alert rules
33. `resource-requests/cleanup-pvs` - Delete orphaned PVs (commands only, no file changes)

### Testing Protocol (Per Branch)

```bash
# 1. Watch ArgoCD sync
kubectl get applications -n argo-cd -w

# 2. Verify pod restart
kubectl get pods -n <namespace> -w

# 3. Confirm resource requests applied
kubectl describe pod -n <namespace> <pod-name> | grep -A 5 "Requests:"

# 4. Check current usage vs requests
kubectl top pods -n <namespace>

# 5. Verify application functionality
# (User performs manual validation)

# 6. Monitor for issues
kubectl logs -n <namespace> <pod-name> --tail=50
```

### Rollback Procedure

If any namespace causes issues:

```bash
# Revert the specific commit
git revert <commit-hash>
git push

# ArgoCD auto-syncs and restores previous state
# Or manual sync:
kubectl get applications -n argo-cd <namespace> -o yaml | kubectl apply -f -
```

---

## Appendix

### Glossary

- **Resource Request:** Guaranteed amount of CPU/memory reserved for a pod. Used by scheduler for placement decisions.
- **Resource Limit:** Maximum amount of CPU/memory a pod can use. CPU limits cause throttling; memory limits cause OOM kills.
- **PDB (Pod Disruption Budget):** Kubernetes resource that limits voluntary disruptions (evictions, drains) to maintain availability.
- **OOM Kill:** Out-of-Memory kill - kernel terminates process when it exceeds memory limits or system is under memory pressure.
- **Headroom:** Extra capacity above average usage to handle spikes. Using 20% (1.2x multiplier).
- **P95:** 95th percentile - value below which 95% of observations fall. Not used here; using 7-day average instead.

### Reference Data

**Top Memory Consumers (7-day avg):**
1. homeassistant-home-assistant: 1108Mi
2. argo-cd-application-controller: 760Mi
3. open-webui: 726Mi
4. otelcol-collector: 521Mi (excluded from scope)
5. prometheus: 514Mi (already has requests)

**Top CPU Consumers (7-day avg):**
1. pmm-missing: 200m (CronJob)
2. prometheus: 60m (already has requests)
3. otelcol-collector: 54m (excluded from scope)
4. promtail: 46m
5. argo-cd-application-controller: 43m

**Cluster Capacity:**
- CPU: 12 cores (12,000m) - Current usage: 1,524m (12%)
- Memory: 48GB (49,152Mi) - Current usage: 24,576Mi (50%)
- Available headroom: 88% CPU, 50% memory

### References

- Kubernetes Resource Management: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- Pod Disruption Budgets: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
- Prometheus Operator Alert Configuration: https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.PrometheusRule
- Monitoring Mixins (jsonnet): https://monitoring.mixins.dev/

