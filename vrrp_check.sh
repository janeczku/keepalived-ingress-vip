#!/bin/bash
# Name: vrrp_check.sh
# VRRP check script to perform various health checks for Kubernetes nodes

is_url_healthy() {

    local url=$1
    local res=$(curl -o /dev/null -m 2 -IsSw '%{http_code}' $url)
    if [[ $res -eq 200 ]]; then
      return 0
    else
      return 1
    fi
}

is_node_ready() {

    local nodename=$1
    local token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    local host=$KUBERNETES_SERVICE_HOST
    local port=$KUBERNETES_SERVICE_PORT
    local res=$(curl -sSk -m 5 --header "Authorization: Bearer ${token}" https://${host}:${port}/api/v1/nodes/${nodename} | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
    if [[ $res == "True" ]]; then
      return 0
    else
      return 1
    fi  
}

TYPE=$1
ARG1=$2

case $TYPE in
    "HEALTHZ")   is_url_healthy $ARG1
                 exit
                 ;;
    "NODEREADY") is_node_ready $ARG1
                 exit
                 ;;
    *)           echo "unknown type"
                 exit 1
                 ;;
esac