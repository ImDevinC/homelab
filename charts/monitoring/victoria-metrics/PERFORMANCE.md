# Recording Rules Performance Guide

## The Problem with Scaling Recording Rules

Recording rules have significant resource costs beyond storage:

### Resource Impact per 100 Rules

**CPU:**
- Each rule evaluates a PromQL query every interval
- 100 rules = 100 queries per cycle
- If evaluation exceeds interval, Prometheus **skips iterations** (data gaps)

**Memory:**
- Recording rules create new time series in memory
- ~2KB per series (including Go GC overhead)
- 100 rules creating 1,000 series each = 200MB additional RAM
- 100 rules creating 10,000 series each = 2GB additional RAM

**Cardinality Explosion:**
- Current config: 6 intervals × 4 aggregates = 24 new series per metric
- 100 metrics = 2,400 new series
- **This is the real killer**

## Current Configuration Analysis

Your `recording-rules.yaml` creates:
- 24 rules for `homeassistant_sensor_power_w` (6 intervals × 4 aggregates)

**If you scale to 100 metrics with same pattern:**
- 100 metrics × 24 rules = **2,400 recording rules**
- Way too many! Prometheus will struggle.

## Optimization Strategies

### 1. **Reduce Aggregation Types** (Easiest)

Most use cases only need `avg`. Remove `min`, `max`, `sum` unless specifically needed.

**Savings:** 4x fewer rules (600 rules instead of 2,400 for 100 metrics)

### 2. **Reduce Time Tiers** (Moderate)

You probably don't need all 6 time granularities. Consider:
- 0-30d: Full resolution (raw)
- 30-90d: 1h aggregates
- 90-180d: 1d aggregates

**Savings:** 3 tiers instead of 6 = 2x fewer rules

### 3. **Use Regex Selectors** (Advanced)

Instead of per-metric rules, use regex to aggregate similar metrics:

```yaml
# Instead of 100 rules for individual sensors, one rule for all:
- record: homeassistant:sensors_power:avg1h
  expr: avg_over_time({__name__=~"homeassistant_sensor_.*_power_w"}[1h])
```

**Problem:** Loses individual metric names, harder to query later.

### 4. **Aggregate by Label** (Best for Infrastructure)

If metrics share labels, aggregate across label dimensions:

```yaml
# If homeassistant_sensor_power_w has a "sensor" label:
- record: homeassistant:power_by_sensor:avg1h
  expr: avg_over_time(homeassistant_sensor_power_w[1h]) by (sensor)
```

This keeps one metric name with sensor as a label.

### 5. **Use VictoriaMetrics Downsampling Instead** (Nuclear Option)

VictoriaMetrics Enterprise has automatic downsampling. But it costs $3k-5k/year.

For OSS, stick with selective recording rules.

## Recommended Approach for Your Homelab

### Strategy: Be Selective

**Don't create recording rules for everything.** Only create rules for:

1. **High-frequency dashboard queries** (refreshing every 5-30s)
2. **Expensive aggregations** (summing across 100+ series)
3. **Metrics you actually query historically**

### Practical Pattern

For 100 metrics, use this hierarchy:

**Tier 1: Critical metrics only** (5-10 metrics)
- Full aggregation: avg, min, max at 1h, 6h, 1d intervals
- ~15-30 rules total

**Tier 2: Important metrics** (20-30 metrics)  
- Avg only at 1h and 1d intervals
- ~40-60 rules total

**Tier 3: Everything else**
- No recording rules
- VictoriaMetrics stores raw data for 180d
- Query directly when needed (less frequent)

**Total: ~70-90 rules instead of 2,400**

## Monitoring Recording Rule Performance

Watch these metrics:

```promql
# How long rules take to evaluate
prometheus_rule_evaluation_duration_seconds

# Missed evaluations (BAD - means rules are too slow)
rate(prometheus_rule_group_iterations_missed_total[5m]) > 0

# Total active series (watch for growth)
prometheus_tsdb_head_series

# Memory usage
process_resident_memory_bytes
```

## Recommended Limits

**Safe Limits:**
- **<200 recording rules**: Safe for most homelabs
- **200-500 rules**: Monitor performance closely
- **>500 rules**: Consider splitting Prometheus instances or rethinking strategy

**Per-Rule Limits:**
- Evaluation time: <1s
- Series produced: <10k (use `limit` parameter)
- If evaluation ≥ interval, optimize or reduce frequency

## Example: Optimized Recording Rules

```yaml
# Only keep essential aggregates for critical metrics
- name: downsample-critical-1h
  interval: 1h
  limit: 10000  # Prevent runaway cardinality
  rules:
  # Critical metrics - full aggregation
  - record: homeassistant_sensor_power_w:avg1h
    expr: avg_over_time(homeassistant_sensor_power_w[1h])
  
  - record: homeassistant_sensor_power_w:max1h
    expr: max_over_time(homeassistant_sensor_power_w[1h])
  
  # Additional critical metrics here (5-10 total)

- name: downsample-important-1h
  interval: 1h
  limit: 10000
  rules:
  # Important metrics - avg only
  - record: homeassistant_sensor_temperature_c:avg1h
    expr: avg_over_time(homeassistant_sensor_temperature_c[1h])
  
  # More important metrics (20-30 total)

- name: downsample-critical-1d
  interval: 1d
  limit: 10000
  rules:
  # Daily aggregates for long-term trends
  - record: homeassistant_sensor_power_w:avg1d
    expr: avg_over_time(homeassistant_sensor_power_w[1d])
```

## Alternative: Query-Time Downsampling

Instead of pre-computing everything, downsample at query time in Grafana:

```promql
# In Grafana, use avg_over_time in queries based on time range
# For >30d queries:
avg_over_time(homeassistant_sensor_power_w[1h])

# For >90d queries:
avg_over_time(homeassistant_sensor_power_w[1d])
```

**Pros:**
- No recording rules needed
- No additional storage/memory
- Flexible (change aggregation on the fly)

**Cons:**
- Slower queries (computed on-demand)
- Higher CPU load during dashboard refresh
- May timeout on very long ranges

## Decision Matrix

| Metric Usage | Recording Rules? | Why |
|--------------|------------------|-----|
| Dashboard updates every 5s | YES | Pre-compute to reduce query load |
| Queried weekly for reports | NO | Use query-time aggregation |
| Critical alerting metric | YES | Fast, reliable evaluation |
| Exploratory/ad-hoc analysis | NO | Different aggregations each time |
| High-cardinality (1000s of series) | MAYBE | Only if queries are slow/frequent |

## Summary: Your Action Plan

1. **Start small:** Keep current 24 rules for `homeassistant_sensor_power_w`
2. **Monitor:** Watch CPU, memory, rule evaluation duration for 1-2 weeks
3. **Expand carefully:** Add 5-10 metrics at a time
4. **Be selective:** Only add rules for frequently-queried metrics
5. **Target: 50-100 total rules** for homelab scale

You can always add more later. Starting conservative prevents resource issues.
