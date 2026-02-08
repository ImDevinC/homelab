# Deployment Checklist

Use this checklist when deploying the VictoriaMetrics rollup configuration.

## Pre-Deployment

- [ ] Review all changes in this PR/commit
- [ ] Understand the retention strategy (see victoria-metrics/README.md)
- [ ] Backup current Prometheus configuration (optional, but recommended)
- [ ] Ensure 50Gi storage is available for VictoriaMetrics PVC

## Deployment

- [ ] Validate manifests build: `kubectl kustomize . --enable-helm > /dev/null`
- [ ] Apply changes: `kubectl apply -k . --enable-helm`
- [ ] Wait for VictoriaMetrics pod to start: `kubectl get pod -n monitoring -l app=victoria-metrics -w`

## Post-Deployment Verification (5 minutes)

- [ ] VictoriaMetrics pod is Running: `kubectl get pod -n monitoring victoria-metrics-0`
- [ ] VictoriaMetrics PVC is Bound: `kubectl get pvc -n monitoring | grep victoria`
- [ ] VictoriaMetrics service is available: `kubectl get svc -n monitoring victoria-metrics`
- [ ] HTTPRoute is created: `kubectl get httproute -n monitoring victoria-metrics`
- [ ] Recording rules are loaded: `kubectl get prometheusrule -n monitoring downsampling-rules`

## Functional Tests (10-15 minutes)

- [ ] Access VictoriaMetrics UI: https://victoria-metrics.int.imdevinc.com
- [ ] Check Prometheus remote_write is working:
  ```bash
  kubectl logs -n monitoring prometheus-prometheus-0 | grep -i "remote_write"
  # Should see: "Successfully sent batch" or similar
  ```
- [ ] Verify metrics are flowing to VictoriaMetrics:
  ```bash
  kubectl exec -n monitoring victoria-metrics-0 -- wget -qO- localhost:8428/api/v1/query?query=up | jq .
  # Should return metrics data
  ```
- [ ] Test querying homeassistant_sensor_power_w from VictoriaMetrics:
  ```bash
  kubectl exec -n monitoring victoria-metrics-0 -- wget -qO- 'localhost:8428/api/v1/query?query=homeassistant_sensor_power_w' | jq .
  ```

## Grafana Verification (5 minutes)

- [ ] Open Grafana: Check datasources page
- [ ] VictoriaMetrics datasource exists and is marked "default"
- [ ] Test VictoriaMetrics datasource (should show green checkmark)
- [ ] Test a query in Explore view: `homeassistant_sensor_power_w`
- [ ] Existing dashboards still load (they'll use VictoriaMetrics now)

## Recording Rules Verification (60-90 minutes after deployment)

Recording rules run at intervals, so wait for at least one evaluation cycle:

- [ ] Wait 1 hour after deployment
- [ ] Check if 1h recording rules exist:
  ```bash
  kubectl exec -n monitoring victoria-metrics-0 -- wget -qO- 'localhost:8428/api/v1/query?query=homeassistant_sensor_power_w:avg1h' | jq .
  # Should return data if more than 1h has passed
  ```
- [ ] Check Prometheus logs for rule evaluation:
  ```bash
  kubectl logs -n monitoring prometheus-prometheus-0 | grep "downsample"
  ```

## Monitoring (Ongoing)

- [ ] Set calendar reminder to check storage usage in 30 days
- [ ] Set calendar reminder to check storage usage in 60 days
- [ ] Monitor VictoriaMetrics metrics:
  ```bash
  kubectl exec -n monitoring victoria-metrics-0 -- wget -qO- localhost:8428/metrics | grep vm_rows
  ```

## Rollback Procedure (if needed)

If something goes wrong:

1. [ ] Remove remoteWrite from opentelemetry-operator/prometheus-operated.yaml:
   ```bash
   git checkout HEAD -- opentelemetry-operator/prometheus-operated.yaml
   ```

2. [ ] Revert Grafana datasource:
   ```bash
   git checkout HEAD -- grafana-operator/grafana-datasource.yaml
   ```

3. [ ] Remove victoria-metrics from kustomization.yaml:
   ```bash
   git checkout HEAD -- kustomization.yaml
   ```

4. [ ] Apply rollback:
   ```bash
   kubectl apply -k . --enable-helm
   ```

5. [ ] Delete VictoriaMetrics resources:
   ```bash
   kubectl delete statefulset victoria-metrics -n monitoring
   kubectl delete svc victoria-metrics -n monitoring
   kubectl delete pvc storage-victoria-metrics-0 -n monitoring
   kubectl delete prometheusrule downsampling-rules -n monitoring
   ```

## Success Criteria

✅ All checks passed if:
- VictoriaMetrics pod is running and healthy
- Prometheus is writing metrics to VictoriaMetrics (check logs)
- Grafana can query VictoriaMetrics successfully
- Recording rules are evaluating (check after 1-2 hours)
- No errors in Prometheus or VictoriaMetrics logs
- Storage usage is stable and within expectations

## Troubleshooting

### Issue: VictoriaMetrics pod won't start

Check logs:
```bash
kubectl logs -n monitoring victoria-metrics-0
kubectl describe pod -n monitoring victoria-metrics-0
```

Common issues:
- PVC not binding: Check storage class exists and has capacity
- Image pull issues: Check internet connectivity

### Issue: Prometheus not writing to VictoriaMetrics

Check remote_write status:
```bash
kubectl exec -n monitoring prometheus-prometheus-0 -- wget -qO- localhost:9090/api/v1/status/runtimeinfo
```

Check for errors:
```bash
kubectl logs -n monitoring prometheus-prometheus-0 | grep -i "remote.*error"
```

### Issue: Recording rules not evaluating

Verify rules are loaded:
```bash
kubectl get prometheusrule -n monitoring downsampling-rules -o yaml
```

Check Prometheus config includes the rules:
```bash
kubectl exec -n monitoring prometheus-prometheus-0 -- wget -qO- localhost:9090/api/v1/rules
```

### Issue: Grafana can't connect to VictoriaMetrics

Test connectivity from Grafana pod:
```bash
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name | head -1)
kubectl exec -n monitoring $GRAFANA_POD -- wget -qO- http://victoria-metrics.monitoring.svc.cluster.local:8428/api/v1/query?query=up
```

For more help, see victoria-metrics/README.md
