# Deploy ZTP Infrastructure to vSphere - Ansible Content

## Prerequisites

- Install Ansible on a local host
- Install needed pip modules: `pip3 install -r ./requirements.txt`
- Install needed Ansible Collections: `ansible-galaxy collection install -r ./collections/requirements.yml`

## Running Locally

- Log into OpenShift

## Hub Setup

### Setup the Hub Cluster - Deploy Operators & Workloads

The following Playbook will take a fresh OpenShift 4.9+ cluster and deploy:

- Reflector
- Local Storage Operator
- OpenShift Data Foundation
- Gitea
- Red Hat Advanced Cluster Management
- Red Hat GitOps (ArgoCD)
- Red Hat Ansible Automation Platform 2

```bash
ansible-playbook 1_deploy.yaml
```

### Configure the Hub Cluster - Configure Operators & Workloads

The configuration playbook will do the following:

- Configure RHACM for OpenShift Assisted Installer Service
- Configure AAP2 Controller with a new Organization, Application, Credentials, Inventory, Project, Job Templates, and RBAC
- Configure Red Hat GitOps (ArgoCD) with a set of Projects, an Application, Git Repo with Credentials, and RBAC

```bash
ansible-playbook 2_configure.yaml
```

### Configure the Hub Cluster - Create Credentials

The `3_create_credentials.yaml` Playbook will create a set of credentials that will be needed to perform ZTP functions, such as:

- AAP2 Controller Credentials
- vCenter Credentials
- Assisted Service Pull Secret
- Git Repo Credentials to push to

```bash
ansible-playbook \
 -e vcenter_username="administrator@vsphere.local" \
 -e vcenter_password='somePass!' \
 -e vcenter_fqdn="vcenter.example.com" \
 3_create_credentials.yaml
```

See the Playbook for other default variables being passed.
