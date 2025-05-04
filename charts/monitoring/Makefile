clean:
	rm -rf manifests

alerts: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml

dashboards: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -m manifests mixins/dashboards.jsonnet

combine:
#	yq -i eval-all 'select(fileIndex==0).kube-prometheus-stack.additionalPrometheusRulesMap.alerts = select(fileIndex==1) | select(fileIndex==0)' ./values.yaml manifests/alerts.yaml
	mkdir -p manifests/dashboards
	for file in manifests/*.json; do\
		baseFile=`basename $$file .json`;\
		cmName=`sed 's/_/-/g' <<< $${baseFile}`;\
		kubectl create configmap -n monitoring $${cmName}-dashboard --dry-run=client --from-file="manifests/$${baseFile}.json" -o yaml > manifests/dashboards/$${baseFile}-dashboard-cm.yaml ;\
		yq -i '.metadata.labels.grafana_dashboard = "1"' manifests/dashboards/$${baseFile}-dashboard-cm.yaml ;\
		sed -i 's/{{\s\?\(\S\+\)\s\?}}/{{`{{\1}}`}}/g' manifests/dashboards/$${baseFile}-dashboard-cm.yaml ;\
	done
	yq eval-all "." manifests/dashboards/*.yaml > templates/dashboards.yaml

all: clean alerts dashboards combine
