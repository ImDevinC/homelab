{
  prometheusAlerts+:: {
    groups+: 
    [
  {
    name: 'KubestateExporter',
    rules: [
      {
        alert: 'KubernetesNodeNotReady',
        expr: 'kube_node_status_condition{condition="Ready",status="true"} == 0',
        'for': '10m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes Node ready (node {{ $labels.node }})',
          description: |||
            Node {{ $labels.node }} has been unready for a long time
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesNodeSchedulingDisabled',
        expr: 'kube_node_spec_taint{key="node.kubernetes.io/unschedulable"} == 1',
        'for': '30m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes node scheduling disabled (node {{ $labels.node }})',
          description: |||
            Node {{ $labels.node }} has been marked as unschedulable for more than 30 minutes.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesNodeMemoryPressure',
        expr: 'kube_node_status_condition{condition="MemoryPressure",status="true"} == 1',
        'for': '2m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes memory pressure (node {{ $labels.node }})',
          description: |||
            Node {{ $labels.node }} has MemoryPressure condition
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesNodeDiskPressure',
        expr: 'kube_node_status_condition{condition="DiskPressure",status="true"} == 1',
        'for': '2m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes disk pressure (node {{ $labels.node }})',
          description: |||
            Node {{ $labels.node }} has DiskPressure condition
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesNodeNetworkUnavailable',
        expr: 'kube_node_status_condition{condition="NetworkUnavailable",status="true"} == 1',
        'for': '2m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes Node network unavailable (instance {{ $labels.instance }})',
          description: |||
            Node {{ $labels.node }} has NetworkUnavailable condition
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesNodeOutOfPodCapacity',
        expr: 'sum by (node) ((kube_pod_status_phase{phase="Running"} == 1) + on(uid, instance) group_left(node) (0 * kube_pod_info{pod_template_hash=""})) / sum by (node) (kube_node_status_allocatable{resource="pods"}) * 100 > 90',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes Node out of pod capacity (instance {{ $labels.instance }})',
          description: |||
            Node {{ $labels.node }} is out of pod capacity
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesContainerOomKiller',
        expr: '(kube_pod_container_status_restarts_total - kube_pod_container_status_restarts_total offset 10m >= 1) and ignoring (reason) min_over_time(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}[10m]) == 1',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes container oom killer ({{ $labels.namespace }}/{{ $labels.pod }}:{{ $labels.container }})',
          description: |||
            Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} has been OOMKilled {{ $value }} times in the last 10 minutes.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesJobFailed',
        expr: 'kube_job_status_failed > 0',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes Job failed ({{ $labels.namespace }}/{{ $labels.job_name }})',
          description: |||
            Job {{ $labels.namespace }}/{{ $labels.job_name }} failed to complete
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesJobNotStarting',
        expr: 'kube_job_status_active == 0 and kube_job_status_failed == 0 and kube_job_status_succeeded == 0 and (time() - kube_job_status_start_time) > 600',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes Job not starting ({{ $labels.namespace }}/{{ $labels.job_name }})',
          description: |||
            Job {{ $labels.namespace }}/{{ $labels.job_name }} did not start for 10 minutes
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesCronjobSuspended',
        expr: 'kube_cronjob_spec_suspend != 0',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes CronJob suspended ({{ $labels.namespace }}/{{ $labels.cronjob }})',
          description: |||
            CronJob {{ $labels.namespace }}/{{ $labels.cronjob }} is suspended
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesPersistentvolumeclaimPending',
        expr: 'kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes PersistentVolumeClaim pending ({{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }})',
          description: |||
            PersistentVolumeClaim {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is pending
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesVolumeOutOfDiskSpace',
        expr: 'kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes * 100 < 10',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes Volume out of disk space (instance {{ $labels.instance }})',
          description: |||
            Volume is almost full (< 10% left)
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesVolumeFullInFourDays',
        expr: 'predict_linear(kubelet_volume_stats_available_bytes[6h:5m], 4 * 24 * 3600) < 0',
        'for': '0m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes Volume full in four days (instance {{ $labels.instance }})',
          description: |||
            Volume under {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is expected to fill up within four days. Currently {{ $value | humanize }}% is available.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesPersistentvolumeError',
        expr: 'kube_persistentvolume_status_phase{phase=~"Failed|Pending", job="kube-state-metrics"} > 0',
        'for': '0m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes PersistentVolumeClaim pending ({{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }})',
          description: |||
            Persistent volume {{ $labels.persistentvolume }} is in bad state
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesStatefulsetDown',
        expr: 'kube_statefulset_replicas != kube_statefulset_status_replicas_ready > 0',
        'for': '1m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes StatefulSet down ({{ $labels.namespace }}/{{ $labels.statefulset }})',
          description: |||
            StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} went down
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesHpaScaleInability',
        expr: '(kube_horizontalpodautoscaler_spec_max_replicas - kube_horizontalpodautoscaler_status_desired_replicas) * on (horizontalpodautoscaler,namespace) (kube_horizontalpodautoscaler_status_condition{condition="ScalingLimited", status="true"} == 1) == 0',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes HPA scale inability (instance {{ $labels.instance }})',
          description: |||
            HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} is unable to scale
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesHpaMetricsUnavailability',
        expr: 'kube_horizontalpodautoscaler_status_condition{status="false", condition="ScalingActive"} == 1',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes HPA metrics unavailability (instance {{ $labels.instance }})',
          description: |||
            HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} is unable to collect metrics
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesHpaScaleMaximum',
        expr: '(kube_horizontalpodautoscaler_status_desired_replicas >= kube_horizontalpodautoscaler_spec_max_replicas) and (kube_horizontalpodautoscaler_spec_max_replicas > 1) and (kube_horizontalpodautoscaler_spec_min_replicas != kube_horizontalpodautoscaler_spec_max_replicas)',
        'for': '2m',
        labels: {
          severity: 'info',
        },
        annotations: {
          summary: 'Kubernetes HPA scale maximum (instance {{ $labels.instance }})',
          description: |||
            HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} has hit maximum number of desired pods
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesHpaUnderutilized',
        expr: 'max(quantile_over_time(0.5, kube_horizontalpodautoscaler_status_desired_replicas[1d]) == kube_horizontalpodautoscaler_spec_min_replicas) by (horizontalpodautoscaler) > 3',
        'for': '0m',
        labels: {
          severity: 'info',
        },
        annotations: {
          summary: 'Kubernetes HPA underutilized (instance {{ $labels.instance }})',
          description: |||
            HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} is constantly at minimum replicas for 50% of the time. Potential cost saving here.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesPodNotHealthy',
        expr: 'sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"}) > 0',
        'for': '15m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes Pod not healthy ({{ $labels.namespace }}/{{ $labels.pod }})',
          description: |||
            Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-running state for longer than 15 minutes.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesPodCrashLooping',
        expr: 'increase(kube_pod_container_status_restarts_total[1m]) > 3',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes pod crash looping ({{ $labels.namespace }}/{{ $labels.pod }})',
          description: |||
            Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesReplicasetReplicasMismatch',
        expr: 'kube_replicaset_spec_replicas != kube_replicaset_status_ready_replicas',
        'for': '10m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes ReplicasSet mismatch ({{ $labels.namespace }}/{{ $labels.replicaset }})',
          description: |||
            ReplicaSet {{ $labels.namespace }}/{{ $labels.replicaset }} replicas mismatch
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesDeploymentReplicasMismatch',
        expr: 'kube_deployment_spec_replicas != kube_deployment_status_replicas_available',
        'for': '10m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes Deployment replicas mismatch ({{ $labels.namespace }}/{{ $labels.deployment }})',
          description: |||
            Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesStatefulsetReplicasMismatch',
        expr: 'kube_statefulset_status_replicas_ready != kube_statefulset_status_replicas',
        'for': '10m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes StatefulSet replicas mismatch (instance {{ $labels.instance }})',
          description: |||
            StatefulSet does not match the expected number of replicas.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesDeploymentGenerationMismatch',
        expr: 'kube_deployment_status_observed_generation != kube_deployment_metadata_generation',
        'for': '10m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes Deployment generation mismatch ({{ $labels.namespace }}/{{ $labels.deployment }})',
          description: |||
            Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has failed but has not been rolled back.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesStatefulsetGenerationMismatch',
        expr: 'kube_statefulset_status_observed_generation != kube_statefulset_metadata_generation',
        'for': '10m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes StatefulSet generation mismatch ({{ $labels.namespace }}/{{ $labels.statefulset }})',
          description: |||
            StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has failed but has not been rolled back.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesStatefulsetUpdateNotRolledOut',
        expr: 'max without (revision) (kube_statefulset_status_current_revision unless kube_statefulset_status_update_revision) * (kube_statefulset_replicas != kube_statefulset_status_replicas_updated)',
        'for': '10m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes StatefulSet update not rolled out ({{ $labels.namespace }}/{{ $labels.statefulset }})',
          description: |||
            StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} update has not been rolled out.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesDaemonsetRolloutStuck',
        expr: 'kube_daemonset_status_number_ready / kube_daemonset_status_desired_number_scheduled * 100 < 100 or kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_current_number_scheduled > 0',
        'for': '10m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes DaemonSet rollout stuck ({{ $labels.namespace }}/{{ $labels.daemonset }})',
          description: |||
            Some Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled or not ready
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesDaemonsetMisscheduled',
        expr: 'kube_daemonset_status_number_misscheduled > 0',
        'for': '1m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes DaemonSet misscheduled ({{ $labels.namespace }}/{{ $labels.daemonset }})',
          description: |||
            Some Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are running where they are not supposed to run
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesCronjobTooLong',
        expr: 'time() - kube_cronjob_next_schedule_time > 3600',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes CronJob too long ({{ $labels.namespace }}/{{ $labels.cronjob }})',
          description: |||
            CronJob {{ $labels.namespace }}/{{ $labels.cronjob }} is taking more than 1h to complete.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesJobSlowCompletion',
        expr: 'kube_job_spec_completions - kube_job_status_succeeded - kube_job_status_failed > 0',
        'for': '12h',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes job slow completion ({{ $labels.namespace }}/{{ $labels.job_name }})',
          description: |||
            Kubernetes Job {{ $labels.namespace }}/{{ $labels.job_name }} did not complete in time.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesApiServerErrors',
        expr: 'sum(rate(apiserver_request_total{job="apiserver",code=~"(?:5..)"}[1m])) by (instance, job) / sum(rate(apiserver_request_total{job="apiserver"}[1m])) by (instance, job) * 100 > 3',
        'for': '2m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes API server errors (instance {{ $labels.instance }})',
          description: |||
            Kubernetes API server is experiencing high error rate
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesApiClientErrors',
        expr: '(sum(rate(rest_client_requests_total{code=~"(4|5).."}[1m])) by (instance, job) / sum(rate(rest_client_requests_total[1m])) by (instance, job)) * 100 > 1',
        'for': '2m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes API client errors (instance {{ $labels.instance }})',
          description: |||
            Kubernetes API client is experiencing high error rate
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesClientCertificateExpiresNextWeek',
        expr: 'apiserver_client_certificate_expiration_seconds_count{job="apiserver"} > 0 and histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 7*24*60*60',
        'for': '0m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes client certificate expires next week (instance {{ $labels.instance }})',
          description: |||
            A client certificate used to authenticate to the apiserver is expiring next week.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesClientCertificateExpiresSoon',
        expr: 'apiserver_client_certificate_expiration_seconds_count{job="apiserver"} > 0 and histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 24*60*60',
        'for': '0m',
        labels: {
          severity: 'critical',
        },
        annotations: {
          summary: 'Kubernetes client certificate expires soon (instance {{ $labels.instance }})',
          description: |||
            A client certificate used to authenticate to the apiserver is expiring in less than 24.0 hours.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
      {
        alert: 'KubernetesApiServerLatency',
        expr: 'histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!~"(?:CONNECT|WATCHLIST|WATCH|PROXY)"} [10m])) WITHOUT (subresource)) > 1',
        'for': '2m',
        labels: {
          severity: 'warning',
        },
        annotations: {
          summary: 'Kubernetes API server latency (instance {{ $labels.instance }})',
          description: |||
            Kubernetes API server has a 99th percentile latency of {{ $value }} seconds for {{ $labels.verb }} {{ $labels.resource }}.
              VALUE = {{ $value }}
              LABELS = {{ $labels }}
          |||,
        },
      },
    ],
  },
]
  }
}
