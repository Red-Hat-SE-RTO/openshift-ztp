# Deploy ZTP Infrastructure to vSphere - Ansible Content

## Prerequisites

- A Hub OpenShift cluster
- Red Hat Registry Pull Secret (or an offline mirror registry pull secret)
- SSH Key pair
- A RH Ansible Automation Platform subscription packaged as a Satellite-compatible zip'd manifest file
- vCenter Credentials

## Running Locally

- Install Ansible on a local host
- Install needed pip modules: `pip3 install -r ./requirements.txt`
- Install needed Ansible Collections: `ansible-galaxy collection install -r ./collections/requirements.yml`
- Log into Hub OpenShift with `oc login`

## OpenShift Hub Cluster Setup

### 0. Using an Outbound Proxy

If you require an outbound proxy for connectivity then the workloads should automatically pick them up from the cluster configuration.

The Red Hat GPTE distributed Gitea operator currently does not support the needed capabilities to set the environmental variables on the Gitea container for proxy information - you can use the fork maintained by Ken Moini, as is the default currently.

You can switch to the RH GPTE distributed operator by setting the Ansible variable `gitea_operator_source: redhat-gpte-gitea`.

### 1. Setup the Hub Cluster - Deploy Operators & Workloads

The following Playbook will take a fresh OpenShift 4.9+ cluster and deploy:

- Reflector
- Local Storage Operator
- OpenShift Data Foundation
- Gitea
- Red Hat Advanced Cluster Management
- Red Hat GitOps (ArgoCD)
- Red Hat Ansible Automation Platform 2
- Red Hat Single Sign-On (SSO)
- Red Hat OpenShift Pipelines (Tekton)
- Red Hat OpenShift Logging (Elasticstack)
- Red Hat OpenShift cert-manager
- Simple HTTP Mirror for assets such as ISOs, Root FSes, etc.

Though by default nothing is deployed, you must specify workloads to enable:

```bash
ansible-playbook 1_deploy.yaml \
  -e deploy_reflector=true \
  -e deploy_lso=true \
  -e deploy_odf=true \
  -e deploy_http_mirror=true \
  -e deploy_rhacm=true \
  -e enable_rhacm_observability=true \
  -e deploy_gitea=true \
  -e deploy_rh_gitops=true \
  -e deploy_aap2_controller=true \
  -e deploy_rh_sso=true \
  -e deploy_rh_cert_manager=true \
  -e deploy_openshift_logging=true \
  -e deploy_openshift_pipelines=true
```

Or use a variable file, such as `deployment.vars.yaml`:

```yaml
---
deploy_reflector: true

deploy_nfd: false
deploy_lso: true
deploy_odf: true
deploy_http_mirror: true
deploy_rhacm: true
enable_rhacm_observability: true
deploy_gitea: true
deploy_rh_gitops: true
deploy_aap2_controller: true
deploy_rh_sso: true
deploy_rh_cert_manager: true
deploy_openshift_logging: true
deploy_openshift_pipelines: true

#########################################
## Local Storage Operator Variables
## lso_hostname_targets: is a list of hostnames to be used by the lso-operator for a LocalVolumeSet
lso_hostname_targets:
  - app-1
  - app-2
  - app-3
```

And then call the Playbook with the additional variable file:

```bash
ansible-playbook -e "@deployment.vars.yaml" 1_deploy.yaml
```

### 2. Configure the Hub Cluster - Configure Operators & Workloads

The configuration playbook will do the following:

- Configure RHACM for OpenShift Assisted Installer Service/Central Infrastructure Management
- Configure AAP2 Controller with a new Organization, Application, Credentials, Inventory, Project, Job Templates, and RBAC
- Configure Red Hat GitOps (ArgoCD) with a set of Projects, an Application, Git Repo with Credentials, and RBAC

```bash
ansible-playbook 2_configure.yaml \
  -e configure_rhacm=true \
  -e configure_aap2_controller=true \
  -e configure_rh_gitops=true \
  -e use_ztp_mirror=true \
  -e use_services_not_routes=true \
  -e pull_secret_path="~/rh-ocp-pull-secret.json" \
  # ...
```

Or, use a variable file, such as `configuration.vars.yaml`:

```yaml
---
configure_rhacm: true
configure_aap2_controller: true
configure_rh_gitops: true

use_ztp_mirror: true
use_services_not_routes: true

pull_secret_path: ~/rh-ocp-pull-secret.json

## View the default variables defined in the `2_configure.yaml` playbook for more control over SCM and other configuration
```

And then call the Playbook with the additional variable file:

```bash
ansible-playbook -e "@configuration.vars.yaml" 2_configure.yaml
```

### 3. Configure the Hub Cluster - Create Credentials

The `3_create_credentials.yaml` Playbook will create a set of credentials that will be needed to perform ZTP functions, such as:

- AAP2 Controller Credentials
- vCenter Credentials
- Assisted Service Pull Secret
- Git Repo Credentials to push Spoke Manifests to

This can be run locally or via the AAP2 Controller running on the Hub, it is already configured and just needs to be provided some variables.

```bash
## Locally
ansible-playbook \
 -e create_vsphere_credentials_secret=true \
 -e vcenter_username="administrator@vsphere.local" \
 -e vcenter_password='somePass!' \
 -e vcenter_fqdn="vcenter.example.com" \
 3_create_credentials.yaml
```

> You can find an all the credential variables and their information in the `example_vars/example_create_credentials.vars.yaml` file.

## Spoke Cluster Manifest Generation

Once the Hub has been set up and configured, with Credentials available, you can create a set of Spoke Cluster manifests.  The **Spoke Cluster Manifest Generation** Ansible Playbook can be run locally or via Ansible Tower/AAP 2 Controller - the previously run `2_configure.yaml` Playbook will set up a Job Template.

There are a set of example variables that would be passed to the **Spoke Cluster Manifest Generation** Playbook in `example_vars` - use it as such:

```bash
# Single Node OpenShift
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-singleNode.yaml" create_spoke_manifests.yml

# 3 Node Converged Control Plane + Application Node Cluster
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-3nodeConverged.yaml" create_spoke_manifests.yml

# 3 Control Plane + 3+ Application Node Cluster
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-haCluster.yaml" create_spoke_manifests.yml
```

> Optionally, you can also include additional variables that will modify the Spoke Cluster Manifest Generation process.

### Adding additional manifests to the Spoke Cluster

Add a `manifestOverrides` variable to the `create_spoke_manifests.yml` playbook to add additional manifests to the Spoke Cluster.

```yaml
---
# manifestOverrides allows you to add Manifest Objects that will be applied to the cluster as a default manifest at cluster install
manifestOverrides:
  - name: spoke-cluster-config
    # Both name and filename have to be unique
    filename: 99-cm-spoke-cluster-config.yaml
    content: |
      ---
      # This file simply adds extra metadata about the spoke cluster in a common place that can be referenced by RHACM/AAP2/etc
      kind: ConfigMap
      apiVersion: v1
      metadata:
        name: spoke-cluster-config
        namespace: openshift-config
        labels:
          name: {{ cluster_name }}
          cloud: vSphere
          vendor: OpenShift
          datacenter: {{ vcenter_datacenter }}
          cluster: {{ vcenter_cluster }}
          cluster-name: {{ cluster_name }}
      data:
        cluster_name: {{ cluster_name }}
        cluster_provider: vsphere
        cluster_type: {{ cluster_type }}

        vsphere_datacenter: {{ vcenter_datacenter }}
        vsphere_cluster: {{ vcenter_cluster }}
        vsphere_datastore: {{ vcenter_datastore }}
        vsphere_network: {{ vcenter_network }}
      {% if vsphere_iso_folder is defined %}
        vsphere_iso_folder: {{ vsphere_iso_folder }}
      {% endif %}
      {% if vsphere_vm_folder is defined %}
        vsphere_vm_folder: {{ vsphere_vm_folder }}
      {% endif %}

        cluster_nodes: '{{ cluster_nodes | to_json }}'
```

### Proxy Configuration for Ansible Execution Environment when running the Playbook

In case your AAP2 Controller is running in OpenShift, and you use a proxy to access external resources, you can configure the proxy for Ansible to use.  Just set the standard `http_proxy`, `https_proxy`, and `no_proxy` variables when running the Playbook.

```yaml
## Proxy Configuration for the Ansible Job Execution Environment
## These proxy variables are used by the Ansible Execution Environment as environment variables
http_proxy: 'http://192.168.51.1:3128/'
https_proxy: 'http://192.168.51.1:3128/'
no_proxy: ".cluster.local,.svc,.svc.cluster.local,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.51.0/24,api-int.core-ocp.lab.kemo.network,api.core-ocp.lab.kemo.network,localhost,127.0.0.1,.apps.core-ocp.lab.kemo.network"
```

### Proxy Configuration for the Spoke Cluster

If your Spoke Cluster that will be created also needs Proxy configuration set, you can pass it the `spoke_httpproxy`, `spoke_httpsproxy`, and `spoke_noproxy` variables when running the Playbook.

```yaml
# https://www.ibm.com/docs/en/zcxrhos/1.1.0?topic=installation-procedure
## Spoke Proxy Configuration
spoke_httpproxy: "http://192.168.77.1:3128/"
# spoke_httpsproxy -  A proxy URL to use for creating HTTPS connections outside the cluster. If you use an MITM transparent proxy network that does not require additional proxy configuration but requires additional CAs, you must not specify an httpsProxy value.
#spoke_httpsproxy: "http://192.168.77.1:3128/"
spoke_noproxy: ".svc.cluster.local,.cluster.local,.svc,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.51.0/24,api-int.{{ cluster_name }}.{{ base_domain }},api.{{ cluster_name }}.{{ base_domain }},localhost,.apps.{{ cluster_name }}.{{ base_domain }},localhost,127.0.0.1"
```
