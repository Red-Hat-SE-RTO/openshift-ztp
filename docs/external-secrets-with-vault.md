# External Secrets with Hashicorp Vault

Each Spoke Cluster deployment needs access to a set of Credentials for Ansible Tower and vSphere.  Instead of managing those credentials for each individual cluster, you can manage them with a Vault and simply reference them as ExternalSecrets.

1. Install Helm on the Local System
2. Add Helm Repos for Hashicorp Vault, Emberstack, and External-Secrets
3. Install Hashicorp Vault
4. Install External-Secrets
5. Install Reflector
5. Initialize and Unseal the Vault
6. Integrate Vault with Kubernetes/OpenShift to allow ServiceAccount tokens to access Vault
7. Configure a SecretStore and Secret pair for External-Secrets to access Vault

## Installing Helm

The following components are installed with Helm and need the `helm` binary available on the system.

```bash
## Create a temporary directory to work in
mkdir -p /tmp/helmsetup
cd /tmp/helmsetup

## Download Helm CLI
wget https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz

## Extract the tar.gz archive
tar zxvf helm-v3.7.2-linux-amd64.tar.gz

## Give executable permissions
chmod a+x helm

## Move to system PATH
sudo mv helm /usr/local/bin

## Cleanup
cd /
rm -rf /tmp/helmsetup
```

## Installing Hashicorp Vault

Hashicorp Vault is a multi-backend secret storage application that's great for managing things like Key/Value Paired Secrets.

```bash
## Add the Hashicorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com

## Update Helm
helm repo update

## Create/switch to a new namespace for Vault
oc new-project hashicorp-vault

## Deploy the Vault Helm Chart
helm install vault hashicorp/vault \
  --namespace hashicorp-vault \
  --set "global.openshift=true" \
  --set "server.dev.enabled=false"
```

## Installing External Secrets

External Secrets is a GoDaddy project and can easily be installed to an OpenShift Hub cluster with Helm.

```bash
## Add the external secrets Helm repo
helm repo add external-secrets https://charts.external-secrets.io

## Update Helm repos
helm repo update

## Create/switch to a new namespace for external-secrets
oc new-project external-secrets

## Install the Helm chart
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --set "prometheus.enabled=true"
```

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
helm install reflector emberstack/reflector \
  --namespace reflector
```

## Initialize Vault

Vault comes in a sealed state that locks it down so you need to initialize/unseal the Vault deployment.

This is done once when freshly deployed:

```bash
## Switch to the vault project
oc project hashicorp-vault

## Initialize the Vault
oc exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1

## Take note of the Vault Key and Root Token!

## Unseal with the Vault Key
oc exec -it vault-0 -- vault operator unseal "$KEY"

## Log in to Vault with the Root Token
oc exec -it vault-0 -- vault login "${ROOT_TOKEN}"

## Enable K8s authentication provider in Vault
oc exec -it vault-0 -- vault auth enable kubernetes

## Enable key/value Secrets Engine
oc exec -it vault-0 -- vault secrets enable -version=2 kv
oc exec -it vault-0 -- vault secrets enable -version=2 -path secrets kv

### Enable Vault PKI Secrets Engine
oc exec -it vault-0 -- vault secrets enable pki

### Configure a 10yr max lease time for PKI
oc exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki

## Set the Policy ACLs
oc exec -it vault-0 -- vault policy write secrets - <<EOF
path "pki*"    { capabilities = ["create", "read", "list"] }
path "secrets*" { capabilities = [ "create", "read", "update", "delete", "list", "patch" ] }
path "kv*" { capabilities = [ "create", "read", "update", "delete", "list", "patch" ] }
path "sys/mounts/*" { capabilities = [ "create", "read", "update", "delete" ] }
EOF

## Enable secrets versioning
oc exec -it vault-0 -- vault kv enable-versioning secrets

## Create a test secret at foo
oc exec -it vault-0 -- vault kv put secrets/foo my-value=s3cr3t

## Create a tiered secret
oc exec -it vault-0 -- vault kv put secrets/customer/acme name="ACME Inc." contact_email="jsmith@acme.com"
```

## Integrate Vault and Kubernetes/OpenShift

This step will allow Vault to authenticate/authorize requests from services/users in OpenShift that are leveraging the built-in OpenShift OAuth Bearer Tokens via the cert-manager Vault Issuer.

```bash
## Switch to Vault namespace/project
oc project hashicorp-vault

## Exec into Vault Pod
oc exec -it vault-0 -- /bin/sh

## Enable k8s authentication mechanism - this must be done in the vault pod in order to get the right ENV VARs
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  issuer="https://kubernetes.default.svc.cluster.local"

## Set Vault issuer role
vault write auth/kubernetes/role/issuer \
  bound_service_account_names="*" \
  bound_service_account_namespaces="*" \
  policies=pki \
  ttl=20m
```

## Deploying a Route for the Vault UI

```bash
## Create the Route
cat <<EOF | oc create -f -
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: vault-ui
  namespace: hashicorp-vault
spec:
  to:
    kind: Service
    name: vault
    weight: 100
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
EOF

## Get the Route URL
VAULT_UI_ROUTE="https://$(oc get route vault-ui --output=jsonpath='{.status.ingress[0].host}')"
echo $VAULT_UI_ROUTE

## Use the Token from earlier to log in
```

## Create a SecretStore for External Secrets to communicate with Vault

```bash
## Switch to the external-secrets project
oc project external-secrets

## Create the SecretStore
cat <<EOF | oc apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: external-secrets
spec:
  provider:
    vault:
      server: "http://vault.hashicorp-vault:8200"
      path: "secrets"
      version: "v2"
      auth:
        # points to a secret that contains a vault token
        # https://www.vaultproject.io/docs/auth/token
        tokenSecretRef:
          name: "vault-token"
          namespace: "external-secrets"
          key: "token"
EOF

## Create the Vault Token Secret
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: external-secrets
stringData:
  token: "someVaultToken"
EOF
```

```bash
cat <<EOF | oc apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
metadata:
  name: vault-example-ext
  namespace: external-secrets
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: vault-backend
    namespace: external-secrets
    kind: SecretStore
  target:
    name: example-sync
    namespace: ansible-automation-platform
  data:
  - secretKey: foobar
    remoteRef:
      key: secrets/foo
      property: my-value
EOF
```

## Configure the Key Value Secret Store in Vault

Add extra secrets as such:

```bash
## Create vCenter Credentials
oc exec -it vault-0 -- vault kv put secrets/rdu-vcenter \
 vcenter_validate_ssl="true" \
 vcenter_fqdn="vcenter.example.com" \
 vcenter_username="administrator@vsphere.local" \
 vcenter_password="secr3t"

## Create Ansible Tower Credentials
oc exec -it vault-0 -- vault kv put secrets/ansible-tower \
 host="ac-tower-ansible-automation-platform.apps.core-ocp.lab.kemo.network" \
 token="someString"
```

## Per Namespace Secret Syncing



```yaml
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: ansible-automation-platform
spec:
  provider:
    vault:
      server: "http://vault.hashicorp-vault:8200"
      path: "secrets"
      version: "v2"
      auth:
        # points to a secret that contains a vault token
        # https://www.vaultproject.io/docs/auth/token
        tokenSecretRef:
          name: "vault-token"
          namespace: "external-secrets"
          key: "token"
```