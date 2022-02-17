#!/bin/bash 
if [ -z $1 ];
then 
  echo "Enter Cluster name"
  echo "Example $0 sno-ocp"
  exit 1
fi 

CLUSTER_NAME=${1}

git pull 
rm -rf ztp-clusters/vsphere/sno/${CLUSTER_NAME}
git add  ztp-clusters/vsphere/sno/${CLUSTER_NAME}
git commit -m "cleanup ${CLUSTER_NAME}"
git push 