{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "homeassistant.name" -}}
{{- default .Chart.Name | trunc 63 }}
{{- end }}

{{/*
Create chart name and version as used by the chart label
*/}}
{{- define "homeassistant.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "homeassistant.labels" -}}
helm.sh/chart: {{ include "homeassistant.chart" . }}
{{ include "homeassistant.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "homeassistant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homeassistant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}