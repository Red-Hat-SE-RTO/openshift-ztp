# ZTP Mirror

ztp-mirror is a container that has a simple Python application that will read out a list of files from a JSON file, download them to the specified folder, and then serve them up via HTTP.

## Building the Container

```bash
podman build -t ztp-mirror .
```

## Running the Container

```bash
podman run --rm -p 8080:8080 --name ztp-mirror ztp-mirror
```

or from Quay

```bash
podman run --rm -p 8080:8080 --name ztp-mirror quay.io/kenmoini/http-mirror:latest
```

## Deploying to OpenShift

Use the files in the `deploy` directory to deploy to OpenShift

```bash
oc new-project ztp-mirror

oc apply -f deploy/
```

### Configuring the HTTP Proxy and Root CA Bundle

For configuring the custom root CA bundle, all you need to do is uncomment the configmap volume mount in the Deployment YAML.

For the HTTP Proxy, you'll need to set some variables - get the needed variables from the cluster with the following commands:

```bash
oc get proxy -o json | jq -r '.items[0].status.httpProxy'

oc get proxy -o json | jq -r '.items[0].status.httpsProxy'

oc get proxy -o json | jq -r '.items[0].status.noProxy'
```

Then plug them in where they need to be in the Deployment JSON and uncomment the lines.