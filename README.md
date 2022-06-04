# Zero Touch Provisioning by the Southeast RTO Team

This repository houses assets for deploying OpenShift via ZTP (Zero-Touch Provisioning) to vSphere - other infrastructure platforms will be added as needed.

This process is conducted via Red Hat Advanced Cluster Management ([RH]ACM) as a function of GitOps where clusters and their states and supporting automation are defined in a Git repository for end-to-end provisioning of OpenShift clusters, their governance, policies, and applications.

**Featured Technologies:**

- [Red Hat OpenShift Container Platform](https://cloud.redhat.com/products/container-platform)
  - [Local Storage Operator](https://docs.openshift.com/container-platform/4.10/storage/persistent_storage/persistent-storage-local.html)
  - [Red Hat OpenShift Data Foundation](https://www.redhat.com/en/technologies/cloud-computing/openshift-data-foundation)
- [Red Hat Advanced Cluster Management](https://www.redhat.com/en/technologies/management/advanced-cluster-management)
- [Red Hat Ansible Automation Platform 2.x](https://www.redhat.com/en/technologies/management/ansible)
- [Red Hat GitOps](https://cloud.redhat.com/blog/announcing-openshift-gitops) (ArgoCD)
- [Reflector](https://github.com/emberstack/kubernetes-reflector) to manage secrets
- [Gitea](https://gitea.io/en-us/) for a cluster-hosted Git server
- HTTP Mirror for assets such as RHCOS ISOs and Root FS blobs, as well as anything else that would need to be served via HTTP server

## Primer Information

- ZTP operates in a ***Hub-and-Spoke*** model - there is a primary Hub cluster that runs RHACM and other supporting services to conduct the deployment of Spoke clusters.
- The Hub cluster needs to be deployed via the ***OpenShift Assisted Installer Service (OAS)*** due to how Metal3 and Ironic are provisioned - at the time of this writing, the needed workloads are not able to be deployed to other non-OAS provisioned clusters.
- *Caveat*: OAS ZTP to Bare Metal needs Metal3 and Ironic - normal OAS ZTP via the Discovery ISO does not, and thus can be deplolyed wherever really as long as there is RWX storage available.
- While you can leverage a GitOps model of deploying clusters with the ACM's traditional ***Cloud Infrastructure Providers***, this is only ZTP *in concept, not in practice*.
- Traditional Cloud Infrastructure Providers in ACM utilize ***Hive*** as the underlying provisioner, which in turn uses ***IPI*** - being IPI-driven means that many customizations are not available since IPI is very opinionated, such as *Single Node OpenShift instances which cannot be deployed to vSphere* via RHACM's CIPs/Hive/IPI processes.
- Deploying OCP to vSphere via Hive/IPI requires network access at port 443 (cannot be otherwise specified to a different port) to vCenter and the host it is deployed on for API Access and Host Access to upload the RHCOS OVA
- Alternatively, deploying OCP to vSphere via OAS/ZTP and Ansible can target non-443 ports and does not need direct access to an ESXi host, just vCenter.
- 3-Node Converged Control Plane/Application clusters are possible on vSphere via Hive/IPI but only with a pre-configured Cluster Scheduler Manifest Override, MachinePool, and ***still*** *will spin up 3 Application Nodes then spin them down after* the cluster is fully instantiated to match the specification in the MachinePool.
- The ***BootstrapInPlace processes handled by OAS*** are unique to the way it generates the ISO and cannot be applied to IPI/UPI installations without considerable effort around overriding and hosting large Ignition files on a web server (normal process of UPI)
- ZTP is driven via OAS, and thus produces ISOs to boot from - the system infrastructure needs to be able to boot from these Discovery ISOs
- The Hub OCP needs to be deployed with whatever extra Certificate Authorities needed to validate mirror services - OAS ZTP cannot skip validation of certificates in case of offline mirror deployment.

---

## Procedures & Documentation

There is a Hub Cluster that runs ArgoCD, Ansible, RHACM, and all the other supporting services needed to deploy Spoke Clusters.

Once the Hub Cluster has the needed workloads deployed, you can integrate AAP 2 Controller/Tower with RHACM for closed-loop automation of clusters.  RHACM will also need other things configured such as Credentials.

Configuration of ArgoCD follows, which then allows for pushing of a cluster and its state to a Git repo for GitOps driven Spoke Cluster deployment.

The Spoke Cluster resources are then created in the `ztp-clusters/` directory and on Git Push/Merge are applied to the local Hub cluster via ArgoCD, which then are picked up by RHACM/OAS.  The InfraEnv and cluster are then defined and ready for downloading the Discovery ISO.

Cluster composition, Discovery ISO download link, and other variables are passed to an AnsibleJob that will then kick off the Ansible Tower Job Template that will actually create the targeted Infrastructure with the Discovery ISO.

Once the intended systems report in and are discoverable by the InfraEnv, the AnsibleJob kicks back over to OAS/ZTP to continue the installation.

## Directory Structure

- `./ansible` - All the Ansible Automation used to bootstrap the hub, template credentials and spoke cluster manifests, and handle vSphere infrastructure automation
- `./docs` - Extra topic specific documentation
- `./legacy-files` - Legacy files such as Bash-based bootstrap scripts
- `./ztp-cluster-applications` - The path for the ZTP Clusters ArgoCD Applications for each Spoke Cluster that are generated per-spoke
- `./ztp-clusters` - The path for the ZTP Cluster manifests that are generated, synced by the ArgoCD Applications in `./ztp-cluster-applications`

## Quickstart - tl;dr

There are two processes that are needed to deploy OpenShift to vSphere via ZTP:

- One-time setup of a Hub Cluster
- Individual GitOps-based deployment templating of manifests into a Git repo, per Spoke Clusters

### Setting up the Hub Cluster

Assuming you have an OCP 4.9+ cluster deployed with OpenShift Assisted Installer Service (OAS), you can simply run the following to bootstrap it into a Hub Cluster:

```bash
## Install needed pip modules
pip3 install -r ./requirements.txt

## Install needed Ansible Collections
ansible-galaxy collection install -r ./collections/requirements.yml

## Log into the Hub cluster with a cluster-admin user:
oc login ...

## Bootstrap the Hub cluster with needed Operators and Workloads
ansible-playbook ansible/1_deploy.yaml

## Configure the Hub cluster Operators and Workloads, namely RHACM, AAP2, and RH GitOps (ArgoCD)
ansible-playbook ansible/2_configure.yaml

## Create credentials for vSphere Infrastructure, Pull Secret, Git credentials, etc
ansible-playbook \
 -e vcenter_username="administrator@vsphere.local" \
 -e vcenter_password='somePass!' \
 -e vcenter_fqdn="vcenter.example.com" \
 ansible/3_create_credentials.yaml
```

### Creating Spoke Clusters

To set up a Spoke cluster, you would just create Spoke Cluster definitions, generate the manifests, and push to the Git repo that RH GitOps is syncing to:

Once the Hub has been set up and configured, with Credentials available, you can create a set of Spoke Cluster manifests.  The **Spoke Cluster Manifest Generation** Ansible Playbook can be run locally or via Ansible Tower/AAP 2 Controller.  The previously run `2_configure.yaml` Playbook will set up a Job Template.

There are a set of example variables that would be passed to the **Spoke Cluster Manifest Generation** Playbook in `example_vars` - use it as such:

```bash
ansible-playbook -i ansible/inv_localhost -e "@ansible/example_vars/create_spoke_manifests-haCluster.yaml" ansible/create_spoke_manifests.yml
```

Now you just need to click the ***Sync*** button in RH GitOps!

From here RH GitOps will pick up the new manifests, apply it to the Hub Cluster, which will use RHACM and AAP2 to deploy a cluster to vSphere automatically.

---

## Docs & Examples

- [Ansible Automation Platform 2.0 on OpenShift Setup](./docs/aap2-setup.md)
- [ArgoCD Setup](./docs/argocd-setup.md)
- [Deploying Gitea to OpenShift](./docs/deploying-gitea-to-openshift.md)

## For Issues see Troubleshooting doc

* [Troubleshooting Doc](legacy-files/deployment-examples/troubleshooting.md)

## Asides & Additional Notes

- Gitea is based on Gogs, however [both are susceptible to RCE](https://github.com/gogs/gogs/issues/6536) - it would be ideal to transition to another Git repository platform that isn't so easily pwned.

## Helpful Links

In case you're wanting to learn more, or get stuck down the way with some oddities, here are some links that we found helpful along the way:

- [Red Hat Hybrid Cloud OpenShift Assisted Installer Service](https://console.redhat.com/openshift/assisted-installer/clusters)
- [OpenShift Assisted Service on GitHub](https://github.com/openshift/assisted-service)
- [Bootstrap-in-place Installer Code in openshift/installer](https://github.com/openshift/installer/tree/master/data/data/bootstrap/bootstrap-in-place)
- [Bootstrap-in-place Documentation in openshift/enhancements](https://github.com/openshift/enhancements/blob/master/enhancements/installer/single-node-installation-bootstrap-in-place.md)
- [ZTP The Hard Way](https://github.com/jparrill/ztp-the-hard-way)
- [ArgoCD Cluster Wide Access](https://github.com/argoproj/argo-cd/issues/5886)
- [ArgoCD Namespaced mode as default?](https://github.com/argoproj-labs/argocd-operator/issues/523)

## TO-DO/WishList

- Disconnected deployments (In progress)
- Video on ZTP to vSphere deployments
- Expand to Nutanix
- Expand to Hyper-V
- External-Secrets & Vault integration
- Quick start Script
- [DONE] Swap ArgoCD out for Red Hat GitOps
- [DONE] Add HA OpenShift cluster examples and workflows (Fix tagging of machines when it populates in cluster)
- [DONE] Convert Bash script templating of Spoke Clusters to Ansible
- [DONE, Superseded by Ansibleization] bootstrap-hub.sh (bug-fixs and Optimizations)

## Special Thanks

This is some galaxy-brain level stuff right here and is too much to be comprehended by normal mortals - there have been some people who have helped with all this that may not have commits into this repo...

- **Brandon Jozsa** - [@v1k0d3n](https://github.com/v1k0d3n) - [CloudCult](https://cloudcult.dev/)
- **Juan Manuel Parrilla Madrid** - [jparrill](https://github.com/jparrill)
- Andrew Schoenfeld for assisting with AAP2
