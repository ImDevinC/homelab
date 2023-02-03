{
  prometheusAlerts+:: {
    groups+: [{
      name: 'radarr',
      rules: [
        {
          alert: 'RadarrStatusOffline',
          expr: |||
            max_over_time(radarr_system_status[5m]) < 1
          ||| % $._config,
          'for': '5m',
          labels: {
            severity: 'warning',
            app: 'radarr'
          },
          annotations: {
            summary: 'Radarr is currently offline',
            description: 'Radarr system status is reporting as offline',
            runbook_url: 'https://github.com/imdevinc/homelab',
          },
        },
      ],
    }],
  },
}