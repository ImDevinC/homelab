// Sealed Secrets Grafana Dashboards

{
  grafanaDashboards+:: {
    'nginx-ingress.json': (import 'nginx-ingress.json'),
  },
}
