#!/bin/bash

LIB_PATH="/usr/local/lua/crowdsec/haproxy/"
DATA_PATH="/var/lib/crowdsec/lua/haproxy/"
SILENT="false"

usage() {
      echo "Usage:"
      echo "    ./uninstall.sh -h                 Display this help message."
      echo "    ./uninstall.sh                    Uninstall the bouncer in interactive mode"
      echo "    ./uninstall.sh -y                 Uninstall the bouncer and accept everything"
      exit 0  
}

#Accept cmdline arguments to overwrite options.
while [[ $# -gt 0 ]]
do
    case $1 in
        -y|--yes)
            SILENT="true"
            shift
        ;;
        -h|--help)
            usage
        ;;
    esac
    shift
done


uninstall() {
    rm -rf ${DATA_PATH}
    rm -rf ${LIB_PATH}
}

if ! [ $(id -u) = 0 ]; then
    log_err "Please run the uninstall script as root or with sudo"
    exit 1
fi
uninstall
echo "crowdsec-haproxy-bouncer uninstalled successfully"