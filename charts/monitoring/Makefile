clean:
	rm -rf manifests

alerts: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml

dashboards: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -m manifests mixins/dashboards.jsonnet

combine:
	#yq -i eval-all 'select(fileIndex==0).kube-prometheus-stack.additionalPrometheusRulesMap.alerts = select(fileIndex==1) | select(fileIndex==0)' ./values.yaml manifests/alerts.yaml
	mkdir -p manifests/dashboards
	for file in manifests/*.json; do\
		baseFile=`basename $$file .json`;\
		cmName=`sed 's/_/-/g' <<< $${baseFile}`;\
		content=`cat $${file} | gzip | base64 -w0` ;\
		content=$${content} cmName=$${cmName} yq e -n '.apiVersion = "grafana.integreatly.org/v1beta1" | .kind = "GrafanaDashboard" | .metadata.name = strenv(cmName) | .spec.instanceSelector.matchLabels.instance = "default" | .spec.gzipJson = strenv(content) | .spec.folder = ""' > manifests/dashboards/$${baseFile}-dashboard.yaml ;\
		#sed -i 's/{{\s\?\(\S\+\)\s\?}}/{{`{{\1}}`}}/g' manifests/dashboards/$${baseFile}-dashboard.yaml ;\
	done
	yq eval-all "." manifests/dashboards/*.yaml > templates/dashboards.yaml

all: clean alerts dashboards combine
