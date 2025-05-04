// Mediaserver Grafana Dashboards

{
  grafanaDashboards+:: {
    'metrics.json': (import 'metrics.json')
  },
}