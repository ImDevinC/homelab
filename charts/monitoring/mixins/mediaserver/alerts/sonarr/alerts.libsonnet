{
  prometheusAlerts+:: {
    groups+: [{
      name: 'sonarr',
      rules: [
        {
          alert: 'SonarrStatusOffline',
          expr: |||
            max_over_time(sonarr_system_status[5m]) < 1
          ||| % $._config,
          'for': '5m',
          labels: {
            severity: 'warning',
            app: 'sonarr'
          },
          annotations: {
            summary: 'Sonarr is currently offline',
            description: 'Sonarr system status is reporting as offline',
            runbook_url: 'https://github.com/imdevinc/homelab',
          },
        },
        {
          alert: 'SonarrDownloadWarning',
          expr: |||
            max_over_time(sonarr_queue_total{download_status="warning"}[5m]) > 0
          ||| % $._config,
          'for': '5m',
          labels: {
            severity: 'warning',
            app: 'sonarr'
          },
          annotations: {
            summary: 'Sonarr is having an issue downloading',
            description: 'There is a warning with one of the downloads in Sonarr',
            runbook_url: 'https://github.com/imdevinc/homelab',
          },
        }
      ],
    }],
  },
}