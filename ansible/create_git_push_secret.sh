#!/bin/bash

read -p "Enter Git repo 'Default: git@github.com:Red-Hat-SE-RTO/openshift-ztp.git' > " GIT_REPO
[[ -z "$GIT_REPO" ]] && GIT_REPO="git@github.com:Red-Hat-SE-RTO/openshift-ztp.git" 
#echo "${GIT_REPO}"

read -p "Enter Git repo branch 'Default: main' > " GIT_BRANCH
[[ -z "$GIT_BRANCH" ]] && GIT_BRANCH="main" 
#echo "${GIT_BRANCH}"

read -p "Enter default auth method ssh or https 'Default: ssh' > " GIT_AUTH_METHOD
[[ -z "$GIT_AUTH_METHOD" ]] && GIT_AUTH_METHOD="ssh" 
#echo "${GIT_AUTH_METHOD}"


read -p "Enter username for Git  for Git Commit/Push Events 'Default: username'  > " GIT_USER_NAME
[[ -z "$GIT_USER_NAME" ]] && GIT_USER_NAME="username" 
#echo "${GIT_USER_NAME}"

read -p "Enter Git email for Git Commit/Push Events  'Default: username@example.com'> " GIT_USER_EMAIL
[[ -z "$GIT_USER_EMAIL" ]] && GIT_USER_EMAIL="username@example.com" 
#echo "${GIT_USER_EMAIL}"

read -p "Enter Git username for login 'Default: git'> " GIT_USERNAME
[[ -z "$GIT_USERNAME" ]] && GIT_USERNAME="git"
#echo "${GIT_USERNAME}"

read -p "Enter Git password for for login  'Default: empty'> " GIT_PASSWORD
[[ -z "$GIT_PASSWORD" ]] && GIT_PASSWORD=""
#echo "${GIT_PASSWORD}"

read -p "Enter git secert credentials name 'Default: ztp-git-push-credentials'> " GIT_CREDENTIALS_SECRET_NAME
[[ -z "$GIT_CREDENTIALS_SECRET_NAME" ]] && GIT_CREDENTIALS_SECRET_NAME="ztp-git-push-credentials"
#echo "${GIT_CREDENTIALS_SECRET_NAME}"

read -p "Enter OpenShift secret namespace for git credentials  'Default: ztp-credentials'> " GIT_CREDENTIALS_SECRET_NAMESPACE
[[ -z "$GIT_CREDENTIALS_SECRET_NAMESPACE" ]] && GIT_CREDENTIALS_SECRET_NAMESPACE="ztp-credentials"
#echo "${GIT_CREDENTIALS_SECRET_NAMESPACE}"

if [[ $GIT_AUTH_METHOD == "ssh" ]];
then 
  read -p "Enter ssh key location Default: $HOME/.ssh/id_rsa > " GIT_SSH_KEY
  [[ -z "$GIT_SSH_KEY" ]] && GIT_SSH_KEY="$HOME/.ssh/id_rsa" 
  echo "${GIT_SSH_KEY}"

  cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${GIT_CREDENTIALS_SECRET_NAME}
  namespace: ${GIT_CREDENTIALS_SECRET_NAMESPACE}
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  git_url: "${GIT_REPO}"
  git_branch: "${GIT_BRANCH}"
  git_auth_method: "${GIT_AUTH_METHOD}"
  git_username: "${GIT_USERNAME}"
  git_password: "${GIT_PASSWORD}"
  git_user_name: "${GIT_USER_NAME}"
  git_user_email: "${GIT_USER_EMAIL}"
  git_ssh_key: |
$(cat $GIT_SSH_KEY | awk '{printf "      %s\n", $0}')
EOF
elif [ $GIT_AUTH_METHOD == "https" ];
then 
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${GIT_CREDENTIALS_SECRET_NAME}
  namespace: ${GIT_CREDENTIALS_SECRET_NAMESPACE}
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
type: Opaque
stringData:
  git_url: "${GIT_REPO}"
  git_branch: "${GIT_BRANCH}"
  git_auth_method: "${GIT_AUTH_METHOD}"
  git_username: "${GIT_USERNAME}"
  git_password: "${GIT_PASSWORD}"
  git_user_name: "${GIT_USER_NAME}"
  git_user_email: "${GIT_USER_EMAIL}"
EOF
else
  echo "Default auth method  not found please enter ssh/https in menu"
  exit 
fi 