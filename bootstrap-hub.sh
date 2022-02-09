#!/bin/bash

## Set the OCP_VERSION for the short x.y version string
OCP_VERSION="4.9"
PULL_SECRET_PATH="$HOME/rh-ocp-pull-secret.json"

DEPLOY_AAP_CONTROLLER="true" # This is "Tower"
DEPLOY_AAP_HUB="false" # This is the AAP that's hosted on RHHC
DEPLOY_GITEA="true"
DEPLOY_NFD="true"
DEPLOY_ARGO_CD="true"
DEPLOY_SEALED_SECRETS="true"

LOG_FILE="/tmp/bootstrap-hub-$(date '+%s').log"
PROMPT_FOR_ODF_CHECK="true"

echo -e "\n===== Logging to ${LOG_FILE}"

function logHeader() {
  echo -e "\n======================================================================"
  echo "| ${1}"
  echo -e "======================================================================\n"
}

function promptToContinue {
  echo -e "\n======================================================================"
  read -p "${1} [N/y] " -n 1 -r

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "======================================================================\n"
    echo "Continuing..."
  else
    promptToContinue "${1}"
  fi
}

function checkForODFConsolePlugin() {
  STORAGE_CLASS_QUERY=$(oc get consoleplugin/odf-console)
  if [ $? -ne 0 ]; then
    echo -e " - ODF ConsolePlugin not found, waiting 30s..." 2>&1 | tee -a $LOG_FILE
    sleep 30
    checkForODFConsolePlugin
  fi
}

function checkForCephFS() {
  STORAGE_CLASS_QUERY=$(oc get storageclass/ocs-storagecluster-cephfs)
  if [ $? -ne 0 ]; then
    echo -e " - CephFS StorageClass not found, waiting 30s..." 2>&1 | tee -a $LOG_FILE
    sleep 30
    checkForCephFS
  else
    echo -e " - CephFS StorageClass found, labeling as default StorageClass..." 2>&1 | tee -a $LOG_FILE
    oc annotate --overwrite storageclass/ocs-storagecluster-cephfs storageclass.kubernetes.io/is-default-class="true" &>> $LOG_FILE
  fi
}

####################################################
## Preflight
source templates/scripts/shared_functions.sh

checkForProgramAndInstallOrExit jq jq
checkForProgramAndInstallOrExit git git

checkForProgramAndDownloadOrExit helm https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.2/kubeseal-0.17.2-linux-amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kubectl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kustomize https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.4.1/kustomize_v4.4.1_linux_amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit oc https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz /usr/local/bin

## Check for the OCP Pull Secret
if [ ! -f "$PULL_SECRET_PATH" ]; then
  echo -e " - Pull secret not found!" 2>&1 | tee -a $LOG_FILE
  exit 1
fi

## Check for the Bitname Sealed Secret Helm Repo
if [ "$DEPLOY_SEALED_SECRETS" == "true" ]; then
  if [ -z "$(helm repo list | grep sealed-secrets)" ]; then
    echo -e " - Installing Bitname Sealed Secret Helm Repo..." 2>&1 | tee -a $LOG_FILE
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets &>> $LOG_FILE
    helm repo update &>> $LOG_FILE
  fi
  HELM_SEALED_SECRETS_STATUS=$(helm status sealed-secrets -n kube-system)
  if [ $? -ne 0 ]; then
    echo -e " - Deploying Sealed Secrets to OCP..." 2>&1 | tee -a $LOG_FILE
    helm install sealed-secrets --namespace kube-system --version 2.1.0 sealed-secrets/sealed-secrets &>> $LOG_FILE
  fi
fi

####################################################
## Install needed Operator Catalogs
logHeader "Installing Operator Catalogs" 2>&1 | tee -a $LOG_FILE
oc apply -f hub-applications/${OCP_VERSION}/operator-catalogs/ &>> $LOG_FILE

## Wait for the Operator Catalog to come online
until oc get packagemanifest gitea-operator -n openshift-marketplace; do echo "Waiting for PackageManifests...sleeping 10s..." && sleep 10; done

####################################################
## Label worker nodes as ODF Hosts
logHeader "Labeling worker nodes as ODF Hosts" 2>&1 | tee -a $LOG_FILE
WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker -o name)

echo "$WORKER_NODES" | while read line 
do
  echo -e " - Adding openshift-storage label to $line..." 2>&1 | tee -a $LOG_FILE
  oc label --overwrite $line cluster.ocs.openshift.io/openshift-storage="" &>> $LOG_FILE
done

####################################################
## Create Namespaces and Operator Subscriptions
logHeader "Creating Operator Namespaces and Operator Subscriptions" 2>&1 | tee -a $LOG_FILE
echo -e " - LSO Operator..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/local-storage-operator/ &>> $LOG_FILE
echo -e " - ODF Operator..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/odf-operator/ &>> $LOG_FILE
echo -e " - RHACM Operator..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/rhacm-operator/ &>> $LOG_FILE
echo -e " - Ansible Automation Platform 2 Operator..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/aap-operator/ &>> $LOG_FILE

if [ "$DEPLOY_NFD" == "true" ]; then
  echo -e " - NFD Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/nfd-operator/ &>> $LOG_FILE
fi

if [ "$DEPLOY_GITEA" == "true" ]; then
  echo -e " - Gitea Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/gitea-operator/ &>> $LOG_FILE
fi

if [ "$DEPLOY_ARGO_CD" == "true" ]; then
  echo -e " - ArgoCD Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/argocd-operator/ &>> $LOG_FILE
fi

####################################################
## Enable ODF ConsolePlugin
logHeader "Patching the Console to enable the ODF Console Plugin" 2>&1 | tee -a $LOG_FILE
checkForODFConsolePlugin
oc patch console.v1.operator.openshift.io/cluster --type='json' -p='[{"op": "add", "path": "/spec/plugins", "value": "[]" }]' &>> $LOG_FILE
oc patch console.v1.operator.openshift.io/cluster --type='json' -p='[{"op": "add", "path": "/spec/plugins", "value": ["odf-console"] }]' &>> $LOG_FILE

####################################################
## Prompt to make sure the operator has deployed the ODF StorageSystem since that is different on any platform
if [ "$PROMPT_FOR_ODF_CHECK" == "true" ]; then
  promptToContinue "Before continuing, create a StorageSystem in OpenShift Data Foundation - has this been done?"
fi

####################################################
## Query for the CephFS StorageClass anyway
logHeader "Querying for the CephFS StorageClass" 2>&1 | tee -a $LOG_FILE
checkForCephFS

####################################################
## Create the Operator Instances/Operands
logHeader "Creating Operator Instances/Operands" 2>&1 | tee -a $LOG_FILE
echo -e " - RHACM Operator..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/rhacm-operator/ &>> $LOG_FILE

if [ "$DEPLOY_NFD" == "true" ]; then
  echo -e " - NFD Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/nfd-operator/ &>> $LOG_FILE
fi

if [ "$DEPLOY_AAP_HUB" == "true" ]; then
  echo -e " - Ansible Automation Platform 2 Hub..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/aap-operator/02_hub_instance.yml &>> $LOG_FILE
fi

if [ "$DEPLOY_AAP_CONTROLLER" == "true" ]; then
  echo -e " - Ansible Automation Platform 2 Controller/Tower..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/aap-operator/03_tower_controller_instance.yml &>> $LOG_FILE
fi

if [ "$DEPLOY_GITEA" == "true" ]; then
  echo -e " - Gitea Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/gitea-operator/ &>> $LOG_FILE
fi

if [ "$DEPLOY_ARGO_CD" == "true" ]; then
  echo -e " - ArgoCD Operator..." 2>&1 | tee -a $LOG_FILE
  oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/argocd-operator/ &>> $LOG_FILE
fi

####################################################
## Create a Pull Secret Secret for OAS
logHeader "Configuring RHACM for OAS ZTP" 2>&1 | tee -a $LOG_FILE
echo -e " - Creating Pull Secret, Secret..." 2>&1 | tee -a $LOG_FILE
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: assisted-deployment-pull-secret
  namespace: open-cluster-management
stringData:
  .dockerconfigjson: '$(cat $PULL_SECRET_PATH)'
  type: kubernetes.io/dockerconfigjson
EOF

####################################################
## Deploy the Hub ACM Configuration
echo -e " - Configuring OAS..." 2>&1 | tee -a $LOG_FILE
oc apply -f ./hub-applications/${OCP_VERSION}/hub-acm-config/ &>> $LOG_FILE

####################################################
## Finished!
####################################################
logHeader "FINISHED!" 2>&1 | tee -a $LOG_FILE
echo -e "\n===== Log saved to ${LOG_FILE}\n"

echo "Next steps:"
echo ""
echo "===== Ansible Automation Platform 2 Setup"
echo " - Get the AAP Tower Admin Password:"
echo "oc get secret/ac-tower-admin-password -n ansible-automation-platform -o jsonpath='{.data.password}' | echo \"\$(base64 -d)\""
echo ""
echo " - Get the AAP Tower Route:"
echo "echo \"https://\$(oc get -n ansible-automation-platform route/ac-tower -o jsonpath='{.spec.host}')\""
echo ""
echo " - Attach a Subscription to Ansible Controller Tower"
echo " - Create an Application in Ansible Controller Tower, 'Resource owner password-based' Authorization grant type, 'Confidential' Client type"
echo " - Create a User Personal Access Token with that Application in Ansible Controller Tower"
echo " - Create SCM Credentials to access the Git repo in Ansible Controller Tower"
echo " - Create a Project in Ansible Controller Tower"
echo " - Create an Inventory in Ansible Controller Tower, localhost being the only host with explicit locality via ansible_connection=local"
echo " - Create a Job Template in Ansible Controller Tower, allow for extra variables to be passed in"
echo ""
echo "===== Red Hat Advanced Cluster Management Setup"
echo " - Create a Credential in RHACM for Ansible Controller Tower, in the open-cluster-management namespace"
echo " - Create Automation Ansible Template in RHACM"
echo ""
echo "===== Run the Spoke Bootstrap Script"
echo ""