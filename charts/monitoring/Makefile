clean:
	rm -rf manifests

alerts: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -S mixins/alerts.jsonnet > manifests/$@.yaml
	echo -e "# DO NOT EDIT\n# THIS FILE IS GENERATED AUTOMATICALLY AND ANY CHANGES WILL BE OVERWRITTEN" > templates/alerts.yaml
	yq e -n '.apiVersion = "monitoring.coreos.com/v1" | .kind = "PrometheusRule" | .metadata.name = "generated-rules" | .spec = load("manifests/alerts.yaml")' >> templates/alerts.yaml
	sed -i 's/\({{\|}}\)/\1`\1/g' templates/alerts.yaml

dashboards: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -m manifests mixins/dashboards.jsonnet
	@mkdir -p manifests/dashboards
	for file in manifests/*.json; do\
		baseFile=`basename $$file .json`;\
		cmName=`sed 's/_/-/g' <<< $${baseFile}`;\
		content=`cat $${file} | gzip | base64 -w0` ;\
		content=$${content} cmName=$${cmName} yq e -n '.apiVersion = "grafana.integreatly.org/v1beta1" | .kind = "GrafanaDashboard" | .metadata.name = strenv(cmName) | .spec.instanceSelector.matchLabels.instance = "default" | .spec.gzipJson = strenv(content) | .spec.folder = ""' > manifests/dashboards/$${baseFile}-dashboard.yaml ;\
	done
	echo -e "# DO NOT EDIT\n# THIS FILE IS GENERATED AUTOMATICALLY AND ANY CHANGES WILL BE OVERWRITTEN" > templates/dashboards.yaml
	yq eval-all "." manifests/dashboards/*.yaml >> templates/dashboards.yaml

all: clean alerts dashboards
