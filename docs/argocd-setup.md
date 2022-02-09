# ArgoCD Setup

ArgoCD drives the initialization of Spoke Cluster deployments in a GitOps model.  That means:

1. A Spoke Cluster has its manifests defined: Namespace, Pull Secret, AgentClusterInstall, ClusterDeployment, KlusterletAddonConfig, InfraEnv, ClusterConfig, and AnsibleJob.  Credentials are created as Sealed Secrets.
2. These manifests are then checked into/merged/uploaded to a Git repo
3. ArgoCD picks up those new manifests and applies them to a Hub OpenShift cluster.
4. Once applied to the Hub OpenShift cluster, the Ansible Automation Platform 2 and RHACM/OAS Operators kicks off the ZTP process
5. Optionally, if ArgoCD only has access to specific namespaces, it can also delete those Spoke OpenShift Clusters by pruning the objects from the Hub cluster

To get to that point of things working, ArgoCD needs to be configured in a few ways.

## 1. Installing the ArgoCD Operator

From this repo root directory run the following:

```bash
## Login to OpenShift with a cluster-admin user
OCP_VERSION="4.9"

## Create the argocd Namespace and Install the ArgoCD
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/argocd-operator/
```

## 2. Creating the ArgoCD Instance

With the ArgoCD Operator installed, you can now instantiate an ArgoCD Operand:

```bash
## Login to OpenShift with a cluster-admin user
OCP_VERSION="4.9"

## Create the argocd Namespace and Install the ArgoCD
oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/argocd-operator/

## Wait a few seconds...
sleep 15

## Get the ArgoCD Dashboard Route
echo "https://$(oc get -n argocd route/argocd-server -o jsonpath='{.spec.host}')"
```

From here, you may normally log into the ArgoCD Dashboard, it uses the OpenShift OAuth and provides everyone admin capabilities, and otherwise provision resources such as Credentials and Applications - this can also be applied to the cluster with some YAML...

## 3. Creating an ArgoCD Project

Ideally you'd want to organize the ZTP assets in an ArgoCD Project - this is a different Project CRD from the OpenShift Projects that extend native Namespaces.

The AppProject's `metadata.name` is what the ArgoCD Project will be named logically - modify the '.spec' as needed for more fine-grained control.

```bash
## Create an ArgoCD Project via the oc CLI
cat << YAML | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  creationTimestamp: null
  name: ztp
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
```

## 4. Adding Git Credentials

Likely this repo that ArgoCD syncs to is private and thus needs credentials to access it.

```bash
## Specify an SSH Private Key to use to log into the Git repo
SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"

## Define the Git repo information
GIT_REPO="git@github.com:kenmoini/openshift-ztp.git"
GIT_REPO_NAME=$(echo $GIT_REPO | cut -d '/' -f2 | sed 's/.git$//')

## Create an ArgoCD Credential via the oc CLI
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
  project: ztp
  sshPrivateKey: |
$(cat $SSH_PRIVATE_KEY_PATH | awk '{printf "      %s\n", $0}')
  type: git
  insecure: "true"
  url: ${GIT_REPO}
type: Opaque
YAML
```

## 5. Deploying the ArgoCD Application

The ArgoCD Application is what will actually sync the repo and apply it to a target OpenShift cluster, like the local Hub OpenShift Cluster:

```bash
## Define the Git repo information
GIT_REPO="git@github.com:kenmoini/openshift-ztp.git"
GIT_REPO_NAME=$(echo $GIT_REPO | cut -d '/' -f2 | sed 's/.git$//')

## Create an ArgoCD Application via the oc CLI - modify .spec as needed
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
  project: ztp
  syncPolicy:
    automated:
      ## Do NOT give ArgoCD the ability to PRUNE resources with cluster-admin unless you want your cluster to be sucked into a black hole
      prune: false
      selfHeal: false
    syncOptions: []
YAML
```

This Application will sync any manifest under the `ztp-clusters/` folder in the repo, which can be the manifests of many Spoke Clusters - alternatively you could have an Application for single clusters and manage them a bit more atomically.

Now the functions of ArgoCD are operationally there, but the Spoke Cluster manifests still need to be created - this can be done with the `./bootstrap-spoke.sh` script.

## [Optional] Give ArgoCD cluster access

***Note***:  The Operator Subscription and Instance provided by this repo allows ArgoCD to run in cluster-mode and just needs the RBAC to access resources in different namespaces such as cluster-admin access.

If ArgoCD is deployed in Namespaced-mode then normally you have to specify what Namespaces ArgoCD has access to - that's sometimes challenging in a ZTP workflow where every provisioned cluster has their own Namespace.  You can provide ArgoCD cluster-wide access with a small set of modifications:

- Modify the `secret/argocd-default-cluster-config` and add `clusterResources: true` and modify `config: {"tlsClientConfig":{"insecure": true}}`

```bash
## Give the ArgoCD ServiceAccount cluster-admin access
oc adm policy add-cluster-role-to-user cluster-admin -z argocd-argocd-application-controller -n argocd

## Get the argocd-default-cluster-config Secret then modify it and apply it right back to the cluster
oc get secret argocd-default-cluster-config -n argocd -o json \
 | jq --arg clusterResources "$(echo 'true' | base64)" '.data["clusterResources"]=$clusterResources' \
 | jq --arg config "$(echo '{"tlsClientConfig":{"insecure":true}}' | base64)" '.data["config"]=$config' \
 | oc apply -f -
```