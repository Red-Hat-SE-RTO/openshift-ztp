#!/bin/bash

function assisted_deployment_spoke_agentclusterinstall() {
cat << YAML
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: '${CLUSTER_NAME}'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
spec:
  clusterDeploymentRef:
    name: '${CLUSTER_NAME}'
  imageSetRef:
    name: openshift-v${OPENSHIFT_RELEASE}
  #apiVIP: "${API_VIP}"
  #ingressVIP: "${INGRESS_VIP}"
  holdInstallation: false
  networking:
    networkType: OVNKubernetes
    #userManagedNetworking: false
    clusterNetwork:
      - cidr: "10.128.0.0/14"
        hostPrefix: 23
    serviceNetwork:
      - "172.30.0.0/16"
    machineNetwork:
      - cidr: "${MACHINE_NETWORK_CIDR}"
  provisionRequirements:
    controlPlaneAgents: 1
  sshPublicKey: "$(cat $SSH_PUB_KEY_PATH)"
YAML
}

function assisted_deployment_spoke_clusterdeployment() {
cat << YAML
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  annotations:
    agentBareMetal-agentSelector/autoSelect: "true"
  name: '${CLUSTER_NAME}'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
spec:
  baseDomain: '${BASE_DOMAIN}'
  clusterName: '${CLUSTER_NAME}'
  #controlPlaneConfig:
  #  servingCertificates: {}
  installed: false
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: '${CLUSTER_NAME}'
    version: v1beta1
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          cluster-name: '${CLUSTER_NAME}'
  pullSecretRef:
    name: assisted-deployment-pull-secret
YAML
}

function assisted_deployment_spoke_infraenv() {
cat << YAML
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: '${CLUSTER_NAME}'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
    agentclusterinstalls.extensions.hive.openshift.io/location: '${CLUSTER_LOCATION}'
    networkType: ${NODE_NETWORK_TYPE}
spec:
  agentLabels:
    agentclusterinstalls.extensions.hive.openshift.io/location: '${CLUSTER_LOCATION}'
  clusterRef:
    name: '${CLUSTER_NAME}'
    namespace: '${CLUSTER_NAME}'
  sshAuthorizedKey: "$(cat $SSH_PUB_KEY_PATH)"
  pullSecretRef:
    name: assisted-deployment-pull-secret
  #ignitionConfigOverride: '{"ignition": {"version": "3.1.0"}, "storage": {"files": [{"path": "/etc/someconfig", "contents": {"source": "data:text/plain;base64,aGVscGltdHJhcHBlZGluYXN3YWdnZXJzcGVj"}}]}}'
  nmStateConfigLabelSelector:
    matchLabels:
      cluster-name: '${CLUSTER_NAME}'
YAML
}

function assisted_deployment_spoke_managedcluster() {
cat << YAML
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: '${CLUSTER_NAME}'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
spec:
  hubAcceptsClient: true
YAML
}

function assisted_deployment_spoke_klusterletaddonconfig() {
cat << YAML
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: '${CLUSTER_NAME}'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
spec:
  clusterName: '${CLUSTER_NAME}'
  clusterNamespace: '${CLUSTER_NAME}'
  clusterLabels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
  applicationManager:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  #workManager:
  #  enabled: true
YAML
}

function assisted_deployment_spoke_namespace() {
cat << YAML
kind: Namespace
apiVersion: v1
metadata:
  name: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
YAML
}

function assisted_deployment_spoke_clusterconfig_configmap() {
cat << YAML
kind: ConfigMap 
apiVersion: v1 
metadata:
  name: '${CLUSTER_NAME}-cluster-config'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
data:
  cluster_name: '${CLUSTER_NAME}'
  cluster_provider: vsphere
  cluster_type: ${CLUSTER_TYPE}
  vsphere_datacenter: '${VCENTER_DATACENTER}'
  vsphere_cluster: '${VCENTER_CLUSTER}'
  vsphere_datastore: '${VCENTER_DATASTORE}'
  vsphere_network: '${VCENTER_NETWORK}'

  ## SNO CONFIG
  sno_disk_size: "${SNO_DISK}"
  sno_cpu_sockets: "1"
  sno_cpu_cores: "${SNO_CPU_CORES}"
  sno_memory_size: "${SNO_MEMORY}"
  sno_mac_address: "${SNO_MAC_ADDRESS}"
  
  ## CONVERGED CONFIG
  control_plane_count: "${MASTER_COUNT}"
  control_plane_disk_size: "${MASTER_HARD_DISK}"
  control_plane_cpu_sockets: "1"
  control_plane_cpu_cores: "${MASTER_CORES}"
  control_plane_memory_size: "${MASTER_MEMORY}"

  ## FULL CONFIG
  app_node_count: "${WORKER_COUNT}"
  app_node_disk_size: "${WORKER_HARD_DISK}"
  app_node_cpu_sockets: "1"
  app_node_cpu_cores: "${WORKER_CORES}"
  app_node_memory_size: "${WORKER_MEMORY}"
YAML
}

function assisted_deployment_spoke_ansiblejob() {
cat << YAML
apiVersion: tower.ansible.com/v1alpha1
kind: AnsibleJob
metadata:
  name: ${CLUSTER_NAME}-vsphere-bootstrap
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
spec:
  tower_auth_secret: ${ANSIBLE_TOWER_CREDENTIALS_NAME}
  job_template_name: deploy-to-vsphere
  extra_vars:
    vcenter_credentials_secret_namespace: ${VSPHERE_CREDENTIALS_NAMESPACE}
    vcenter_credentials_secret_name: ${VSPHERE_CREDENTIALS_NAME}

    infraenv_namespace: ${CLUSTER_NAME}
    infraenv_name: ${CLUSTER_NAME}

    cluster_configmap_namespace: ${CLUSTER_NAME}
    cluster_configmap_name: ${CLUSTER_NAME}-cluster-config
YAML
}

function assisted_deployment_spoke_nmstate_config() {
  #VMWare ESXi OIU is 00-0C-29
cat << YAML
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
  name: '${CLUSTER_NAME}-$(echo "$1" | $2 eval '.hostname' -P -)'
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
    hostname: $(echo "$1" | $2 eval '.hostname' -P -)
$(echo "$1" | $2 eval 'del(.hostname)' -P -)
YAML
}
