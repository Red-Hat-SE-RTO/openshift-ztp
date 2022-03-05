# Quick Start Guide

### Requirements 
* ODF 
* OPENSHIFT
* RHACM
* kustomize 

### Programs that shpuld be installed via preflight_checks.sh
* jq
* helm
* oc 
* kubeseal
* argocd
* git 

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
* [Deploying Gitea to OpenShift](deploying-gitea-to-openshift.md)