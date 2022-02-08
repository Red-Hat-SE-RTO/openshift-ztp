# Credential Setup

For every vSphere or Ansible Tower environment, the Hub OpenShift cluster needs a few Secrets accessible to the different Namespaces.

The easiest way to do this is to create a set of Secrets from stringData manually to a set of namespaces, and have Reflector mirror it into the Spoke Cluster namespaces.

# Hub Cluster Initial Configuration

## Install Reflector

Reflector will sync ConfigMaps and Secrets to multiple Namespaces.

```bash
## Add emberstack repo 
helm repo add emberstack https://emberstack.github.io/helm-charts

## Update Helm repos
helm repo update

## Create a reflector project
oc new-project reflector

## Install the Helm chart
helm upgrade --install reflector emberstack/reflector --namespace reflector

## Add SCC to SA RBAC
oc adm policy add-scc-to-user privileged -z default -n reflector
oc adm policy add-scc-to-user privileged -z reflector -n reflector
```

## Create Credentials Namespace

```bash
## Create a shared ZTP credential namespace
oc new-project ztp-credentials
```

## Create an Ansible Tower Credential

```bash
## Get AAP2 Controller/Tower Route
AAP_ROUTE="$(echo "https://$(oc get -n ansible-automation-platform route/ac-tower -o jsonpath='{.spec.host}')")"

## Set your Tower Token
ANSIBLE_TOWER_TOKEN="someLongString"

## Create the Ansible Tower Credential
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: ansible-tower-credentials
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  host: $AAP_ROUTE
  token: $ANSIBLE_TOWER_TOKEN
EOF
```

## Create a vCenter Credential

```bash
## Set the vCenter Connection Details
VCENTER_FQDN="vcenter.example.com"
VCENTER_USERNAME="administrator@vsphere.local"
VCENTER_PASSWORD="someString"

## Create the vSphere Credential
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: loe-rdu-vcenter-credentials
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  vcenter_fqdn: $VCENTER_FQDN
  vcenter_username: $VCENTER_USERNAME
  vcenter_password: $VCENTER_PASSWORD
  skip_ssl_validation: "true"
EOF
```

## Create a Pull Secret

```bash
## Set the Pull Secret Path
PULL_SECRET_PATH="/opt/rh-ocp-pull-secret.json"

cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: assisted-deployment-pull-secret
  namespace: ztp-credentials
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  .dockerconfigjson: '$(cat ${PULL_SECRET_PATH})'
EOF
```

# Per Spoke Secret Setup

With Reflector installed, you can copy Secrets simply:

```bash
CLUSTER_NAME="sno-ocp"
VCENTER_DATACENTER="LabDC"
VCENTER_CLUSTER="LabCluster"

## Create the Pull Secret
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: assisted-deployment-pull-secret
  namespace: ${CLUSTER_NAME}
  annotations:
    reflector.v1.k8s.emberstack.com/reflects: "ztp-credentials/assisted-deployment-pull-secret"
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
data:
EOF

## Create the vSphere Credential
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: loe-rdu-vcenter-credentials
  namespace: ${CLUSTER_NAME}
  annotations:
    reflector.v1.k8s.emberstack.com/reflects: "ztp-credentials/loe-rdu-vcenter-credentials"
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
data:
EOF

## Create the Ansible Tower Credential
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: ansible-tower-credentials
  namespace: ${CLUSTER_NAME}
  annotations:
    reflector.v1.k8s.emberstack.com/reflects: "ztp-credentials/ansible-tower-credentials"
  labels:
    name: '${CLUSTER_NAME}'
    cloud: vSphere
    vendor: OpenShift
    datacenter: '${VCENTER_DATACENTER}'
    cluster: '${VCENTER_CLUSTER}'
    cluster-name: '${CLUSTER_NAME}'
data:
```