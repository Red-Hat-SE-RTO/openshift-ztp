# Deploy JFrog to vSphere on Fedora CoreOS

## Prerequisites

- Install Ansible: `python3 -m pip install ansible`
- Install needed pip modules: `python3 -m pip install -r ./requirements.txt`
- Install needed Ansible Collections: `ansible-galaxy collection install -r ./collections/requirements.yml`

## Copy and Modify the Variables

```bash
cp example.vars.yml vars.yml

nano vars.yml
```

## Deploy JFrog to FCOS VM

```bash
ansible-playbook -e "@vars.yml" 1_bootstrap.yml
```

> This VM will reboot twice in order to install the needed packages and update the system.

## Post-start OOBE Configuration

1. Log in to the web panel at the FQDN or IP address of the VM.
2. Use the default credentials to log in: `admin` / `password`
3. Change the default credentials and supply an email address at https://${ARTIFACTORY_URL}/ui/admin/management/users/admin/edit
4. If your EULA is not signed, run the following call: `curl -XPOST -vu 'username:password' https://${ARTIFACTORY_URL}/artifactory/ui/jcr/eula/accept`
5. Create a new Docker-type registry - give it a name like `ocp4`, allow v2 schema 1 tags, and set the Docker Tag Retention to `99999999`.
6. You can perform a test with the following:

```bash
# Set the needed variables
export ARTIFACTORY_URL="https://artifactory.example.com/ocp4"
export ARTIFACTORY_USER="admin"
export ARTIFACTORY_PASSWORD="Passw0rd123!"
export IMAGE_SRC="quay.io/kmoini/infinite_mario:latest"

# Log in to the registry
sudo podman login --tls-verify=false -u ${ARTIFACTORY_USER} -p "${ARTIFACTORY_PASSWORD}" "${ARTIFACTORY_URL}"

# Pull the upstream image src
sudo podman pull --tls-verify=false "${IMAGE_SRC}"

# Tag pivot & push
sudo podman tag --tls-verify=false ${IMAGE_SRC} "${ARTIFACTORY_URL}/mirror-test/mario:latest"
sudo podman push --tls-verify=false "${ARTIFACTORY_URL}/mirror-test/mario:latest"
```

## Mirroring OpenShift Releases

In the parent folder, you can find a `oc-mirror` directory with some Ansible Automation that will perform the mirroring functions for you; you can do this via the CLI or via Ansible Tower/Controller with the included custom Runner container.

### CLI

```bash
ansible-playbook mirror.yml \
 -e privateRegistryUser="admin" \
 -e privateRegistryPassword='Passw0rd123!' \
 -e privateRegistryURL="jfrog-artifactory.d70.lab.kemo.network" \
 -e storageRegistryImageURL="jfrog-artifactory.d70.lab.kemo.network/ocp4/oc-mirror-metadata"
```

## Delete FCOS VM from vSphere

```bash
ansible-playbook -e "@vars.yml" 9_destroy.yml
```