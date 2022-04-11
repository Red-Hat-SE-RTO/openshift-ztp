#!/bin/bash 
if (( $# != 2 ));
then 
  echo "Enter Cluster name"
  echo "Example $0 sno sno-ocp"
  echo "Example $0 converged converged-ocp"
  echo "Example $0 full full-ocp"
  exit 1
fi 


CLUSTER_TYPE=${1}
CLUSTER_NAME=${2}

git pull 
rm -rf ztp-clusters/vsphere/${CLUSTER_TYPE}/${CLUSTER_NAME}
git add  ztp-clusters/vsphere/${CLUSTER_TYPE}/${CLUSTER_NAME}
git commit -m "cleanup ${CLUSTER_NAME}"
git push 

oc delete  Application ${CLUSTER_NAME} -n argocd
oc delete project ${CLUSTER_NAME}