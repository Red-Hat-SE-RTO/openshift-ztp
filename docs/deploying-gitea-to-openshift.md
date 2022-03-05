# Deploying Gitea to OpenShift

For ZTP to work you'll need a Git repository - this is easily done via Gitea and the Operator Framework.

Perform the following actions as a user with cluster-admin privileges:

```bash
## Assuming you're in the cloned repo root folder
OCP_VERSION="4.9"

## Create new project 
oc new-project gitea

## Install the Operator CatalogSource
oc apply -f ./hub-applications/${OCP_VERSION}/operator-catalogs/rh-gpte-gitea-catalogsource.yml

## Wait a few seconds...
sleep 10

## Install the Operator
oc apply -f ./hub-applications/${OCP_VERSION}/operator-subscriptions/gitea-operator/

## Wait a few more seconds...
sleep 10

## Create a Gitea Operator instance
oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/gitea-operator/
```

The default username/password will be `opentlc-mgr` and `r3dh4t123!`