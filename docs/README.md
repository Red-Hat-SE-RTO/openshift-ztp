# Quick Start Guide for blank OpenShift cluster

### Requirements
* ODF
* OPENSHIFT
* RHACM


### Programs that shpuld be installed via preflight_checks.sh
* jq
* helm
* oc
* kubeseal
* argocd
* git
* kustomize

### Recomned hub clsuter sizing
* Control plane Nodes:
* Worker Nodes:

### Run bootstrap-hub.sh
**Log into the Hub cluster with a cluster-admin user:**
```
oc login ...
```
**Start bootstrap-hub.sh**
```
./bootstrap-hub.sh
```

### TEMP - Manually install OpenShift GitOPs
* Install OpenShift GitOps in argocd namespace

### Install Gitea
> You may also use what ever repo you would like.
* [Deploying Gitea to OpenShift](deploying-gitea-to-openshift.md)

### Install Ansible Tower
> verify ocs-storagecluster-ceph-rbd is the default storage class
* [Ansible Automation Platform 2, Controller/Tower Setup](aap2-setup.md)

## Configure Credentials for deployment
### Install and configure credentials
* [Install Reflector](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/docs/credential-setup.md#install-reflector)
* [Install Reflector - Usage](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/USAGE.md#install-reflector)

### Create Credentials Namespace
* [Create Credentials Namespace](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/USAGE.md#create-credentials-namespace)

### Create GitHub Repo Credentials
* [GitHub Repo Credentials](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/USAGE.md#github-repo-credentials)

### Configure Ansible Tower credentials
* [Ansible Tower Application OAuth Token Secret](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/USAGE.md#ansible-tower-application-oauth-token-secret)
*  [Create an Ansible Tower Credential - Example](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/docs/credential-setup.md#create-an-ansible-tower-credential)

### Configure  vCenter Credential
* [Create a vCenter Credential - Example](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/docs/credential-setup.md#create-a-vcenter-credential)

### Configure Pull Secret
* [Pull Secret...Secret](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/USAGE.md#pull-secretsecret)
* [Create a Pull Secret - Example](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/docs/credential-setup.md#create-a-pull-secret)

## Start cluster deployments
* [See Deployment Examples for different configuration settings](https://github.com/Red-Hat-SE-RTO/openshift-ztp/blob/main/deployment-examples/README.md)