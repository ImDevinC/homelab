# VictoriaMetrics Multi-Tier Metrics Rollup

This directory contains the configuration for VictoriaMetrics with multi-tier metric rollup/downsampling.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Prometheus (30d full resolution)                    │
│ - All scraping, service discovery                   │
│ - Recording rules (create downsampled metrics)      │
│ - Recent data queries (0-30d)                       │
└─────────────┬───────────────────────────────────────┘
              │ remote_write (all metrics)
              ↓
┌─────────────────────────────────────────────────────┐
│ VictoriaMetrics Single (180d retention)             │
│ - Long-term storage                                 │
│ - 7-10x better compression than Prometheus          │
│ - Historical queries (0-180d)                       │
└─────────────────────────────────────────────────────┘
              ↑
┌─────────────┴───────────────────────────────────────┐
│ Grafana                                             │
│ - Default datasource: VictoriaMetrics               │
│ - Queries both recent and historical data          │
└─────────────────────────────────────────────────────┘
```

## Retention Strategy

| Time Range | Resolution | Metric Pattern | Notes |
|------------|-----------|----------------|-------|
| 0-30d | Full (scrape interval) | `homeassistant_sensor_*_power_w` | Raw data from Prometheus |
| 30-90d | 1 hour | `homeassistant:power:avg1h` | Hourly averages, grouped by entity/friendly_name |
| 90-150d | 1 day | `homeassistant:power:avg1d` | Daily averages |
| 150-180d | 1 week | `homeassistant:power:avg1w` | Weekly averages |

## How It Works

1. **Prometheus Recording Rules**: Prometheus evaluates recording rules at each interval (1h, 1d, 1w) and creates new time series with aggregated values. The rules use regex to capture ALL power sensors (`homeassistant_sensor_*_power_w`) and preserve `entity` and `friendly_name` labels.

2. **Remote Write**: All metrics (both raw and aggregated) are written to VictoriaMetrics via `remote_write`.

3. **Automatic Cleanup**: 
   - Prometheus deletes data older than 30d (raw metrics disappear)
   - VictoriaMetrics keeps 180d (aggregated metrics remain available)
   - After 30d, only downsampled metrics exist for historical queries

4. **Querying**: Use the appropriate metric name based on the time range you're querying:
   ```promql
   # Recent data (0-30d) - full resolution, all individual power sensors
   homeassistant_sensor_ac_power_w
   homeassistant_sensor_dishwasher_power_w
   # ... etc

   # Historical data (30-90d) - hourly resolution, filtered by label
   homeassistant:power:avg1h{entity="sensor.ac_power"}
   homeassistant:power:avg1h{friendly_name="Dishwasher Power"}

   # Older data (90-150d) - daily resolution
   homeassistant:power:avg1d{entity="sensor.ac_power"}

   # Oldest data (150-180d) - weekly resolution
   homeassistant:power:avg1w{entity="sensor.ac_power"}
   ```

## Grafana Query Examples

### Query by device using labels

The recording rules preserve `entity` and `friendly_name` labels, so you can filter by specific devices:

```promql
# Recent data (0-30d) - specific device
homeassistant_sensor_ac_power_w

# Historical hourly (30-90d) - filter by entity
homeassistant:power:avg1h{entity="sensor.ac_power"}

# Historical hourly - filter by friendly name
homeassistant:power:avg1h{friendly_name="Dishwasher Power"}

# Historical hourly - all devices (will show all power sensors)
homeassistant:power:avg1h

# Historical daily (90-150d) - specific device
homeassistant:power:avg1d{entity="sensor.ac_power"}
```

### Aggregate across multiple devices

```promql
# Total power usage across all devices (last hour)
sum(homeassistant:power:avg1h)

# Average power across specific devices
avg(homeassistant:power:avg1h{entity=~"sensor.(ac|dishwasher|washer)_power"})

# Top 5 power consumers (hourly average)
topk(5, homeassistant:power:avg1h)
```

### Automatic time-range based queries

For dashboards, use Grafana template variables to automatically select the right metric:

```
# Create variable: resolution
# Custom values:
#   raw: homeassistant_sensor_*_power_w
#   1h:  homeassistant:power:avg1h
#   1d:  homeassistant:power:avg1d
#   1w:  homeassistant:power:avg1w

# Then in your query:
${resolution:raw}{entity="$entity"}
```

## Adding More Metrics

The current configuration uses regex to capture ALL power sensors matching `homeassistant_sensor_*_power_w`. To add more metric types, add new rules to `recording-rules.yaml`:

```yaml
# Temperature sensors
- record: homeassistant:temperature:avg1h
  expr: avg_over_time({__name__=~"homeassistant_sensor_.*_temperature_c"}[1h]) by (entity, friendly_name)

# Humidity sensors  
- record: homeassistant:humidity:avg1h
  expr: avg_over_time({__name__=~"homeassistant_sensor_.*_humidity_percent"}[1h]) by (entity, friendly_name)

# Battery levels
- record: homeassistant:battery:avg1h
  expr: avg_over_time({__name__=~"homeassistant_sensor_.*_battery_percent"}[1h]) by (entity, friendly_name)
```

**Key points:**
- Use regex pattern `{__name__=~"pattern"}` to match multiple metrics
- Always include `by (entity, friendly_name)` to preserve device labels
- Repeat for each time interval (1h, 1d, 1w)
- Each pattern creates 3 rules (1h, 1d, 1w) instead of 24 rules per metric

## Storage Efficiency

VictoriaMetrics provides ~7-10x better compression than Prometheus:

- **Before**: 50Gi stores 30 days of full data
- **After**: 50Gi stores 180 days of data (30d full + 150d downsampled)

## Monitoring VictoriaMetrics

Access the VictoriaMetrics UI at: https://victoria-metrics.int.imdevinc.com

Useful endpoints:
- `/metrics` - Prometheus metrics from VictoriaMetrics itself
- `/api/v1/status/tsdb` - TSDB stats (cardinality, storage size)
- `/api/v1/query` - PromQL queries (same as Prometheus)

## Troubleshooting

### Check if remote_write is working

```bash
# Check Prometheus remote_write queue
kubectl exec -n monitoring prometheus-prometheus-0 -- wget -qO- localhost:9090/api/v1/status/runtimeinfo | jq .data.storageRetention

# Check VictoriaMetrics ingestion
kubectl logs -n monitoring victoria-metrics-0 | grep -i "inserted rows"
```

### Check if recording rules are evaluating

```bash
# List all recording rules
kubectl get prometheusrule -n monitoring

# Check Prometheus logs for rule evaluation
kubectl logs -n monitoring prometheus-prometheus-0 | grep -i "recording"
```

### Query both datasources from CLI

```bash
# Query Prometheus
kubectl exec -n monitoring prometheus-prometheus-0 -- wget -qO- 'localhost:9090/api/v1/query?query=homeassistant_sensor_power_w'

# Query VictoriaMetrics  
kubectl exec -n monitoring victoria-metrics-0 -- wget -qO- 'localhost:8428/api/v1/query?query=homeassistant_sensor_power_w'
```

## Future Enhancements

- Add more infrastructure metrics (node_exporter, kube-state-metrics)
- Consider Thanos if need for >180d retention or multi-cluster
- Add VictoriaMetrics backup to S3/MinIO using vmbackup
- Implement VictoriaMetrics vmalert for recording rule evaluation (removes load from Prometheus)
