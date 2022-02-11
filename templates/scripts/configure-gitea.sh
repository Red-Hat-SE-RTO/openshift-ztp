#!/bin/bash 
source shared_functions.sh

## Configure Gitea repo on OpenShift 
PROJECT="gpte-deployment"
SET_PRIVATE_REPO=true
GITEA_PASSWORD="openshift"


oc new-project ${PROJECT} --display-name="Gitea Deployment"
oc apply -f https://raw.githubusercontent.com/redhat-gpte-devopsautomation/gitea-operator/master/catalog_source.yaml

cat >/tmp/gitea-with-admin.yaml<<YAML
apiVersion: gpte.opentlc.com/v1
kind: Gitea
metadata:
  name: gitea
spec:
  giteaSsl: true
  giteaAdminUser: adminuser
  giteaAdminPassword: ""
  giteaAdminPasswordLength: 32
  giteaAdminEmail: adminuser@example.com
  giteaCreateUsers: true
  giteaGenerateUserFormat: "user-%d"
  giteaUserNumber: 1
  giteaUserPassword: ${GITEA_PASSWORD}
  giteaMigrateRepositories: true
  giteaRepositoriesList:
  - repo: https://github.com/Red-Hat-SE-RTO/openshift-ztp.git
    name: openshift-ztp
    private: ${SET_PRIVATE_REPO}
YAML

oc create -f /tmp/gitea-with-admin.yaml

POSTGRESS_POD=$(oc get pods -n ${PROJECT} | grep postgresql-gitea- | awk '{print $1}')
waitforme $POSTGRESS_POD  ${PROJECT} 

GITEA_POD=$(oc get pods -n ${PROJECT} | grep gitea- | awk '{print $1}')
waitforme $GITEA_POD  ${PROJECT} 

URL="https://$(oc get route -n  ${PROJECT} |  grep -v NAME | awk '{print $2}')/user-1/openshift-ztp.git"
echo "GITEA URL: ${URL}"
echo "export GIT_REPO="${URL}""
echo "GITEA PASSWORD: ${GITEA_PASSWORD}"