#!/bin/bash

#########################################################
## Bootstrap Spoke Script
##
## ./bootstrap.sh ./env-vars
#########################################################

#########################################################
## Include Global Functions
source ./templates/scripts/shared_functions.sh
source ./templates/scripts/generate_cluster_configs.sh
source ./templates/scripts/generate_sealed_secrets.sh

#########################################################
## Include variable file
echo -e "\n===== Including variable file...\n"
if [ -z "$1" ]; then
    echo "ERROR: No variable file specified!"
    echo -e "Usage: $0 ./env-vars\n"
    exit 1
fi
if [ -f "$1" ]; then
    source $1
else
    echo -e "ERROR: Variable file $1 not found!\n"
    exit 1
fi

#########################################################
## Run preflight checks
source ./templates/scripts/preflight_checks.sh

set -e

echo "oc whoami: $(oc whoami)"

#########################################################
## Generate directories
echo -e "===== Generating directories...\n"
BASE_DIR="./ztp-clusters/${DEPLOYMENT_TYPE}/${CLUSTER_NAME}"
mkdir -p ${BASE_DIR}

#########################################################
## Sealed Secrets
echo -e "===== Creating Sealed Secrets..."

echo " - Sealing Spoke Cluster Pull Secret..."
assisted_deployment_spoke_pull_secret | kubeseal \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  --format yaml \
  > ${BASE_DIR}/01_pull-secret.yaml

echo " - Sealing Ansible Tower Secret..."
assisted_deployment_ansible_tower_credential "${CLUSTER_NAME}" | kubeseal \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  --format yaml \
  > ${BASE_DIR}/09_ansible-tower_secret-cluster-ns.yaml

assisted_deployment_ansible_tower_credential "${ANSIBLE_TOWER_CREDENTIALS_NAMESPACE}" | kubeseal \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  --format yaml \
  > ${BASE_DIR}/09_ansible-tower_secret.yaml

echo " - Sealing vSphere Credentials Secret..."
assisted_deployment_vsphere_credential | kubeseal \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  --format yaml \
  > ${BASE_DIR}/10_vsphere_secret.yaml

#########################################################
## Template Infrastructure Environment Config
echo -e "\n===== Creating Cluster Configuration..."

echo " - Creating Spoke Cluster Namespace..."
assisted_deployment_spoke_namespace > ${BASE_DIR}/00_namespace.yaml

echo " - Creating Spoke Cluster AgentClusterInstall..."
assisted_deployment_spoke_agentclusterinstall > ${BASE_DIR}/02_agentclusterinstall.yaml

echo " - Creating Spoke Cluster ClusterDeployment..."
assisted_deployment_spoke_clusterdeployment > ${BASE_DIR}/03_clusterdeployment.yaml

echo " - Creating Spoke Cluster KlusterletAddonConfig..."
assisted_deployment_spoke_klusterletaddonconfig > ${BASE_DIR}/04_klusterletaddonconfig.yaml

echo " - Creating Spoke Cluster ManagedCluster..."
assisted_deployment_spoke_managedcluster > ${BASE_DIR}/05_managedcluster.yaml

echo " - Creating Spoke Cluster InfraEnv..."
assisted_deployment_spoke_infraenv > ${BASE_DIR}/07_infraenv.yaml

echo " - Creating Spoke Cluster ClusterConfig ConfigMap..."
assisted_deployment_spoke_clusterconfig_configmap > ${BASE_DIR}/08_cluster_config.yaml

echo " - Creating Spoke Cluster AnsibleJob..."
assisted_deployment_spoke_ansiblejob > ${BASE_DIR}/09_ansiblejob.yaml

echo " - Creating Spoke Cluster NMState Configs..."
case "${CLUSTER_TYPE}" in
  "sno")
    assisted_deployment_spoke_nmstate_config "$SNO_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config.yaml
    ;;
  "converged")
    assisted_deployment_spoke_nmstate_config "$NODE_ONE_NM_CONFIG" ./bin/yq  > ${BASE_DIR}/11_nmstate_config_NODE_ONE.yaml
    assisted_deployment_spoke_nmstate_config "$NODE_TWO_NM_CONFIG" ./bin/yq  > ${BASE_DIR}/11_nmstate_config_NODE_TWO.yaml
    assisted_deployment_spoke_nmstate_config "$NODE_THREE_NM_CONFIG" ./bin/yq  > ${BASE_DIR}/11_nmstate_config_NODE_THREE.yaml
    ;;
  "full")
    assisted_deployment_spoke_nmstate_config "$COMPUTE_NODE_ONE_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_COMPUTE_NODE_ONE.yaml
    assisted_deployment_spoke_nmstate_config "$COMPUTE_NODE_TWO_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_COMPUTE_NODE_TWO.yaml
    assisted_deployment_spoke_nmstate_config "$COMPUTE_NODE_THREE_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_COMPUTE_NODE_THREE.yaml

    assisted_deployment_spoke_nmstate_config "$APP_NODE_ONE_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_APP_NODE_ONE.yaml
    assisted_deployment_spoke_nmstate_config "$APP_NODE_TWO_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_APP_NODE_TWO.yaml
    assisted_deployment_spoke_nmstate_config "$APP_NODE_THREE_NM_CONFIG" ./bin/yq > ${BASE_DIR}/11_nmstate_config_APP_NODE_THREE.yaml
    ;;
  *)
    echo "ERROR: Unknown cluster type: ${CLUSTER_TYPE}"
    exit 1
    ;;
esac

#echo " - Creating Spoke Cluster ArgoCD Application..."
#assisted_deployment_spoke_argocd_application > ${BASE_DIR}/12_argocd_application.yaml

oc new-project ${CLUSTER_NAME}