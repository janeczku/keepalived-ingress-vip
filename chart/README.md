# Keepalived Ingress VIP

![Hero Banner](https://raw.githubusercontent.com/janeczku/keepalived-ingress-vip/master/img/banner-top.png)

This is a lightweight HA/IP failover solution that provides floating IP addresses (VIPs) for external access to public-facing services running on Kubernetes nodes, such as Ingress controllers or the Kubernetes API servers.

It's especially suited for situations where Kubernetes clusters are deployed in infrastructure that lacks (managed) load balancers, such as in on-premise data centers or edge.

The solution is deployed as Helm application and provides sub-second L2 failover for typical failure scenarios such as nodes crashing or worker nodes becoming network partitioned from the Kubernetes control plane.

The Virtual IP is managed using the [Virtual Router Redundancy Protocol (VRRP) implementation of Keepalived](https://keepalived.readthedocs.io/en/latest/case_study_failover.html) and - instead of relying on Kubernetes API state (which would be to slow for this purpose) - the eligibility of a node to host the VIP is determined by running probes against local and remote HTTP health check endpoints (e.g. NGINX Ingress Controller, Kubelet, K8s API server).

## Prerequisites

- Network infrastructure must permit the use of VRRP protocol and multicast traffic (which is a no for most public clouds)
- Tested on a vSphere 6.7u3 environment with stock vSwitch and port group setup. Other non-cloud infrastructure providers should work.
- The Chart included in the repo requires Helm >= v3.1

### Installing the Chart using Rancher

In the Rancher GUI, navigate to __Cluster->System Project->Tools->Catalog__ and click on __Add Catalog__:

- Name: <Some Name>
- Catalog URL: `https://github.com/janeczku/keepalived-ingress-vip`
- Helm Version: `Helm v3`

Afterwards, you can launch the chart from the System project's __Apps__ page providing the configuration variables documented below.

### Installing the Chart using Helm CLI

Using the Helm CLI you must specify the required configuration options using `--set <variable>=<value>`.

```bash
$ helm install keepalived-ingress-vip ./chart -n vip \
  --set keepalived.vrrpInterfaceName=ens160 \
  --set keepalived.vipInterfaceName=ens160 \
  --set keepalived.vipAddressCidr="172.16.135.2/21"
```

### Uninstalling the Chart using Helm CLI

To uninstall the `keepalived-ingress-vip` deployment:

```bash
$ helm delete -n vip keepalived-ingress-vip
```

### Example Configurations

#### Provision a VIP as a high available endpoint for cluster ingress (e.g. NGINX Ingress Controller)

Example Helm values.yaml:

```yaml
keepalived:
  # interface used for the VRRP protocol
  vrrpInterfaceName: eth9
  # interface to attach the VIP to
  vipInterfaceName: eth0
  # The floating IP address in CIDR format
  vipAddressCidr: "172.16.135.2/21"
  
  # NGiNX Ingress Controller health check endpoint   
  checkServiceUrl: http://127.0.0.1:10254/healthz
  # If the Kubelet is down, the node will be marked as failed and VIP
  # moved to a healthy node immediately
  checkKubelet: true
  # If the Kubernetes API can't be reached from the node, the node's
  # priority for hosting the VIP will be reduced
  checkKubeApi: true 
  # optional: Tolerate an unhealthy Kubelet for up to 30 seconds
  # (e.g. to prevent VIP flapping during a planned K8s upgrade)
  checkKubeletInterval=3
  checkKubeletFailAfter=10

# optional: If the ingress controller is running on designated nodes only,
# make sure the VIP is scheduled to the same set of nodes
pod:
  nodeSelector:
    nodeRole: ingress
```

#### Provision a VIP as a high available K8s API endpoint for a multi-master cluster

Example Helm values.yaml:

```yaml
keepalived:
  # interface used for the VRRP protocol
  vrrpInterfaceName: eth0
  # interface to attach the VIP to
  vipInterfaceName: eth0
  # The floating IP address in CIDR format
  vipAddressCidr: "172.16.135.2/21"
  
  # Health check the local K8s API service (URL might vary depending on k8s distro)
  checkServiceUrl: http://127.0.0.1:6443/healthz
  checkKubelet: false
  checkKubeApi: false

# Daemonset is used because we always want a Keepalived instance on every master node
kind: Daemonset

pod:
  # Ensure that the VIP is only scheduled on master nodes
  nodeSelector:
    node-role.kubernetes.io/controlplane: "true"
  # Tolerate master taints 
  tolerateMasterTaints: true
```

#### Provide a VIP as an high available API endpoint for k3s clusters

You can package a Helm resource file with k3s that will automatically attach a floating IP to a healthy master during cluster bootstrapping.

Create the file `/var/lib/rancher/k3s/server/manifests/keepalived-api-vip.yaml` on the k3s server host:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: keepalived-ingress-vip
  namespace: kube-system
spec:
  chart: keepalived-ingress-vip
  version: 0.1.4
  repo: https://janeczku.github.io/helm-charts/
  targetNamespace: keepalived
  valuesContent: |-
    keepalived:
      # interface used for the VRRP protocol
      vrrpInterfaceName: ens160
      # interface to attach the VIP to
      vipInterfaceName: ens160
      # The floating IP address in CIDR format
      vipAddressCidr: "172.16.135.2/21"
      # Health check the local K3s API endpoint
      checkServiceUrl: http://127.0.0.1:6443/healthz
      checkKubelet: false
      checkKubeApi: false
    # Daemonset is used because we always want a Keepalived instance on every master node
    kind: Daemonset
    pod:
      # Schedule the VIP only to master nodes
      nodeSelector:
        node-role.kubernetes.io/controlplane: "true"
      # Tolerate master taints 
      tolerateMasterTaints: true
````

Once the k3s cluster is bootstrapped you can point your Kubernetes client to: `https://VIP:6443`.


### Configuration Reference

The following table lists the configurable parameters of this chart and their default values.

| Parameter                           | Description                                                      | Default                                             |
| ----------------------------------- | -----------------------------------------------------------------| --------------------------------------------------- |
| `keepalived.debug`                  | Enable verbose logging                                           | `false`                                             |
| `keepalived.authPassword`.          | Shared VRRP authentication key (1-8 chars)                       | _autogenerated_                                     |
| `keepalived.vrrpInterfaceName`      | The host network interface name to use for VRRP traffic.         | `eth0`                                              |
| `keepalived.vipInterfaceName`       | The host network interface name to attach the VIP to.            | `eth0`                                              |
| `keepalived.vipAddressCidr`         | The Virtual IP address to use (in CIDR notation, e.g. `192.168.11.2/24`) | ``                                          |
| `keepalived.virtualRouterId`        | A unique numeric Keepalived Router ID.                           | `10`                                                |
| `keepalived.vrrpNoPreempt`          | Enable the Keepalived "nopreempt" option                         | `false`                                             |
| `keepalived.checkServiceUrl`        | URL checked to determine availability of the service endpoint provided on the local node (expects HTTP status code 200) | `http://127.0.0.1:10254/healthz` (NGINX Ingress Controller) |
| `keepalived.checkServiceInterval`   | Interval for the service health check in seconds                 | `2`                                                 |
| `keepalived.checkServiceFailAfter`  | Number of failed service checks to allow before marking this Keepalived instance failed | `2`                          |
| `keepalived.checkKubelet`           | Remove VIP from Keepalived instance running on node with unhealthy Kubelet | `true`                                    |
| `keepalived.checkKubeletInterval`   | Interval for Kubelet health checks in seconds                    | `5`                                                 |
| `keepalived.checkKubeletFailAfter`  | Number of failed Kubelet health checks before marking this Keepalived instance failed | `5`                            |
| `keepalived.checkKubeletUrl`        | The URL checked to determine health of the local node Kubelet | `http://127.0.0.1:10248/healthz`                       |
| `keepalived.checkKubeApi`           | Reduce priority of a Keepalived instance running on a node that fails to communicate with the K8s API server | `true`  |
| `keepalived.checkKubeApiInterval`   | Interval for K8s API health checks in seconds                    | `5`                                                 |
| `keepalived.checkKubeApiFailAfter`  | Number of failed K8s API health checks before reducing priority of the keepalived instance (VIP may then be moved to a higher priority instance) | `5` |
| `kind`                              | The deployment resource to create for the Keepalived pods (one of 'Deployment' or 'Daemonset') | `Deployment`          |
| `image.repository`                  | Image repository to pull from                                    | `janeczku/keepalived-ingress-vip`                   |
| `image.tag`                         | Image tag to pull                                                | `v0.1.4`                                            |
| `image.pullPolicy`                  | Image pull policy                                                | `IfNotPresent`                                      |
| `rbac.create`                       | Whether to create the required RBAC resources                    | `true`                                              |
| `rbac.pspEnabled`                   | Whether to create the required PodSecurityPolicy                 | `false`                                             |
| `serviceAccount.name`               | Use an existing service account instead of creating a new one.   | ``                                                  |
| `pod.replicas`                      | The number of Keepalived instances to run in the cluster         | `2`                                                 |
| `pod.priorityClassName`             | The priority class to assign the pods to                         | `system-cluster-critical`                           |
| `pod.extraEnv`                      | Additional pod environment variables                             | `[]`                                                |
| `pod.resources.requests.cpu`        | CPU resource requests                                            | 80m                                                 |
| `pod.resources.limits.cpu`          | CPU resource limits                                              |                                                     |
| `pod.resources.requests.memory`     | Memory resource requests                                         | 6Mi                                                 |
| `pod.resources.limits.memory`       | Memory resource limits                                           | 12Mi                                                |
| `pod.nodeSelector`                  | Node selector                                                    | `{}`                                                |
| `pod.tolerations`                   | Custom pod taint tolerations                                     | see below for the default                           |
| `pod.tolerateMasterTaints`          | Configure taint tolerations that allows pods to run on master nodes | `false`                                          |
| `pod.affinity`                      | Additional pod affinity configuration                            | `{}`                                                |
| `pod.imagePullSecrets`              | Array of image Pull Secrets                                      | `[]`                                                |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

#### Default Pod Taint Tolerations

By default the following tolerations are set by the Helm chart. You may use the `pod.tolerations` variable to override the default.

```
  tolerations:
  # If the the node becomes tainted as unreachable or not-ready one would typically want
  # the Keepalived instance to be migrated to healthy node without much delay.
  # Setting the tolerationSeconds value too low might cause the VIP to be evicted during a
  # scheduled upgrade of the Kubelet (which might be the desired behaviour in most cases anyways).
  - key: "node.kubernetes.io/unreachable"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 15
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 15
```