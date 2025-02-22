// Sealed Secrets Grafana Dashboards

{
  grafanaDashboards+:: {
    'nginx-ingress.json': (import 'nginx-ingress.json'),
    'geoip.json': (import 'geoip.json')
  },
}
