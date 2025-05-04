// Mediaserver Grafana Dashboards

{
  grafanaDashboards+:: {
    'radarr.json': (import 'radarr.json'),
    'sonarr.json': (import 'sonarr.json')
  },
}