# Proxy & Root CA Configuration

There are a few places and a few ways to configure the Outbound Proxy and Root CAs on the Hub Cluster, in the Spoke Cluster Manifests, Spoke Clusters themselves, and in the Ansible Jobs that are run.

## General OpenShift Considerations

- Your `noProxy` needs to have:
  - .svc
  - .svc.cluster.local
  - .{{ cluster_name }}.{{ cluster_domain }}

## Hub Cluster

If your Hub Cluster needs to use a Proxy, it is expected that it is configured at the Cluster Settings for the Proxy - otherwise it will not be enabled in many of the workloads such as Red Hat Advanced Cluster Management, Red Hat GitOps/ArgoCD, Gitea, and so on.

Learn how to configure the cluster-wide proxy here: https://docs.openshift.com/container-platform/4.10/networking/enable-cluster-wide-proxy.html

- When deploying workloads and configuring them on the Hub Cluster, the consumption of cluster-wide proxy settings is automatically set.
  This means when you run `ansible-playbook 1_deploy.yaml`, RHACM, Gitea, and so on will automatically use the cluster-wide proxy settings.
  This also means that when you run `ansible-playbook 2_configure.yaml`, the configuration of RHACM's OAS, AAP2, and ArgoCD will automatically use the cluster-wide proxy settings!

- When running the AAP2 AnsibleJobs/Ansible Jobs on the Hub Cluster, you will need to pass along some proxy configuration if the ephemeral Execution Environment/Runner is needing to use a proxy to connect to resources.

---

## Ansible Jobs

AAP2 has some proxy configuration that is automatically set on Controller/Tower instance but not every part of the execution chain consumes those settings: https://github.com/ansible/awx-resource-operator/issues/69

### Creating Credentials in AAP2 `3_create_credentials.yaml`

If you're running the `create-credentials` Job in the AAP2 Web UI, you will need to set the `http_proxy`, `https_proxy`, and `no_proxy` as extra variables in the `extra_vars` section of the Job.

These are passed onto the Playbook's Tasks running in the Execution Environment.

```yaml
## These are consumed by the AnsibleJob Pod's Ansible Playbook
http_proxy: 'http://192.168.51.1:3128/'
https_proxy: 'http://192.168.51.1:3128/'
no_proxy: ".cluster.local,.svc,.svc.cluster.local,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.51.0/24,api-int.core-ocp.lab.kemo.network,api.core-ocp.lab.kemo.network,localhost,127.0.0.1,.apps.core-ocp.lab.kemo.network"
```

### AnsibleJob Custom Resources Proxy and Root CA - `create_spoke_manifests.yml`

Part of this ZTP to vSphere automation workflow uses AnsibleJob Custom Resources provided by the AAP2 Operator.

Unfortunately, the container that this is run in is called a "Runner" and uses a different type of image and currently does not have any mechanism to mount volumes for configuration for things such as a proxy or Root CA ConfigMap.  This means that you must build a custom Runner image with any needed Root CAs injected and specify the customer image when running the `create_spoke_manifests.yml` Playbook with:

```yaml
ansible_job_runner_image: quay.io/kenmoini/aap2-rooted-runner
ansible_job_runner_image_version: latest
```

There is an example of a Dockerfile for a container like this in the `ansible/runners/add-root-ca-bundle/` directory.  You can use this as a starting point for your own custom Runner image.

### SSL MITM'ing - `create_spoke_manifests.yml`

In addition to using a custom Runner with your Root CA if your Proxy uses SSL Re-encryption with a custom Root CA(s), you will need to pass the `create_spoke_manifests.yml` Playbook the following variables:

```yaml
## These are consumed by the AnsibleJob Pod's Ansible Playbook
http_proxy: 'http://192.168.51.1:3128/'
https_proxy: 'http://192.168.51.1:3128/'
no_proxy: ".cluster.local,.svc,.svc.cluster.local,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.51.0/24,api-int.core-ocp.lab.kemo.network,api.core-ocp.lab.kemo.network,localhost,127.0.0.1,.apps.core-ocp.lab.kemo.network"

## Spoke Proxy Configuration
spoke_httpproxy: "http://192.168.77.1:3128/"
# spoke_httpsproxy -  A proxy URL to use for creating HTTPS connections outside the cluster. If you use an MITM transparent proxy network that does not require additional proxy configuration but requires additional CAs, you must not specify an httpsProxy value.
#spoke_httpsproxy: "http://192.168.77.1:3128/"
spoke_noproxy: ".svc.cluster.local,.cluster.local,.svc,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.51.0/24,api-int.{{ cluster_name }}.{{ base_domain }},api.{{ cluster_name }}.{{ base_domain }},localhost,.apps.{{ cluster_name }}.{{ base_domain }},localhost,127.0.0.1"
```

---

## Proxy Configuration for Spoke Clusters

- The only place Proxy Configuration should be set is on the `AgentClusterInstall` - do not set it twice via install-config overrides or the InfraEnv, multiple proxy definitions will cause problems.
- Pass along some extra variables to the `create_spoke_manifests.yml` Playbook as the `spoke_httpproxy`, `spoke_httpsproxy`, and `spoke_noproxy` variables.  This will embed it in the needed places for the Spoke Cluster to consume.

## Root CA for the Spoke Clusters

- You can pass along an additional Root CA Bundle to the Spoke Clusters to consume - handy when you're doing SSL reencryption with a custom Root CA.
- This is done via the `ClusterDeployment` CR via `.spec.certificateBundles` this is a list of SecretRefs, ie

```yaml
spec:
  certificateBundles:
    - name: {{ root_ca_secret_name }}
      certificateSecretRef:
        name: {{ root_ca_secret_name }}
```

Where the Secret has a `.data.tls-ca-bundle.pem` key that contains the custom Root CA Bundle.

---

## Additional Reading

- https://www.ibm.com/docs/en/zcxrhos/1.1.0?topic=installation-procedure
- https://docs.openshift.com/container-platform/4.10/networking/enable-cluster-wide-proxy.html
- https://docs.openshift.com/container-platform/4.10/networking/configuring-a-custom-pki.html
- https://github.com/openshift/assisted-service/tree/master/docs/hive-integration
- https://github.com/wangjun1974/tips/blob/9ba0154b44cdf2da6e7d71b6ed691edb9ec52a67/ocp/assisted-installer-on-premise.md
- https://docs.google.com/document/d/1JN_KHsBpBk6vrf_aQjP9-vpmwODM5WcoJm18-k0Ofb4/edit#heading=h.sacp69wt8jj4