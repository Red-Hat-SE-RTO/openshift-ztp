# oc-mirror Quickstart

The `oc-mirror` binary is a tool that quickly allows mirroring of OpenShift releases, Operators, and such similar content to another registry, or a tar to be sneakernetted over to a disconnected network.

This document will guide you through using it with JFrog's Artifactory/Container Registry by setting up those resources, downloading and running `oc-mirror`, and modifications you need to make to the ZTP processes.

## JFrog Setup

- If you need a JFrog server on vSphere, see the `extras/jfrog-fcos-vsphere` directory for Ansible Automation that will deploy the latest JFrog to a Fedora CoreOS OVA, fronted by HAProxy and an optional SSL certificate.

1. Log in to JFrog, do set up if needed
   1. Create group called `mirrorusers`
   2. Create a new Permission called `WriteRepos` - give that Permissions definition the ability to do things with Repositories
   3. Associate the `mirrorusers` Group to the `WriteRepos` Permission
   4. Create a User called `ocpmirror` and add it to the `mirrorusers` Group
   5. Create an Access Token for that User
2. Create a new Local Repository, Docker type, call it `ocp4`, uncheck the box for "Block pushing of image manifest v2 schema 1"

## oc-mirror Usage

1. Download the `oc-mirror` binary:

```bash
# Make a temporary directory
mkdir ~/tmpdl && cd ~/tmpdl

# Clone the repo
git clone https://github.com/openshift/oc-mirror.git

cd oc-mirror

# Make the executable
make build

sudo mv ./bin/oc-mirror /usr/bin

# Clean up
cd - && rm -rf ~/tmpdl
```

2. Create an ImageSetConfiguration file called `~/isc.yml`:

```yaml
apiVersion: mirror.openshift.io/v1alpha2
kind: ImageSetConfiguration
storageConfig:
  registry:
    imageURL: jfrog-artifactory.d70.lab.kemo.network/ocp4/mirror-metadata:latest
    skipTLS: true
mirror:
  platform:
    architectures:
      - "amd64" # Architectures to mirror for the collection of release versions (defaults to amd64)
    channels:
      - name: stable-4.10 # References latest stable release
    graph: true # Include Cincinnati upgrade graph image in imageset
  operators:
    - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.10 # References entire catalog
      full: false # full can be set to pull a full catalog and must be set to filter packages
      packages:
        - name: rhacs-operator
          minVersion: '3.67.0'
          channels:
            - name: 'latest'
  additionalImages: # List of additional images to be included in imageset
    - name: registry.redhat.io/ubi8/ubi:latest
  helm:
    repositories:
      - name: emberstack
        url: https://emberstack.github.io/helm-charts
        charts:
          - name: reflector
```

3. Get a Pull Secret from the Red Hat Hybrid Cloud Console: https://console.redhat.com/openshift/downloads
4. Create a `~/rh-pull-secret.json` file with the contents of the Pull Secret
5. Create a directory for "docker" `mkdir ~/.docker`
6. Make it human readable and add it to the right place for `oc-mirror`: `cat ~/rh-pull-secret.json | python3 -m json.tool > ~/.docker/config.json`
7. Add your JFrog Login information to the `~/
8. Run a connection test: `oc-mirror --config ~/isc.yml list updates`


9. Mirror the repos locally: `oc-mirror --dest-skip-tls --continue-on-error --skip-missing --config ~/isc.yml file://ocpmirror`
10. Mirror to JFrog: `oc-mirror --dest-skip-tls file://ocpmirror docker://jfrog-artifactory.d70.lab.kemo.network`
11. Mirror the repos locally: `oc-mirror --dest-skip-tls --continue-on-error --skip-missing --config ~/isc.yml docker://jfrog-artifactory.d70.lab.kemo.network/ocp4`