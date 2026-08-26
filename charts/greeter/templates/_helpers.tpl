{{/*
Chart name.
*/}}
{{- define "greeter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified application name.
*/}}
{{- define "greeter.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "greeter.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "greeter.labels" -}}
app.kubernetes.io/name: {{ include "greeter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "greeter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "greeter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
