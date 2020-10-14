{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Name of the service account to use
*/}}
{{- define "app.serviceAccountName" -}}
    {{ default (include "app.fullname" .) .Values.serviceAccountName }}
{{- end -}}



{{/*
Define a set of required configuration environment variables to be
shared across daemonset and deployment pod specs
*/}}
{{- define "environmentvars" -}}
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: AUTH_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "app.fullname" . }}
      key: password
- name: VRRP_IFACE
  value: {{ .Values.keepalived.vrrpInterfaceName | quote }}
- name: VIP_IFACE
  value: {{ .Values.keepalived.vipInterfaceName | quote  }}
- name: VIP_ADDR_CIDR
  value: {{ .Values.keepalived.vipAddressCidr | quote }}
- name: VIRTUAL_ROUTER_ID
  value: {{ .Values.keepalived.virtualRouterId | quote  }}
- name: VRRP_NOPREEMPT
  value: {{ .Values.keepalived.vrrpNoPreempt | quote }}
- name: CHECK_SERVICE_URL
  value: {{ .Values.keepalived.checkServiceUrl | quote }}
- name: CHECK_SERVICE_INTERVAL
  value: {{ .Values.keepalived.checkServiceInterval | quote }}
- name: CHECK_SERVICE_FAILAFTER
  value: {{ .Values.keepalived.checkServiceFailAfter | quote }}
- name: CHECK_KUBELET
  value: {{ .Values.keepalived.checkKubelet | quote }}
- name: CHECK_KUBELET_INTERVAL
  value: {{ .Values.keepalived.checkKubeletInterval | quote }}
- name: CHECK_KUBELET_FAILAFTER
  value: {{ .Values.keepalived.checkKubeletFailAfter | quote }}
- name: CHECK_KUBELET_URL
  value: {{ .Values.keepalived.checkKubeletUrl | quote }}
- name: CHECK_KUBEAPI
  value: {{ .Values.keepalived.checkKubeApi | quote }}
- name: CHECK_KUBEAPI_INTERVAL
  value: {{ .Values.keepalived.checkKubeApiInterval | quote }}
- name: CHECK_KUBEAPI_FAILAFTER
  value: {{ .Values.keepalived.checkKubeApiFailAfter | quote }}
{{- if .Values.pod.extraEnv }}
{{ toYaml .Values.pod.extraEnv }}
{{- end }}
{{- end }}

{{/*
Generate the pod tolerations
*/}}
{{- define "tolerations" -}}
{{- if .Values.pod.tolerations -}}
{{ toYaml .Values.pod.tolerations }}
{{ end }}
{{- if .Values.pod.tolerateMasterTaints -}}
- key: "node-role.kubernetes.io/controlplane"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
- key: "node-role.kubernetes.io/etcd"
  operator: "Equal"
  value: "true"
  effect: "NoExecute"
{{- end -}}
{{- end -}}
