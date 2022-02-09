# How to use this repo

## Prerequisites

- For Hub cluster setup, a linux or mac terminal with Git installed - WSL works too.
- A GitHub account - you can use other SCMs too but that's not covered here.
- A [RH Pull Secret](https://console.redhat.com/openshift/downloads#tool-pull-secret) stored at `$HOME/rh-ocp-pull-secret.json`

## Fork this Repo

First thing's first, [fork this repo](https://github.com/Red-Hat-SE-RTO/openshift-ztp/fork) - then clone it down and push it to a second remote endpoint.  This second endpoint should be a [new private repository](https://github.com/new):

```bash
## Clone the repo locally from your public fork
git clone git@github.com:YOUR_USERNAME/openshift-ztp.git
cd openshift-ztp

## Add a private remote to your private repo
git remote add private git@github.com:YOUR_USERNAME/private-openshift-ztp.git

## Touch a file
mkdir ztp-clusters
echo "# Take a seat" > ztp-clusters/.nofile

## Add the changes
git add ztp-clusters/

## Commit the changes
git commit -m "repo start"

## Push the changes
git push private main
```

Now that you have a private fork and can push to it, the Hub OpenShift cluster needs to be configured - then centralized credentials are set, and then spoke clusters can be defined and deployed in a single shot via an Ansible Tower survey.

## Configure Hub cluster - One time process

There is a Hub Cluster, and a number of Spoke clusters.  Before deploying Spoke clusters, the Hub cluster needs to be configured:

- Install OpenShift 4.9+ via OAS (not sure on that last part, more testing to come for non-bare-metal deployments)
- Install ODF Operator, set up ODF
- Install ArgoCD Operator, deploy ArgoCD
- Install Ansible Automation Platform 2 Operator, cluster-scoped, deploy a Controller
- Install RH Advanced Cluster Management Operator, deploy a Hub

Once the Operators are installed and instantiated, configure them by running - you can also just start off after installing OpenShift with the following:

```bash
# configure the Hub cluster with all the operators, instances, and OAS for RHACM - it will prompt you and wait for you to manually configure a StorageSystem for ODF.
./bootstrap-hub.sh

# configure Ansible - modify this file around the git credentials
nano bootstrap-aap2.sh
./bootstrap-aap2.sh ## Maybe run this twice if the Project doesnt show up...it's idempotent
## IMPORTANT!!! take note of the token the first time the script is run
## It's also saved to ./aap2_user_application_token tho lol

# edit the argocd bootstrap file with your fork
nano bootstrap-argocd.sh

# deploy and configure ArgoCD with an Application to start syncing from
./bootstrap-argocd.sh
```

At this point all the automation is set up - next, supply some credentials and spoke clusters.

## Create Central Credentials

You need some credentials to connect to different vCenter appliances and Ansible Tower, in addition to a Pull Secret for OCP Containers from the RH Registry.

### Install Reflector

Reflector will sync ConfigMaps and Secrets to multiple Namespaces.

```bash
## Add emberstack repo 
helm repo add emberstack https://emberstack.github.io/helm-charts

## Update Helm repos
helm repo update

## Create a reflector project
oc new-project reflector

## Install the Helm chart
helm upgrade --install reflector emberstack/reflector --namespace reflector

## Add SCC to SA RBAC
oc adm policy add-scc-to-user privileged -z default -n reflector
oc adm policy add-scc-to-user privileged -z reflector -n reflector
```

## Create Credentials Namespace

Credentials in a central namespace will be mirrored into spoke cluster namespaces - create that central namespace:

```bash
## Create a shared ZTP credential namespace
oc new-project ztp-credentials
```

### GitHub Repo Credentials

If using the **Create Spoke Manifests** Ansible Playbook to create spoke cluster manifests from Tower, there is a Git credential secret that is needed to push generated manifests.

Modify the `./ansible/create_git_push_secret.sh` file and run it, swapping out Git target and credentials to reflect your fork and credentials that can pull/push to it.  It will create the `secret/ztp-git-push-credentials` in `namespace/ztp-credentials`

### Ansible Tower Application OAuth Token Secret

*say that three times fast*

vSphere infrastructre is provisioned via Ansible Tower, specifically AnsibleJob CRDs that are synced to the hub cluster by ArgoCD.

The AnsibleJob CRD needs to have a token to access the Tower API - AAP2 and the Token are configured as part of the `./bootstrap-aap2.sh` script....you can find the User Token at `./aap2_user_application_token`

Take that token and the Route of the Tower instance and pass it to a Secret in the same `ztp-credentials` namespace as the GitHub credentials:

```bash
## Get AAP2 Controller/Tower Route
AAP_ROUTE="$(echo "https://$(oc get -n ansible-automation-platform route/ac-tower -o jsonpath='{.spec.host}')")"

## Set your Tower Token
ANSIBLE_TOWER_TOKEN="$(cat ./aap2_user_application_token)"

## Create the Ansible Tower Credential
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: ansible-tower-credentials
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  host: $AAP_ROUTE
  token: $ANSIBLE_TOWER_TOKEN
```

### Pull Secret...Secret

Take the RH Registry Pull Secret you stored at `$HOME/rh-ocp-pull-secret.json` and create a Secret from it:

```bash
## Set the Pull Secret Path
PULL_SECRET_PATH="$HOME/rh-ocp-pull-secret.json"

cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: assisted-deployment-pull-secret
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  .dockerconfigjson: '$(cat ${PULL_SECRET_PATH})'
EOF
```

This pull secret can be shared by spoke clusters to pull from the RH Registry for deployment - you would add other Pull Secret compositions for disconnected/offline registries.

### vCenter Credentials

The vSphere infrastructure is created by Ansible via the vCenter modules/API I guess.  You need to pass in some vCenter credentials is all I'm saying.

```bash
## Set the vCenter Connection Details
VCENTER_FQDN="vcenter.example.com"
VCENTER_USERNAME="administrator@vsphere.local"
VCENTER_PASSWORD="someString"

## Create the vSphere Credential
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: loe-rdu-vcenter-credentials
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  vcenter_fqdn: $VCENTER_FQDN
  vcenter_username: $VCENTER_USERNAME
  vcenter_password: $VCENTER_PASSWORD
  skip_ssl_validation: "true"
EOF
```

> From this point, all the Secrets are pre-configured on the cluster, can be pulled from ExternalSecrets+Vault, blah blah - now you can have empty Secrets in Git and it'll just magically sync over with Reflector.

## Create Spoke Clusters

The recommended way to do this is via Ansible Tower - if you used the `./bootstrap-aap2.sh` script then it's already set up, you just need to run the **Create Spoke Manifest** Job Template, or the **Create Spoke Manifest - Survey** to use an interactive version.