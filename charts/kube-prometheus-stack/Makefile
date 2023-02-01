alerts: mixins/mixin.libsonnet mixins/alerts/*.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml

combine:
	yq -i eval-all 'select(fileIndex==0).kube-prometheus-stack.additionalPrometheusRulesMap.alerts = select(fileIndex==1) | select(fileIndex==0)' ./values.yaml manifests/alerts.yaml