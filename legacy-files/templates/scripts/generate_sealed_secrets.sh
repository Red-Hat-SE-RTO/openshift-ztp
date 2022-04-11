#!/bin/bash

function assisted_deployment_spoke_pull_secret() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: assisted-deployment-pull-secret
  namespace: '${CLUSTER_NAME}'
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
stringData:
  .dockerconfigjson: '$(cat ${PULL_SECRET_PATH})'
YAML
}

function assisted_deployment_ansible_tower_credential() {
cat << YAML
kind: Secret
apiVersion: v1
metadata:
  name: ${ANSIBLE_TOWER_CREDENTIALS_NAME}
  namespace: ${1}
  creationTimestamp: null
  labels:
    cluster.open-cluster-management.io/credentials: ''
    cluster.open-cluster-management.io/type: ans
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
stringData:
  host: >-
    $(echo $ANSIBLE_TOWER_HOST)
  token: $(echo $ANSIBLE_TOWER_TOKEN)
type: Opaque
YAML
}

function assisted_deployment_vsphere_credential() {
cat << YAML
kind: Secret
apiVersion: v1
metadata:
  name: ${VSPHERE_CREDENTIALS_NAME}
  namespace: ${VSPHERE_CREDENTIALS_NAMESPACE}
  creationTimestamp: null
  labels:
    cluster.open-cluster-management.io/credentials: ''
    cluster.open-cluster-management.io/type: vmw
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
stringData:
  skip_ssl_validation: "true"
  ssh-privatekey:  |
$(cat $SSH_PRI_KEY_PATH | awk '{printf "      %s\n", $0}')
  vCenter: https://${VCENTER_ENDPOINT}
  vcenter_fqdn: ${VCENTER_ENDPOINT}
  ssh-publickey:  |
$(cat $SSH_PUB_KEY_PATH | awk '{printf "      %s\n", $0}')
  pullSecret: '$(cat ${PULL_SECRET_PATH})'
  baseDomain: ''
  username: ${VCENTER_USERNAME}
  defaultDatastore: '${VCENTER_DATASTORE}'
  cacertificate:  |
$(cat $VCENTER_CA_CERT_PATH | awk '{printf "      %s\n", $0}')
  cluster: '${VCENTER_CLUSTER}'
  password: '${VCENTER_PASSWORD}'
  datacenter: '${VCENTER_DATACENTER}'
type: Opaque
YAML
}

#########################################################
## LEGACY FUNCTIONS

function cluster_pull_secret() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-pull-secret
  namespace: '${CLUSTER_NAME}'
  labels:
    hive.openshift.io/cluster-deployment-name: ${CLUSTER_NAME}
    hive.openshift.io/secret-type: merged-pull-secret
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '$(cat ${PULL_SECRET_PATH})'
YAML
}

function cluster_ssh_private_key() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-ssh-private-key
  namespace: '${CLUSTER_NAME}'
  labels:
    cluster.open-cluster-management.io/copiedFromNamespace: ${ACM_CREDENTIALS_NAME}
    cluster.open-cluster-management.io/copiedFromSecretName: ${ACM_CREDENTIALS_NAME}
type: Opaque
stringData:
  ssh-privatekey: |
$(cat $SSH_PRI_KEY_PATH | awk '{printf "      %s\n", $0}')
YAML
}

function cluster_ssh_keys() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-ssh-key
  namespace: '${CLUSTER_NAME}'
  labels:
    cluster.open-cluster-management.io/copiedFromNamespace: ${ACM_CREDENTIALS_NAME}
    cluster.open-cluster-management.io/copiedFromSecretName: ${ACM_CREDENTIALS_NAME}
type: Opaque
stringData:
  ssh-privatekey: |
$(cat $SSH_PRI_KEY_PATH | awk '{printf "      %s\n", $0}')
  ssh-publickey: |
$(cat $SSH_PUB_KEY_PATH | awk '{printf "      %s\n", $0}')
YAML
}

function aws_credentials() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-aws-creds
  namespace: '${CLUSTER_NAME}'
  labels:
    cluster.open-cluster-management.io/copiedFromNamespace: ${ACM_CREDENTIALS_NAME}
    cluster.open-cluster-management.io/copiedFromSecretName: ${ACM_CREDENTIALS_NAME}
type: Opaque
stringData:
  aws_access_key_id: ${AWS_ACCESS_KEY_ID}
  aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}
YAML
}

function vsphere_credentials() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-creds
  namespace: ${CLUSTER_NAME}
  labels:
    cluster.open-cluster-management.io/copiedFromNamespace: ${ACM_CREDENTIALS_NAME}
    cluster.open-cluster-management.io/copiedFromSecretName: ${ACM_CREDENTIALS_NAME}
type: Opaque
stringData:
  password: ${VCENTER_PASSWORD}
  username: ${VCENTER_USERNAME}
YAML
}

function vsphere_cacert() {
cat << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-certs
  namespace: ${CLUSTER_NAME}
  labels:
    cluster.open-cluster-management.io/copiedFromNamespace: ${ACM_CREDENTIALS_NAME}
    cluster.open-cluster-management.io/copiedFromSecretName: ${ACM_CREDENTIALS_NAME}
type: Opaque
stringData:
  cacertificate: |
$(cat $VCENTER_CA_CERT_PATH | awk '{printf "      %s\n", $0}')
YAML
}