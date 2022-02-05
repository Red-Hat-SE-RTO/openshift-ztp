#!/bin/bash

#########################################################
## Universal Variables

## GENERATE_SSHKEY - Generate a unique SSH Key or not: true/false
export GENERATE_SSHKEY="true"
## SSH_PRIVATE_KEY_PATH - Path to the SSH Private Key if GENERATE_SSHKEY is set to false
export SSH_PRI_KEY_PATH="$HOME/.ssh/id_rsa"
export SSH_PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"

## PULL_SECRET_PATH - Path to the RH Registry OCP pull secret, get from https://console.redhat.com/openshift/downloads
export PULL_SECRET_PATH="$HOME/pull-secret.json"

## DEPLOYMENT_TYPE specifies which deployment to use - maps to root directory of this repo, e.g. "aws", "vsphere", etc
export DEPLOYMENT_TYPE="vsphere"
## CLUSTER_TYPE specifies what type of cluster, sno/converged/full
export CLUSTER_TYPE="sno"
## CLUSTER_NAME is the name of the OCP cluster
export CLUSTER_NAME="sno-ocp"
## BASE_DOMAIN is the base domain for the OCP cluster
export BASE_DOMAIN="atl.kemo.labs"
export OPENSHIFT_RELEASE="4.9.9"
## CLUSTER_LOCATION is the location of the OCP cluster, extra metadata
export CLUSTER_LOCATION="loe-atl-1"

#########################################################
## vSphere Specific Variables
export VCENTER_ENDPOINT="vcenter.kemo.labs"
export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_PASSWORD="somepass!"
export VCENTER_DATACENTER="LabDC"
export VCENTER_CLUSTER="LabCluster"
export VCENTER_DATASTORE="nvme"
export VCENTER_NETWORK="VMNetwork"
export VCENTER_CA_CERT_PATH="$HOME/vcenter-ca.pem"

export SNO_MEMORY="65536"
export SNO_CPU_CORES="12"
export SNO_DISK="240" # in GB
export SNO_MAC_ADDRESS="00:51:56:42:06:90"

export ANSIBLE_TOWER_CREDENTIALS_NAME="${CLUSTER_NAME}-ansible-tower-credentials"
export ANSIBLE_TOWER_CREDENTIALS_NAMESPACE="open-cluster-management"
export ANSIBLE_TOWER_HOST="https://ac-tower-ansible-automation-platform.apps.core-ocp.kemo.labs"
export ANSIBLE_TOWER_TOKEN="someToken"

export VSPHERE_CREDENTIALS_NAME="${CLUSTER_NAME}-vcenter-credentials"
export VSPHERE_CREDENTIALS_NAMESPACE="vsphere-credentials"

#########################################################
## NMState Specific Variables
## NODE_NETWORK_TYPE: static|dhcp
export NODE_NETWORK_TYPE="static"
export MACHINE_NETWORK_CIDR="192.168.1.0/24"

## SNO_NM_CONFIG defines an example NMState configuration for Single Node OpenShift with Static IP
## SNO takes a single IP for the host, App VIP and API VIP, this IP needs to resolve all of the needed DNS entries
SNO_NM_CONFIG='hostname: '${CLUSTER_NAME}'
spec:
  config:
    dns-resolver:
      config:
        server:
        - 192.168.42.9
        - 192.168.42.10
        search:
        - atl.kemo.labs
    interfaces:
    - ipv4:
        address:
        - ip: 192.168.1.5
          prefix-length: 24
        dhcp: False
        enabled: true
      name: ens192
      state: up
      type: ethernet
    routes:
      config:
      - destination: 0.0.0.0/0
        next-hop-address: 192.168.1.1
        next-hop-interface: ens192
        table-id: 254
  interfaces:
  - name: "ens192"
    macAddress: "'${SNO_MAC_ADDRESS}'"
'