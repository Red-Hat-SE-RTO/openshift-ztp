#!/bin/bash

GIT_REPO="git@github.com:kenmoini/openshift-ztp.git"
GIT_BRANCH="main"

GIT_AUTH_METHOD="ssh"
GIT_SSH_KEY="$HOME/.ssh/id_rsa"
GIT_USERNAME="git"
GIT_PASSWORD=""

GIT_CREDENTIALS_SECRET_NAME="ztp-git-push-credentials"
GIT_CREDENTIALS_SECRET_NAMESPACE="ztp-credentials"

cat <<EOF | oc create -f -
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
  git_ssh_key: "$(cat ${GIT_SSH_KEY})"
  git_username: "${GIT_USERNAME}"
  git_password: "${GIT_PASSWORD}"
EOF