#!/bin/bash

set -e

################################################################################
## Ansible Automation Platform 2 Setup Script
##
## This script will configure an AAP2 Controller/Tower instance running in
## OpenShift to be ready for use in a ZTP workflow with vSphere.
################################################################################

## AAP2 DEPLOYMENT VARIABLES
AAP2_NAMESPACE="ansible-automation-platform"
AAP2_CONTROLLER_NAME="ac-tower"
AAP2_ADMIN_SECRET_NAME="${AAP2_CONTROLLER_NAME}-admin-password"
AAP2_CONTROLLER_ROUTE_NAME="${AAP2_CONTROLLER_NAME}"

## AAP2 DEPLOYMENT OBJECTS
AAP2_CONTROLLER_ROUTE=$(oc get route ${AAP2_CONTROLLER_ROUTE_NAME} -n ${AAP2_NAMESPACE} -o jsonpath='{.spec.host}')
AAP2_ADMIN_PASSWORD=$(oc get secret ${AAP2_ADMIN_SECRET_NAME} -n ${AAP2_NAMESPACE} -o jsonpath='{.data.password}' | base64 -d)

## AAP2 DEPLOYMENT CONFIGURATION
ORGANIZATION="Default"
INVENTORY_NAME="localhost-ee"

SCM_CREDENTIAL_AUTH_TYPE="ssh" # ssh or basic
SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
SCM_CREDENTIAL_USERNAME="your-username"
SCM_CREDENTIAL_PASSWORD="your-password"
SCM_CREDENTIAL_NAME="SCM Credentials"

PROJECT_NAME="vSphere ZTP"
## GIT_REPO SHOULD BE MODIFIED TO POINT TO YOUR GIT REPO FORK OF https://github.com/Red-Hat-SE-RTO/openshift-ztp
GIT_REPO=${GIT_REPO:="git@github.com:kenmoini/openshift-ztp.git"}

JOB_TEMPLATE_NAME="vsphere-infra-ztp"
JOB_TEMPLATE_PLAYBOOK="ansible/deploy_to_vsphere.yml"

APPLICATION_NAME="ZTP RHACM"

SCM_CREDENTIAL_PRIVATE_KEY="$(sed -z 's|\n|\\n|g' ${SSH_PRIVATE_KEY_PATH})"

################################################################################
## PREFLIGHT
echo "===== ADMIN PASSWORD: ${AAP2_ADMIN_PASSWORD}"

## Get OAuth2 token
AAP2_OAUTH_TOKEN=$(curl -sSk -u admin:${AAP2_ADMIN_PASSWORD} -H 'Content-Type: application/json' -X POST https://${AAP2_CONTROLLER_ROUTE}/api/v2/tokens/ | jq -r .token)
echo "===== OAUTH2 TOKEN: ${AAP2_OAUTH_TOKEN}"

## Get Organization ID
AAP2_ORGANIZATION_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X GET https://${AAP2_CONTROLLER_ROUTE}/api/v2/organizations/${ORGANIZATION}/ | jq -r .id)
echo "===== ${ORGANIZATION} ORG ID: ${AAP2_ORGANIZATION_ID}"

## Get User ID
USER_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' https://${AAP2_CONTROLLER_ROUTE}/api/v2/me/ | jq -r .results[0].id)
echo "===== USER ID: ${USER_ID}"

## Add cluster-admin roles to default AAP2 ServiceAccount
oc adm policy add-cluster-role-to-user cluster-admin -z default -n ansible-automation-platform

################################################################################
## Check for Inventory
INVENTORY_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/inventories/?name=${INVENTORY_NAME})

## If not found, create it
if [ "$(echo ${INVENTORY_CHECK} | jq -r .count)" -eq "0" ]; then
  echo "- Inventory does not exist, creating..."
  curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "'${INVENTORY_NAME}'", "description": "", "organization": '${AAP2_ORGANIZATION_ID}', "kind": "", "variables": {}, "host_filter": "", "host_vars": {}, "group_vars": {}, "groups": [], "hosts": []}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/inventories/ > /dev/null 2>&1
else
  echo "- Inventory exists, skipping..."
fi

## Pull the Inventory ID we just created
INVENTORY_ID_PULL=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/inventories/?name=${INVENTORY_NAME} | jq -r .results[0].id)
echo "===== INVENTORY ID: ${INVENTORY_ID_PULL}"

################################################################################
## Check for Host in Inventory
HOST_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/inventories/${INVENTORY_ID_PULL}/hosts/?name=localhost | jq -r .count)
## Add host if it does not exist
if [ "$HOST_CHECK" -eq "0" ]; then
  echo "- Host does not exist, creating..."
  curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "localhost", "description": "", "organization": '${AAP2_ORGANIZATION_ID}', "variables": "---\nansible_connection: local\nansible_python_interpreter: \"{{ ansible_playbook_python }}\"", "host_filter": "", "kind": ""}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/inventories/${INVENTORY_ID_PULL}/hosts/ > /dev/null 2>&1
else
  echo "- Host exists, skipping..."
fi

################################################################################
## Get Credential Type ID
SCM_CREDENTIAL_TYPE_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=Source Control" https://${AAP2_CONTROLLER_ROUTE}/api/v2/credential_types/ | jq -r .results[0].id)

################################################################################
## Check for Credential
CREDENTIAL_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${SCM_CREDENTIAL_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/credentials/ | jq -r .count)
## If not found, create it
if [ "$CREDENTIAL_CHECK" -eq "0" ]; then
  echo "- Credential does not exist, creating..."
  if [ "${SCM_CREDENTIAL_AUTH_TYPE}" == "ssh" ]; then
    curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "'"${SCM_CREDENTIAL_NAME}"'", "description": "", "organization": '${AAP2_ORGANIZATION_ID}', "kind": "", "inputs": {"ssh_key_data": "'"$SCM_CREDENTIAL_PRIVATE_KEY"'"}, "credential_type": '${SCM_CREDENTIAL_TYPE_ID}'}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/credentials/ > /dev/null 2>&1
  fi
  if [ "${SCM_CREDENTIAL_AUTH_TYPE}" == "basic" ]; then
    curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "'"${SCM_CREDENTIAL_NAME}"'", "description": "", "organization": '${AAP2_ORGANIZATION_ID}', "kind": "", "inputs": {"username": "'${SCM_CREDENTIAL_USERNAME}'", "password": "'${SCM_CREDENTIAL_PASSWORD}'"}, "credential_type": '${SCM_CREDENTIAL_TYPE_ID}'}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/credentials/ > /dev/null 2>&1
  fi
else
  echo "- Credential exists, skipping..."
fi

## Get Credential ID
SCM_CREDENTIAL_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${SCM_CREDENTIAL_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/credentials/ | jq -r .results[0].id)
echo "===== CREDENTIAL ID: ${SCM_CREDENTIAL_ID}"

################################################################################
## Check for Project
PROJECT_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${PROJECT_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/projects/ | jq -r .count)
## If not found, create it
if [ "$PROJECT_CHECK" -eq "0" ]; then
  echo "- Project does not exist, creating..."
  curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{ "name": "'"${PROJECT_NAME}"'", "description": "", "scm_type": "git", "scm_url": "'${GIT_REPO}'", "scm_branch": "main", "scm_clean": true, "scm_track_submodules": false, "scm_delete_on_update": false, "credential": '${SCM_CREDENTIAL_ID}', "timeout": 0, "organization": '${AAP2_ORGANIZATION_ID}', "scm_update_on_launch": true, "scm_update_cache_timeout": 0, "allow_override": false, "default_environment": null }' https://${AAP2_CONTROLLER_ROUTE}/api/v2/projects/ > /dev/null 2>&1
else
  echo "- Project exists, skipping..."
fi

## Get Project ID
PROJECT_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${PROJECT_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/projects/ | jq -r .results[0].id)
echo "===== PROJECT ID: ${PROJECT_ID}"

################################################################################
## Check for Job Template
JOB_TEMPLATE_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${JOB_TEMPLATE_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/job_templates/ | jq -r .count)
## If not found, create it
if [ "$JOB_TEMPLATE_CHECK" -eq "0" ]; then
  echo "- Job Template does not exist, creating..."
  curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "'${JOB_TEMPLATE_NAME}'", "description": "", "job_type": "run", "inventory": '${INVENTORY_ID_PULL}', "project": '${PROJECT_ID}', "playbook": "'${JOB_TEMPLATE_PLAYBOOK}'", "scm_branch": "", "forks": 0, "limit": "", "verbosity": 0, "extra_vars": "---", "job_tags": "", "force_handlers": false, "skip_tags": "", "start_at_task": "", "timeout": 0, "use_fact_cache": false, "execution_environment": null, "host_config_key": "", "ask_scm_branch_on_launch": false, "ask_diff_mode_on_launch": false, "ask_variables_on_launch": true, "ask_limit_on_launch": false, "ask_tags_on_launch": false, "ask_skip_tags_on_launch": false, "ask_job_type_on_launch": false, "ask_verbosity_on_launch": false, "ask_inventory_on_launch": false, "ask_credential_on_launch": false, "survey_enabled": false, "become_enabled": false, "diff_mode": false, "allow_simultaneous": true, "job_slice_count": 1, "webhook_service": null, "webhook_credential": null }' https://${AAP2_CONTROLLER_ROUTE}/api/v2/job_templates/ > /dev/null 2>&1
else
  echo "- Job Template exists, skipping..."
fi

################################################################################
## Check for Application
APPLICATION_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${APPLICATION_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/applications/ | jq -r .count)
## If not found, create it
if [ "$APPLICATION_CHECK" -eq "0" ]; then
  echo "- Application does not exist, creating..."
  curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"name": "'"${APPLICATION_NAME}"'", "description": "", "client_type": "confidential", "redirect_uris": "", "authorization_grant_type": "password", "skip_authorization": false, "organization": '${AAP2_ORGANIZATION_ID}'}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/applications/ > /dev/null 2>&1
else
  echo "- Application exists, skipping..."
fi

## Get Application ID
APPLICATION_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "name=${APPLICATION_NAME}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/applications/ | jq -r .results[0].id)
echo "===== APPLICATION ID: ${APPLICATION_ID}"

################################################################################
## Check for Application User Token
APPLICATION_USER_TOKEN_CHECK=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "application=${APPLICATION_ID}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/users/${USER_ID}/tokens/ | jq -r .count)

## If not found, create it
if [ "${APPLICATION_USER_TOKEN_CHECK}" -eq "0" ]; then
  echo "- Application User Token does not exist, creating..."
  USER_APPLICATION_TOKEN_CREATE=$(curl -sSkL -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -H 'Content-Type: application/json' -X POST -d '{"application": '${APPLICATION_ID}', "scope": "write", "description": "'"${APPLICATION_NAME}"' Token"}' https://${AAP2_CONTROLLER_ROUTE}/api/v2/users/${USER_ID}/tokens/)
  echo "USER TOKEN: $(echo ${USER_APPLICATION_TOKEN_CREATE} | jq -r .token)"
  echo ${USER_APPLICATION_TOKEN_CREATE} | jq -r .token > ./aap2_user_application_token
else
  ## Get application token id
  APPLICATION_USER_TOKEN_ID=$(curl -sSk -H "Authorization: Bearer ${AAP2_OAUTH_TOKEN}" -G -H 'Content-Type: application/json' --data-urlencode "application=${APPLICATION_ID}" https://${AAP2_CONTROLLER_ROUTE}/api/v2/users/${USER_ID}/tokens/ | jq -r .results[0].id)
  echo "- Application User Token exists, skipping...delete if a new one needs to be generated"
  echo "  Delete from: https://${AAP2_CONTROLLER_ROUTE}/#/users/${USER_ID}/tokens/${APPLICATION_USER_TOKEN_ID}/details"
fi

################################################################################
## Complete!
echo -e "\n===== Finished bootstrapping Ansible Automation Platform 2 for vSphere ZTP!\n"
