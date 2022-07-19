#!/bin/bash

LUA_MOD_DIR="./lua-mod"
LIB_PATH="/usr/local/lua/crowdsec/"
CONFIG_PATH="/etc/crowdsec/bouncers/"
DATA_PATH="/var/lib/crowdsec/lua/"
LAPI_DEFAULT_PORT="8080"
SILENT="false"

usage() {
      echo "Usage:"
      echo "    ./install.sh -h                 Display this help message."
      echo "    ./install.sh                    Install the bouncer in interactive mode"
      echo "    ./install.sh -y                 Install the bouncer and accept everything"
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


gen_apikey() {
    
    type cscli > /dev/null

    if [ "$?" -eq "0" ] ; then
        SUFFIX=`tr -dc A-Za-z0-9 </dev/urandom | head -c 8`
        API_KEY=`sudo cscli bouncers add crowdsec-haproxy-bouncer-${SUFFIX} -o raw`
        echo "Bouncer registered to the CrowdSec Local API."
    else
        echo "cscli is not present, unable to register the bouncer to the CrowdSec Local API."
    fi
    mkdir -p "${CONFIG_PATH}"
    API_KEY=${API_KEY} envsubst < ${LUA_MOD_DIR}/crowdsec-haproxy-bouncer.conf | sudo tee -a "${CONFIG_PATH}crowdsec-haproxy-bouncer.conf" >/dev/null
}


install() {
    sudo mkdir -p ${LIB_PATH}/plugins/crowdsec/
    sudo mkdir -p ${DATA_PATH}/templates/

    sudo cp -r ${LUA_MOD_DIR}/lib/* ${LIB_PATH}/
    sudo cp -r ${LUA_MOD_DIR}/templates/* ${DATA_PATH}/templates/
    sudo cp ${LUA_MOD_DIR}/community_blocklist.map ${DATA_PATH}
}


gen_apikey
install


echo "crowdsec-haproxy-bouncer installed successfully"