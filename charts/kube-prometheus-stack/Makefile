alerts: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml

dashboards: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -m manifests mixins/dashboards.jsonnet

combine:
	yq -i eval-all 'select(fileIndex==0).kube-prometheus-stack.additionalPrometheusRulesMap.alerts = select(fileIndex==1) | select(fileIndex==0)' ./values.yaml manifests/alerts.yaml
	for file in manifests/*.json; do\
		val=`cat $$file`; \
		export val=$$val \
		export baseFile=`basename $$file`; \
		yq -i '.kube-prometheus-stack.grafana.dashboards.default.[strenv(baseFile)].json = strenv(val)' values.yaml ;\
	done

all: alerts dashboards combine

get-config:
	kubectl get secret -n monitoring alertmanager-new-config -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d > old-config.yaml

seal-config:
	kubectl create secret generic alertmanager-new-config --from-file=alertmanager.yaml=old-config.yaml --dry-run=client -o yaml -n monitoring > new-config.yaml
	kubeseal -o yaml < new-config.yaml > templates/config.yaml
	rm new-config.yaml old-config.yaml
