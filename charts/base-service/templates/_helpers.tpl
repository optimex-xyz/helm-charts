{{/*
Expand the name of the chart.
*/}}
{{- define "base-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "base-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "base-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "base-service.labels" -}}
helm.sh/chart: {{ include "base-service.chart" .context }}
{{ include "base-service.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "base-service.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "base-service.name" .context }}-{{ .name }}
{{ end -}}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "base-service.serviceAccountName" -}}
{{- if .Values.server.serviceAccount.create }}
{{- default (include "base-service.fullname" .) .Values.server.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.server.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create redis name and version as used by the chart label.
*/}}
{{- define "base-service.redis.fullname" -}}
{{- printf "%s-%s" (include "base-service.fullname" .) .Values.redis.name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{/*

Create the name of the redis service account to use
*/}}
{{- define "base-service.redisServiceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (include "base-service.redis.fullname" .) .Values.redis.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create template ingress annotations
*/}}
{{- define "base-service.server.ingress.annotations" }}
kubernetes.io/ingress.class: nginx
cert-manager.io/acme-challenge-type: http01
cert-manager.io/issue-temporary-certificate: "true"
cert-manager.io/cluster-issuer: letsencrypt
{{- end }}

{{/*
Create deployment env
*/}}
{{- define "base-service.server.env" }}
{{ $ddKeys := list "DD_ENABLED" "DD_ENV" "DD_VERSION" "DD_SERVICE" "DD_AGENT_HOST" }}
{{ $otelKeys := list "OTEL_ENABLED" "OTEL_ENV" "OTEL_SERVICE_VERSION" "OTEL_SERVICE_NAME" "OTEL_AGENT_HOST" "OTEL_METRIC_AGENT_GRPC_PORT" "OTEL_METRIC_AGENT_HTTP_PORT" "OTEL_TRACE_AGENT_GRPC_PORT" "OTEL_TRACE_AGENT_HTTP_PORT" "OTEL_INSECURE" "OTEL_TRACE_SAMPLE_RATE" }}
env:
{{- range .Values.server.env }}
{{- if not (has .name $ddKeys) }}
- name: {{ .name }}
  {{- if .value }}
  value: {{ .value | quote }}
  {{- end }}
  {{- if .valueFrom }}
  valueFrom:
  {{- toYaml .valueFrom | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- if .Values.server.datadog.enabled }}
- name: DD_ENABLED
  value: "1"
- name: DD_ENV
  value: {{ .Values.server.datadog.env | default "develop" | quote }}
- name: DD_SERVICE
  value: {{ .Values.server.datadog.service | default (include "base-service.fullname" .) | quote }}
- name: DD_VERSION
  value: {{ .Values.server.datadog.version | default .Values.server.image.tag | quote }}
- name: DD_AGENT_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
{{- end }}
{{- if .Values.server.otel.enabled }}
- name: OTEL_ENABLED
  value: "true"
- name: OTEL_ENV
  value: {{ .Values.server.otel.env | default "develop" | quote }}
- name: OTEL_SERVICE_NAME
  value: {{ .Values.server.otel.service | default (include "base-service.fullname" .) | quote }}
- name: OTEL_SERVICE_VERSION
  value: {{ .Values.server.otel.version | default .Values.server.image.tag | quote }}
- name: OTEL_AGENT_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_METRIC_AGENT_GRPC_PORT
  value: "4315"
- name: OTEL_METRIC_AGENT_HTTP_PORT
  value: "4316"
- name: OTEL_TRACE_AGENT_GRPC_PORT
  value: "4317"
- name: OTEL_TRACE_AGENT_HTTP_PORT
  value: "4318"
- name: OTEL_INSECURE
  value: "true"
- name: OTEL_TRACE_SAMPLE_RATE
  value: {{ .Values.server.otel.traceSampleRate | default "0.5" | quote }}
{{- end }}
{{- end }}

{{/*
Return full container image URL
*/}}
{{- define "merged.image" }}
{{- printf "%s:%s" .repository .tag -}}
{{- end }}

{{/*
Return merged list of environment variables
*/}}
{{- define "merged.env" -}}
{{- range . }}
- name: {{ .name }}
  {{- if .value }}
  value: {{ quote .value }}
  {{- end }}
  {{- if .valueFrom }}
  valueFrom:
  {{- toYaml .valueFrom | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
