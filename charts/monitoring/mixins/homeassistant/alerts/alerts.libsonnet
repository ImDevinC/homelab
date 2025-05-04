{
  prometheusAlerts+:: {
    groups+: [{
      name: 'homeassistant',
      rules: [
        {
          alert: 'SenseEnergyMissing',
          expr: |||
            absent(homeassistant_sensor_power_w{entity=~"sensor.energy_production|sensor.energy_usage"}) > 0
          ||| % $._config,
          'for': '15m',
          labels: {
            severity: 'warning',
            app: 'sense'
          },
          annotations: {
            summary: 'Sense energy data is missing',
            description: 'Sense energy data is missing',
            runbook_url: 'https://homeassistant.imdevinc.com',
          },
        },
      ],
    }],
  },
}