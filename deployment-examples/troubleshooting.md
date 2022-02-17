# Troubleshooting Doc


## Vmware
**VM fails to poweron do to mac**

Run  [mac Generator for OpenShift deployments on VMWARE](https://gist.github.com/tosin2013/eb9e67ab88da09b9597f1b7760f199c9) delete the vm  and update the mac address under 11_nmstate_config-sno-dev1.yml and 08_cluster_config.yml then retry deployment.