# Deploy ZTP Infrastructure to vSphere

## Prerequisites

- Install Ansible
- Install needed pip modules: `pip3 install -r ./requirements.txt`
- Install needed Ansible Collections: `ansible-galaxy collection install -r ./collections/requirements.yml`

## Running Locally

- Log into OpenShift
- `ansible-playbook -i inv_localhost deploy_to_vsphere.yml`