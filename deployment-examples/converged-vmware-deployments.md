# Converged OpenShift Deployments
This document contains different node configurations for OpenShift deployments. These variables are to be used in the `create-spoke-cluster` Automation template.

## Requirements
* See [mac Generator for OpenShift deployments on VMWARE](https://gist.github.com/tosin2013/eb9e67ab88da09b9597f1b7760f199c9) before starting a unique mac is need for each deployment

### VMWARE DHCP Configuration 
> This configuration will auto assign ip address and auto assign the dns servers as well. This configuration will auto assign the vips for api and the load balancer. 
![20220223121511](https://i.imgur.com/h2vspd7.png)
```
---
source_git_repo: https://gitea.example.com/user1/openshift-ztp

cluster_type: converged
cluster_name: converged-ocp
base_domain: example.com
cluster_location: loc-1
node_network_type: dhcp
cluster_api_vip: 192.168.1.10
cluster_load_balancer_vip: 192.168.1.11
cluster_node_network_ipam: dhcp

vcenter_credential_secret_name: "example-vcenter-credentials"
vcenter_datacenter: Datacenter
vcenter_datastore: Datastore
vcenter_cluster: Cluster
vcenter_network: VM Network
node_boot_timeout: 60
node_count: 3

cluster_nodes:
  - name: converged-ocp-1
    type: converged-node
    vm:
      cpu_cores: 8
      cpu_sockets: 1
      cpu_threads: 1
      memory: 65536
      disks:
        - size: 120
          name: boot
        - size: 100
          name: odf
        - size: 100
          name: odf
    interfaces:
      - name: ens192
        mac_address: 00:50:56:68:47:10
        dhcp: true
  - name: converged-ocp-2
    type: converged-node
    vm:
      cpu_cores: 8
      cpu_sockets: 1
      cpu_threads: 1
      memory: 65536
      disks:
        - size: 120
          name: boot
        - size: 100
          name: odf
        - size: 100
          name: odf
    interfaces:
      - name: ens192
        mac_address: 00:50:56:68:47:10
        dhcp: true
  - name: converged-ocp-3
    type: converged-node
    vm:
      cpu_cores: 8
      cpu_sockets: 1
      cpu_threads: 1
      memory: 65536
      disks:
        - size: 120
          name: boot
        - size: 100
          name: odf
        - size: 100
          name: odf
    interfaces:
      - name: ens192
        mac_address: 00:50:56:68:47:10
        dhcp: true
```
Job Slicing `1`
Options: `Concurrent Jobs`

### VMWARE DHCP Static Configuration WIP
```
---
source_git_repo: https://gitea.example.com/user1/openshift-ztp

cluster_type: converged
cluster_name: converged-ocp
base_domain: example.com
cluster_location: loc-1
cluster_api_vip: 192.168.1.71
cluster_load_balancer_vip: 192.168.1.71
cluster_node_cidr: 192.168.1.0/24
cluster_node_network_ipam: static
cluster_node_network_static_dns_servers:
  - 1.1.1.1
  - 8.8.8.8
cluster_node_network_static_dns_search_domains:
  - example.com

vcenter_credential_secret_name: "example-vcenter-credentials"
vcenter_datacenter: Datacenter
vcenter_datastore: Datastore
vcenter_cluster: Cluster
vcenter_network: VM Network

cluster_nodes:
  - name: converged-ocp-1
    type: converged-node
    vm:
      cpu_cores: 8
      cpu_sockets: 1
      cpu_threads: 1
      memory: 65536
      disks:
        - size: 120
          name: boot
        - size: 100
          name: odf
        - size: 100
          name: odf
    interfaces:
      - name: ens192
        mac_address: 00:51:56:42:06:91
        dhcp: false
        ipv4:
          - address: 192.168.1.71
            prefix: 24
        routes:
          - destination: 0.0.0.0/0
            next_hop_address: 192.168.1.1
            next_hop_interface: ens192
            table_id: 254
```

### VMWARE DHCP Static Configuration with Multi Nic - WIP
> need to select different VM networks `vcenter_network` in VMWARE
```
---
source_git_repo: https://gitea.example.com/user1/openshift-ztp

cluster_type: converged
cluster_name: converged-ocp
base_domain: example.com
cluster_location: loc-1
cluster_node_cidr: 192.168.1.0/24
cluster_node_network_ipam: static

vcenter_credential_secret_name: "example-vcenter-credentials"
vcenter_datacenter: Datacenter
vcenter_datastore: Datastore
vcenter_cluster: Cluster
vcenter_network: VM Network

cluster_nodes:
  - name: converged
    type: converged-node
    vm:
      cpu_cores: 8
      cpu_sockets: 1
      cpu_threads: 1
      memory: 65536
      disks:
        - size: 120
          name: boot
        - size: 100
          name: odf
        - size: 100
          name: odf
    interfaces:
      - name: ens192
        mac_address: 00:50:56:68:47:10
        dhcp: true
      - name: ens224
        mac_address: 00:51:56:42:06:91
        ipv4:
          - address: 192.168.10.21
            prefix: 24
        dhcp: false
        state: up
        type: ethernet
```

## For Issues see Troubleshooting doc
* [TroubleShooting Doc](troubleshooting.md)
