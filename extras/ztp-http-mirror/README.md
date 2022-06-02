# ZTP HTTP Mirror

There may be some assets that may need to be mirrored, such as the Red Hat CoreOS ISOs and Root Filesystems.

You can do so easily with a pre-built Golang application that will take a list of URLs, download them to a specific path, optionally overwrite existing files, and then mirror them via an HTTP server. This is handy for ZTP where you may need to mirror RHCOS ISOs and Root Filesystem blobs.

You can find this application here: https://github.com/kenmoini/go-http-mirror

It is available via the Ansible Automation deployer as default.
