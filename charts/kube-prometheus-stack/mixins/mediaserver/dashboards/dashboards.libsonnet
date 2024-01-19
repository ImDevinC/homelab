// Mediaserver Grafana Dashboards

{
  grafanaDashboards+:: {
    'radarr.json': (import 'radarr.json'),
    'sonarr.json': (import 'sonarr.json'),
    'power.json': (import 'power.json'),
  },
}