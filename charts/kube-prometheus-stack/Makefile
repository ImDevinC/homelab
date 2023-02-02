alerts: mixins/mixin.libsonnet mixins/alerts/*.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml

dashboards: mixins/mixin.libsonnet mixins/dashboards/*.libsonnet
	@mkdir -p manifests
	jsonnet -m mixins/dashboards.jsonnet

combine:
	yq -i eval-all 'select(fileIndex==0).kube-prometheus-stack.additionalPrometheusRulesMap.alerts = select(fileIndex==1) | select(fileIndex==0)' ./values.yaml manifests/alerts.yaml
	for file in manifests/*.json; do\
		val=`cat $$file`; \
		export val=$$val \
		export baseFile=`basename $$file`; \
		yq -i '.kube-prometheus-stack.grafana.dashboards.default.[strenv(baseFile)].json = strenv(val)' values.yaml ;\
	done