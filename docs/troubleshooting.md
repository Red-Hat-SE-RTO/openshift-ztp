# Troubleshooting

There are a lot of moving pieces and parts to ZTP, adding additional automation and functions to it increases its complexity even more so.  Here are some common issues you may run into, where to look to debug, and how to fix them.

- **AnsibleJob does not start the Automation Job Pods**

  In case the AnsibleJob does not start, there could be a few places it could have caught a snag.
  - Check to make sure the AAP2 Operator was installed in cluster-scoped mode.
  - Check to make sure the AAP2 Controller has RBAC permissions to access the AnsibleJob CRs, Secrets, ConfigMaps, and Jobs/Pods in the spoke cluster namespaces.
  - Check the `resource-operator-controller-manager` Pod logs in the `ansible-automation-platform` namespace.  Make sure to switch from the `kube-rbac-proxy` to the `platform-resource-manager` container!
  - Check the AnsibleJob CR for the `.status` field and the associated conditions.  If you see `Tower Secret must exist` then the Secret does not exist or the `platform-resource-manager` Pod cannot access it.
  - If you check the AnsibleJob CR and the status says:
    ```
    The task includes an option with an undefined variable. The error was:
    'dict object' has no attribute 'data'

    The error appears to be in '/opt/ansible/roles/job/tasks/main.yml': line
    102, column 3, but may

    be elsewhere in the file depending on the exact syntax problem.

    The offending line appears to be:

    - name: Start K8s Runner Job
      ^ here
    ```
    ...then the supplied Secret was found but is likely empty.  Check the tower_auth_secret Secret and make sure the data is there - there have been events where something like Reflector was not running and the Secret was not populated.


- **Reflector is not copying ConfigMaps and Secrets around the cluster**

  This is likely either due to the Pod not starting, or Reflector not having enough RBAC permissions to CRUD the ConfigMaps and Secrets from one Namespace to another.

- **The Deploy to vSphere Playbook/Template is failing when attempting to download the Discovery ISO**

  This is likely due to a configuration issue with either the AgentClusterInstall, InfraEnv, or an NMState CR.  Check the `.status` fields for those CRs, starting with the InfraEnv since that is what generates and provides the Discovery ISO.