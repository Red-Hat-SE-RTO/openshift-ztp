#!/bin/bash

#########################################################
## Global Functions

## checkForProgramAndExit detects binaries available in the system path
function checkForProgramAndExit() {
    command -v $1 > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        printf '  %-72s %-7s\n' $1 "PASSED!";
    else
        printf '  %-72s %-7s\n' $1 "FAILED!";
        echo -e "\n  Missing required $1 binary!\n";
        exit 1
    fi
}

## checkForProgramAndInstallOrExit detects binaries available in the system path, if not available installs it
function checkForProgramAndInstallOrExit() {
    command -v $1 > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        printf '  %-72s %-7s\n' $1 "PASSED!";
    else
        printf '  %-72s %-7s\n' $1 "NOT FOUND!";
        echo "    Attempting to install $1 via $2..."
        sudo yum install -y $2
        if [[ $? -eq 0 ]]; then
            printf '  %-72s %-7s\n' $1 "PASSED!";
        else
            printf '  %-72s %-7s\n' $1 "FAILED!";
            echo -e "\n  Missing required $1 binary and unable to install!\n";
            exit 1
        fi
    fi
}

## checkForProgramAndDownloadOrExit detects binaries available in the system path, if not available downloads and installs it
function checkForProgramAndDownloadOrExit() {
    command -v $1 > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        printf '  %-72s %-7s\n' $1 "PASSED!";
    else
        printf '  %-72s %-7s\n' $1 "NOT FOUND!";
        echo "    Attempting to install $1 via $2 to $3..."

        ## Make a temp directory
        TMP_DIR=$(mktemp -d)
        ## Download the binary package
        curl -sSL "$2" -o ${TMP_DIR}/$(basename "$2")
        ## Extract the package
        tar zxf ${TMP_DIR}/$(basename "$2") -C ${TMP_DIR}
        ## Remove the Readme
        rm -f ${TMP_DIR}/README
        rm -f ${TMP_DIR}/README.md
        ## Add the executable permissions
        chmod a+x ${TMP_DIR}/$1
        ## Move the binary to the target path
        sudo mv ${TMP_DIR}/$1 $3
        ## Remove the temp directory
        rm -rf ${TMP_DIR}
        
        if [[ $? -eq 0 ]]; then
            printf '  %-72s %-7s\n' $1 "PASSED!";
        else
            printf '  %-72s %-7s\n' $1 "FAILED!";
            echo -e "\n  Missing required $1 binary and unable to download and install!\n";
            exit 1
        fi
    fi
}


## checkForProgramAndDownloadOrExit detects binaries available in the system path, if not available downloads and installs it
function checkForArgocdcliAndDownloadOrExit() {
      command -v $1 > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        printf '  %-72s %-7s\n' $1 "PASSED!";
    else
        printf '  %-72s %-7s\n' $1 "NOT FOUND!";
        echo "    Attempting to install $1 via $2."

        curl -sSL -o /usr/local/bin/$1 $2
        chmod +x /usr/local/bin/$1
        
        if [[ $? -eq 0 ]]; then
            printf '  %-72s %-7s\n' $1 "PASSED!";
        else
            printf '  %-72s %-7s\n' $1 "FAILED!";
            echo -e "\n  Missing required $1 binary and unable to download and install!\n";
            exit 1
        fi
    fi
}

function login-to-argocd(){
    nameSpace=argocd
    argoRoute=$(oc get route argocd-server -n ${nameSpace} -o jsonpath='{.spec.host}')
    argoUser=admin
    argoPass=$(oc get secret/argocd-cluster -n ${nameSpace} -o jsonpath='{.data.admin\.password}' | base64 -d)
    until [[ $(curl -ks -o /dev/null -w "%{http_code}"  https://${argoRoute}) -eq 200 ]]
    do
        sleep 3
        echo -n '.'
    done
    argocd login --insecure --grpc-web --username ${argoUser} --password ${argoPass} ${argoRoute}

    echo "$argoRoute"
    echo "$argoPass"
}