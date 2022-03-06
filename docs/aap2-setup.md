# Ansible Automation Platform 2, Controller/Tower Setup

Ansible provides the infrastructure automation needed for this ZTP to vSphere process.

Perform the following actions as a user with cluster-admin privileges:

```bash
## Assuming you're in the cloned repo root folder
OCP_VERSION="4.9"

##  Switch to ansible-automation-platform
oc project ansible-automation-platform\

## Create a Gitea Operator instance
oc apply -f ./hub-applications/${OCP_VERSION}/operator-instances/aap-operator/03_tower_controller_instance.yml
```


Deploy an Ansible Controller/Tower via AAP2 on OpenShift and do the following:

1. Find the Admin password: `oc get secret/ac-tower-admin-password -n ansible-automation-platform -o jsonpath='{.data.password}' | echo "$(base64 -d)"`
2. Log into the AAP2 Controller/Tower: `echo "https://$(oc get -n ansible-automation-platform route/ac-tower -o jsonpath='{.spec.host}')"`
3. Attach a Subscription to Tower
4. Create an **Application**, 'Resource owner password-based' Authorization grant type, 'Confidential' Client type
5. Create a **User Personal Access Token** with that Application, take note of the Token
6. Create SCM **Credentials** to access the ZTP Git repo
7. Create a **Project** to the ZTP Git repo
8. Create an **Inventory**, localhost being the only host with explicit locality via `ansible_connection=local` and  `ansible_python_interpreter: '{{ ansible_playbook_python }}'` in the host inventory variables.
9. Create a **Job Template**, allow for extra variables to be passed in
10. Give the default ServiceAccount in the ansible-automation-platform Namespace cluster-admin permissions: `oc adm policy add-cluster-role-to-user cluster-admin -z default -n ansible-automation-platform`

***Note***: Save/Verify ./aap2_user_application_token for future use.  
***Note***: You don't need to give the default SA full cluster-admin permissions, just enough RBAC to allow listing/viewing of Secrets in a few namespaces, but this is easier for testing.  Production workloads will want to set proper Roles and RoleBindings.