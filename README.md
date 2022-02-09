# Zero Touch Provisioning by the Southeast RTO Team

This repository houses assets for deploying OpenShift via ZTP (Zero-Touch Provisioning) to vSphere - other infrastructure platforms will be added as needed.

This process is conducted via Red Hat Advanced Cluster Management ([RH]ACM) as a function of GitOps where clusters and their states and supporting automation are defined in a Git repository for end-to-end provisioning of OpenShift clusters, their governance, policies, and applications.

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

## Proceedures & Documentation

There is a Hub Cluster that runs ArgoCD, Ansible, RHACM, and all the other supporting services needed to deploy Spoke Clusters.

Once the Hub Cluster has the needed workloads deployed, you can integrate AAP 2 Controller/Tower with RHACM for closed-loop automation of clusters.  RHACM will also need other things configured such as Credentials.

Configuration of ArgoCD follows, which then allows for pushing of a cluster and its state to a Git repo for GitOps driven Spoke Cluster deployment.

The Spoke Cluster resources are then created in the `ztp-clusters/` directory and on Git Push/Merge are applied to the local Hub cluster via ArgoCD, which then are picked up by RHACM/OAS.  The InfraEnv and cluster are then defined and ready for downloading the Discovery ISO.

Cluster composition, Discovery ISO download link, and other variables are passed to an AnsibleJob that will then kick off the Ansible Tower Job Template that will actually create the targeted Infrastructure with the Discovery ISO.

Once the intended systems report in and are discoverable by the InfraEnv, the AnsibleJob kicks back over to OAS/ZTP to continue the installation.

### tl;dr

Assuming you have an OCP 4.9+ cluster deployed with OpenShift Assisted Installer Service (OAS), you can simply run the following:

```bash
## Set the Git Repo if not using this one
GIT_REPO="git@github.com:kenmoini/wg-serto-ztp.git"
## Set the path to the SSH Key that has access to the Git repo
SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
## Create pull Secret
## https://console.redhat.com/openshift/create
vim "$HOME/rh-ocp-pull-secret.json"

## Log into the Hub cluster with a cluster-admin user:
oc login ...

## Bootstrap the Hub cluster with needed Operators and Configuration
./bootstrap-hub.sh

## Log into the AAP2 Controller/Tower and attach a subscription
oc get secret/ac-tower-admin-password -n ansible-automation-platform -o jsonpath='{.data.password}' | echo "$(base64 -d)"
echo "https://$(oc get -n ansible-automation-platform route/ac-tower -o jsonpath='{.spec.host}')"

## Attach a RH Subscription

## Bootstrap the Ansible Automation Platform 2 instance
./bootstrap-aap2.sh

## Bootstrap the ArgoCD instance
./bootstrap-argocd.sh
```

From this point, you would just create Spoke Cluster definitions, generate the manifests, and push to the Git repo:

```bash
## Copy the example-spoke-vars for the target cluster type, ./*.env-vars.sh files are in the .gitignore and will not be pushed to a repo by accident
cp ./example-spoke-vars/single-node-openshift.sh ./vsphere-sno.env-vars.sh
cp ./example-spoke-vars/three-node-openshift.sh ./vsphere-converged.env-vars.sh

## Create the Spoke Cluster Manifests
./bootstrap-spoke.sh ./vsphere-sno.env-vars.sh

## Check the newly made manifests into the repository
git add ztp-clusters/
git commit -m "added a new cluster"
git push
```

From here ArgoCD will pick up the new manifests, apply it to the Hub Cluster, which will use RHACM and AAP2 to deploy a cluster to vSphere automatically.

### 1. Deploy the Hub Cluster

- OCP 4.9+ deployed with OpenShift Assisted Installer Service (OAS) - can use this Ansible Automation for deploying to Libvirt: https://github.com/kenmoini/ocp4-ai-svc-libvirt
- Each application node needs an additional disk at /dev/vdb for ODF RWX StorageClass - or however you need to provision storage for ODF

1. Save your OCP Registry Pull Secret to a file at `$HOME/rh-ocp-pull-secret.json`
2. Log into your Hub OpenShift Cluster via the CLI `oc login ...`
3. Run `./bootstrap-hub.sh`

The `./bootstrap-hub.sh` script will label and configure the OpenShift cluster, install Operators, and setup OAS for ZTP.

### 2. Configure Ansible Automation Platform 2.0 Controller/Tower

Being that the Cloud Infrastructure Providers built into RHACM use Hive, which uses IPI under the covers, another automation tool needs to be used to provision the infrastructure for SNO and 3-node clusters to vSphere.  This is acheived with AAP2's AnsibleJob CRD.

With the Ansible Automation Platform 2 Controller/Tower that was deployed by the `./bootstrap-hub.sh` script, you can simply run the `./bootstrap-aap2.sh` script after logging in and attaching a Red Hat Subscription.

### 3. Configuring ArgoCD

ArgoCD takes Spoke Cluster definitions from a Git repo and syncs them to the Hub Cluster in order to kick off the ZTP processes.

You can find expanded step-by-step documentation here: [ArgoCD Setup](./docs/argocd-setup.md)

### 4. Creating a Spoke Cluster

With Ansible, ArgoCD, RHACM, and OpenShift properly configured and set up you can now create the OpenShift Spoke Cluster manifests.

```bash
## Copy the example-spoke-vars for the target cluster type, ./*.env-vars.sh files are in the .gitignore and will not be pushed to a repo by accident
cp ./example-spoke-vars/single-node-openshift.sh ./vsphere-sno.env-vars.sh

## Modify the env-vars files as needed to match the deployment and vSphere target

## Create the Spoke Cluster Manifests
./bootstrap-spoke.sh ./vsphere-sno.env-vars.sh

## Check the newly made manifests into the repository
git add ztp-clusters/
git commit -m "added a new cluster"
git push
```

Once ArgoCD syncs the new Spoke Cluster definitions it will kick off a fully automated deployment of OpenShift to vSphere!

---

## Docs & Examples

- [Ansible Automation Platform 2.0 on OpenShift Setup](./docs/aap2-setup.md)
- [ArgoCD Setup](./docs/argocd-setup.md)
- [Deploying Gitea to OpenShift](./docs/deploying-gitea-to-openshift.md)

## Additional Notes

- Gitea is based on Gogs, however [both are susceptible to RCE](https://github.com/gogs/gogs/issues/6536) - it would be ideal to transition to another Git repository platform that isn't so easily pwned.

## Helpful Links

- [Red Hat Hybrid Cloud OpenShift Assisted Installer Service](https://console.redhat.com/openshift/assisted-installer/clusters)
- [OpenShift Assisted Service on GitHub](https://github.com/openshift/assisted-service)
- [Bootstrap-in-place Installer Code in openshift/installer](https://github.com/openshift/installer/tree/master/data/data/bootstrap/bootstrap-in-place)
- [Bootstrap-in-place Documentation in openshift/enhancements](https://github.com/openshift/enhancements/blob/master/enhancements/installer/single-node-installation-bootstrap-in-place.md)
- [ZTP The Hard Way](https://github.com/jparrill/ztp-the-hard-way)
- [ArgoCD Cluster Wide Access](https://github.com/argoproj/argo-cd/issues/5886)
- [ArgoCD Namespaced mode as default?](https://github.com/argoproj-labs/argocd-operator/issues/523)

## TO-DO

- Swap ArgoCD out for Red Hat GitOps
- Add 3 node converged OpenShift cluster examples and workflows
- Add HA OpenShift cluster examples and workflows
- Convert Bash script templating of Spoke Clusters to Ansible
- Video on ZTP to vSphere deployments
- Expand to Nutanix
- Expand to Hyper-V

## Special Thanks

This is some galaxy-brain level stuff right here and is too much to be comprehended by normal mortals - there have been some people who have helped with all this that may not have commits into this repo...

- **Brandon Jozsa** - [@v1k0d3n](https://github.com/v1k0d3n) - [CloudCult](https://cloudcult.dev/)
- **Juan Manuel Parrilla Madrid** - [jparrill](https://github.com/jparrill)
- Andrew Schoenfeld for assisting with AAP2