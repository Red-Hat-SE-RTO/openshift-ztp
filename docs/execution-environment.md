# Ansible Automation Platform 2 Execution Environment

One of the bigger changes in AAP2 is the Execution Environment - basically it's just an ephemeral container that runs the Playbook/Template/Job.

In some environments it's easier to create your own Execution Environment and use it to run your Playbook/Template/Job without needing additional AAP2 Controller/Tower specific preflight such as installing packages and pip modules.

An example Dockerfile:

```Dockerfile
FROM registry.redhat.io/ansible-automation-platform-21/ee-supported-rhel8:1.0.1-72

RUN microdnf update -y
RUN microdnf install git -y

RUN python3 -m pip install --upgrade --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org openshift kubernetes pyvmomi jmespath PyYAML jsonpatch
```