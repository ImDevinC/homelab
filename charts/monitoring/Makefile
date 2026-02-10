clean:
	rm -rf manifests

alerts: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -S opentelemetry-operator/alerts.jsonnet > manifests/$@.yaml
	echo -e "# DO NOT EDIT\n# THIS FILE IS GENERATED AUTOMATICALLY AND ANY CHANGES WILL BE OVERWRITTEN" > opentelemetry-operator/alerts.yaml
	yq e -n '.apiVersion = "monitoring.coreos.com/v1" | .kind = "PrometheusRule" | .metadata.name = "generated-rules" | .spec = load("manifests/alerts.yaml")' >> opentelemetry-operator/alerts.yaml
	sed -i 's/\({{\|}}\)/\1`\1/g' opentelemetry-operator/alerts.yaml

dashboards: mixins/mixin.libsonnet
	@mkdir -p manifests
	jsonnet -m manifests mixins/dashboards.jsonnet
	@mkdir -p manifests/dashboards
	for file in manifests/*.json; do\
		baseFile=`basename $$file .json`;\
		cmName=`sed 's/_/-/g' <<< $${baseFile}`;\
		content=`cat $${file} | gzip | base64 -w0` ;\
		content=$${content} cmName=$${cmName} yq e -n '.apiVersion = "grafana.integreatly.org/v1beta1" | .kind = "GrafanaDashboard" | .metadata.name = strenv(cmName) | .spec.instanceSelector.matchLabels.instance = "default" | .spec.gzipJson = strenv(content) | .spec.folder = "General"' > manifests/dashboards/$${baseFile}-dashboard.yaml ;\
	done
	echo -e "# DO NOT EDIT\n# THIS FILE IS GENERATED AUTOMATICALLY AND ANY CHANGES WILL BE OVERWRITTEN" > grafana-operator/dashboards.yaml
	yq eval-all "." manifests/dashboards/*.yaml >> grafana-operator/dashboards.yaml

all: clean alerts dashboards
