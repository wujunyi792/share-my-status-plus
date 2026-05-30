{{/*
Expand the chart name.
*/}}
{{- define "share-my-status.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "share-my-status.fullname" -}}
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
Create chart label.
*/}}
{{- define "share-my-status.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "share-my-status.labels" -}}
helm.sh/chart: {{ include "share-my-status.chart" . }}
app.kubernetes.io/name: {{ include "share-my-status.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "share-my-status.backend.fullname" -}}
{{- printf "%s-backend" (include "share-my-status.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "share-my-status.frontend.fullname" -}}
{{- printf "%s-frontend" (include "share-my-status.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "share-my-status.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "share-my-status.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{- define "share-my-status.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "share-my-status.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{- define "share-my-status.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "share-my-status.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
