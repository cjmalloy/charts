{{/*
Expand the name of the chart.
*/}}
{{- define "jasper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jasper.fullname" -}}
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
{{- define "jasper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "jasper.labels" -}}
helm.sh/chart: {{ include "jasper.chart" . }}
{{ include "jasper.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "jasper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jasper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "jasper.workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jasper.name" . }}-workload
app.kubernetes.io/instance: {{ .Release.Name }}-workload
{{- end }}
{{- define "jasper.ssh.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jasper.name" . }}-ssh
app.kubernetes.io/instance: {{ .Release.Name }}-ssh
{{- end }}
{{/*
Create the name of the SSH service account.
*/}}
{{- define "jasper.ssh.serviceAccountName" -}}
{{- printf "%s-ssh" (include "jasper.fullname" . | trunc 59 | trimSuffix "-") }}
{{- end }}
{{- define "jasper.sshController.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "%s-ssh-controller" (include "jasper.name" .) | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/instance: {{ printf "%s-ssh-controller" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "jasper.cache.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jasper.name" . }}-cache
app.kubernetes.io/instance: {{ .Release.Name }}-cache
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "jasper.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "jasper.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the built in PostgreSQL resources (StatefulSet, Service and Secret).
*/}}
{{- define "jasper.postgresql.fullname" -}}
{{- default (printf "%s-db" (include "jasper.fullname" .)) .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
PostgreSQL selector labels. These match the labels used by the Bitnami subchart previously
bundled with this chart so the existing StatefulSet can be updated in place.
*/}}
{{- define "jasper.postgresql.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: postgresql
app.kubernetes.io/component: primary
{{- end }}

{{- define "jasper.postgresql.labels" -}}
helm.sh/chart: {{ include "jasper.chart" . }}
{{ include "jasper.postgresql.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Secret and key holding the database password used by Jasper.
*/}}
{{- define "jasper.database.secretName" -}}
{{- if .Values.postgresql.enabled }}
{{- default (include "jasper.postgresql.fullname" .) .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- default (printf "%s-external-db" (include "jasper.fullname" .)) .Values.externalDatabase.existingSecret }}
{{- end }}
{{- end }}

{{- define "jasper.database.secretKey" -}}
{{- if .Values.postgresql.enabled }}
{{- default "postgres-password" .Values.postgresql.auth.secretKeys.adminPasswordKey }}
{{- else }}
{{- default "password" .Values.externalDatabase.existingSecretPasswordKey }}
{{- end }}
{{- end }}

{{/*
Datasource environment variables for Jasper containers.
*/}}
{{- define "jasper.database.env" -}}
{{- if .Values.postgresql.enabled }}
- name: SPRING_DATASOURCE_URL
  value: jdbc:postgresql://{{ include "jasper.postgresql.fullname" . }}:5432/{{ .Values.postgresql.auth.database }}
- name: SPRING_DATASOURCE_USERNAME
  value: postgres
- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "jasper.database.secretName" . }}
      key: {{ include "jasper.database.secretKey" . }}
{{- else }}
{{- with .Values.externalDatabase }}
- name: SPRING_DATASOURCE_URL
  {{- if .jdbcUrl }}
  value: {{ .jdbcUrl | quote }}
  {{- else }}
  value: {{ printf "jdbc:postgresql://%s:%v/%s" (required "externalDatabase.host or externalDatabase.jdbcUrl is required when postgresql.enabled=false" .host) .port .database | quote }}
  {{- end }}
- name: SPRING_DATASOURCE_USERNAME
  value: {{ .username | quote }}
{{- end }}
{{- if or .Values.externalDatabase.password .Values.externalDatabase.existingSecret }}
- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "jasper.database.secretName" . }}
      key: {{ include "jasper.database.secretKey" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "jasper.postgresql.env" -}}
- name: PGDATA
  value: /pgdata/data
- name: POSTGRES_USER
  value: postgres
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "jasper.database.secretName" . }}
      key: {{ include "jasper.database.secretKey" . }}
- name: POSTGRES_DB
  value: {{ .Values.postgresql.auth.database | quote }}
{{- with .Values.postgresql.initdbArgs }}
- name: POSTGRES_INITDB_ARGS
  value: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
The data volume is not mounted under /var/lib/postgresql since the postgres images declare
a VOLUME there (/var/lib/postgresql/data before 18) which would hide the data directory.
*/}}
{{- define "jasper.postgresql.volumeMounts" -}}
- name: data
  mountPath: /pgdata
- name: config
  mountPath: /etc/postgresql
- name: empty-dir
  mountPath: /tmp
  subPath: tmp
- name: empty-dir
  mountPath: /var/run/postgresql
  subPath: run
- name: dshm
  mountPath: /dev/shm
{{- end }}
