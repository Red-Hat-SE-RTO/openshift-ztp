#!/bin/bash

echo -e "===== Running preflight...\n"

echo -e "Checking for required binaries..."
source 
checkForProgramAndInstallOrExit jq jq
checkForProgramAndInstallOrExit git git

checkForProgramAndDownloadOrExit helm https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.2/kubeseal-0.17.2-linux-amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kubectl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit kustomize https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.4.1/kustomize_v4.4.1_linux_amd64.tar.gz /usr/local/bin
checkForProgramAndDownloadOrExit oc https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz /usr/local/bin
checkForArgocdcliAndDownloadOrExit argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 


# Check for ssh key 
echo -e "\nChecking for SSH Key..."
if [ ${GENERATE_SSHKEY} == "true" ]; then
  ## Check to see if the generated key exists, if not generate it
  if [ ! -f "${HOME}/.ssh/${CLUSTER_NAME}-${BASE_DOMAIN}-key" ]; then
      ssh-keygen -t rsa -b 4096 -f ${HOME}/.ssh/${CLUSTER_NAME}-${BASE_DOMAIN}-key -N ''
  fi
  ## Export the key paths of the generated key
  export SSH_PUB_KEY_PATH="${HOME}/.ssh/${CLUSTER_NAME}-${BASE_DOMAIN}-key.pub"
  export SSH_PRI_KEY_PATH="${HOME}/.ssh/${CLUSTER_NAME}-${BASE_DOMAIN}-key"
fi

# Check for pull secret
echo -e "Checking for Pull Secret..."
if [ ! -f "${PULL_SECRET_PATH}" ]; then
  echo -e "ERROR: ${PULL_SECRET_PATH} not found!\n"
  exit 1
fi
PULL_SECRET=$(cat ${PULL_SECRET_PATH})

# Check for deployment specific requirements
case $DEPLOYMENT_TYPE in
    aws)
        echo "Checking for AWS ENV Variables..."

        if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then
          echo "ERROR: AWS_ACCESS_KEY_ID not found!"
          exit 1
        fi

        if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
          echo "ERROR: AWS_SECRET_ACCESS_KEY not found!"
          exit 1
        fi
        ;;
    vsphere)
        echo "Checking for vCenter CA Certificate..."
        if [[ ! -f "${VCENTER_CA_CERT_PATH}" ]]; then
          echo "ERROR: vCenter CA Certificate not found!"
          exit 1
        fi
        ;;
    *)
        echo "ERROR: Unknown deployment type: $DEPLOYMENT_TYPE"
        exit 1
        ;;
esac

echo -e "\n===== Preflight finished!\n"