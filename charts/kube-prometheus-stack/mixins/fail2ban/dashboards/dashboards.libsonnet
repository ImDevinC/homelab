// Mediaserver Grafana Dashboards

{
  grafanaDashboards+:: {
    'fail2ban.json': (import 'fail2ban.json')
  },
}
