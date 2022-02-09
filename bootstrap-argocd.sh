#!/bin/bash


source templates/scripts/shared_functions.sh

checkForArgocdcliAndDownloadOrExit argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 

## Login to OpenShift with a cluster-admin user
OCP_VERSION="4.9"

## Specify an SSH Private Key to use to log into the Git repo
SSH_PRIVATE_KEY_PATH=${SSH_PRIVATE_KEY_PATH:="$HOME/.ssh/MasterKemoKey"}

## Define the Git repo information
GIT_REPO=${GIT_REPO:="git@github.com:kenmoini/openshift-ztp.git"}\

## Skip Git validation for https repos 
SKIP_INSECURE=false

ARGOCD_PROJECT_NAME="ztp"
ARGOCD_CLUSTER_ACCESS="true"

###############################################################################
CHECK_ARGO_CRD=$( oc get crd | grep argoproj.io | wc -l)
if [[ $CHECK_ARGO_CRD -eq 5 ]] ; then
  echo "ArgoCD Operator is installed and ready!"
else
    ## Create the argocd Namespace and Install the ArgoCD
    echo "Creating ArgoCD Namespace and Installing Operator..."
    oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/argocd-operator/

    ## Wait for the ArgoCD Operator to be ready
    until [ "$(oc get subscription.v1alpha1.operators.coreos.com argocd-operator -n openshift-operators -o jsonpath='{.status.state}')" == "AtLatestKnown" ]; do
    echo "- Waiting for ArgoCD Operator to be ready..."
    sleep 5
    done

    echo "ArgoCD Operator is installed and ready!"

    ###############################################################################
    ## Create the argocd Namespace and Install the ArgoCD
    echo "Creating ArgoCD Instance..."
    oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/argocd-operator/

fi

###############################################################################
## Create an ArgoCD Project via the oc CLI
echo "Creating ArgoCD Project..."
cat << YAML | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  creationTimestamp: null
  name: ${ARGOCD_PROJECT_NAME}
  namespace: argocd
spec:
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  destinations:
    - namespace: '*'
      server: '*'
  sourceRepos:
    - '*'
YAML

if [[ "$GIT_REPO" == *"@"* ]]; then
###############################################################################
## Create an ArgoCD Credential via the oc CLI
GIT_REPO_NAME=$(echo $GIT_REPO | cut -d '/' -f2 | sed 's/.git$//')
echo "Creating ArgoCD Git Credential... for ${GIT_REPO}"
cat << YAML | oc apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: repo-${GIT_REPO_NAME}
  namespace: argocd
  creationTimestamp: null
  labels:
    argocd.argoproj.io/secret-type: repository
  annotations:
    managed-by: argocd.argoproj.io
stringData:
  name: ${GIT_REPO_NAME}
  project: ${ARGOCD_PROJECT_NAME}
  sshPrivateKey: |
$(cat $SSH_PRIVATE_KEY_PATH | awk '{printf "      %s\n", $0}')
  type: git
  insecure: "true"
  url: ${GIT_REPO}
type: Opaque
YAML
else 
  echo "Creating ArgoCD Git Credential... for ${GIT_REPO}"
  GIT_REPO_NAME=$(echo $GIT_REPO | cut -d '/' -f5 | sed 's/.git$//')
  login-to-argocd
  if [ $SKIP_INSECURE == true ];
  then 
    argocd repo add --insecure-skip-server-verification ${GIT_REPO}
  else
    argocd repo add ${GIT_REPO}
  fi 
fi
###############################################################################
## Create an ArgoCD Application via the oc CLI - modify .spec as needed
echo "Creating ArgoCD Application..."
cat << YAML | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${GIT_REPO_NAME}
  namespace: argocd
spec:
  ignoreDifferences:
    - group: hive.openshift.io
      jsonPointers:
        - /spec/installed
      kind: ClusterDeployment
    - group: extensions.hive.openshift.io
      jsonPointers:
        - /spec
      kind: AgentClusterInstall
    - kind: Secret
      jsonPointers:
        - /data
  destination:
    name: ''
    namespace: ''
    server: 'https://kubernetes.default.svc'
  source:
    repoURL: '${GIT_REPO}'
    targetRevision: HEAD
    ## Path is the repo directory that containers the cluster(s) configuration and deployment manifests
    path: ztp-clusters/
    ## Enable recursive sub-directory search to enable management of multiple cluster from this single Application
    directory:
      recurse: true
  project: ${ARGOCD_PROJECT_NAME}
  syncPolicy:
    automated:
      ## Do NOT give ArgoCD the ability to PRUNE resources with cluster-admin unless you want your cluster to be sucked into a black hole
      prune: false
      selfHeal: false
    syncOptions: []
YAML

###############################################################################
## Enable cluster access to the ArgoCD Operator
if [ "${ARGOCD_CLUSTER_ACCESS}" == "true" ]; then
  ## Give the ArgoCD ServiceAccount cluster-admin access
  echo "Giving ArgoCD cluster-admin access..."
  oc adm policy add-cluster-role-to-user cluster-admin -z argocd-argocd-application-controller -n argocd

  ## Get the argocd-default-cluster-config Secret then modify it and apply it right back to the cluster
  echo "Enabling ArgoCD to access cluster resources..."
  #oc get secret argocd-default-cluster-config -n argocd -o json \
  #| jq --arg clusterResources "$(echo 'true' | base64)" '.data["clusterResources"]=$clusterResources' \
  #| jq --arg config "$(echo '{"tlsClientConfig":{"insecure":true}}' | base64)" '.data["config"]=$config' \
  #| oc apply -f -
fi

echo ""
echo "Finished deploying ArgoCD!"
