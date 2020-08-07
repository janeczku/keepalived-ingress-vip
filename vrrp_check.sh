#!/bin/bash
# Name: vrrp_check.sh
# VRRP check script to perform various health checks for Kubernetes nodes

DEFAULT_TIMEOUT=5

build_kubeapi_url() {

    local path=$1
    echo "https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}${path}"
}

do_curl() {

    local url=$1
    local timeout=$2
    local token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    local headers=(-H "Authorization: bearer ${token}")
    local options=(-fksS -m ${timeout})
    local curl_args=("${options[@]}" "${headers[@]}" ${url})
    curl "${curl_args[@]}"
}

is_kubeapi_ready() {

    local url=$(build_kubeapi_url /healthz)
    do_curl "$url" "$DEFAULT_TIMEOUT"
}

is_node_ready() {

    local nodename=${NODE_NAME}
    local url=$(build_kubeapi_url /api/v1/nodes/$nodename)
    local res=$(do_curl "$url" "$DEFAULT_TIMEOUT")
    if [[ $? -ne 0 ]]; then
        echo $res
        return 1
    fi

    local ready=$(jq -r '.status.conditions[] | select(.type=="Ready") | .status' <<< "$res")
    if [[ $ready == "True" ]]; then
      return 0
    else
      echo $ready
      return 1
    fi  
}

ARG_TYPE=$1
ARG_URL=$2
ARG_TIMEOUT=${3:-$DEFAULT_TIMEOUT}

case $ARG_TYPE in
    "URL_CHECK") res=$(do_curl "$ARG_URL" "$ARG_TIMEOUT")
                 exit
                 ;;
    "API_CHECK") url=$(build_kubeapi_url /healthz)
                 res=$(do_curl "$url" "$DEFAULT_TIMEOUT")
                 exit
                 ;;
    "NODE_READY") is_node_ready
                 exit
                 ;;
    *)           echo "unknown type"
                 exit 1
                 ;;
esac
