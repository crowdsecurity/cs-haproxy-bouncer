#!/bin/bash

LUA_MOD_DIR="./lua-mod"
LIB_PATH="/usr/local/lua/crowdsec/haproxy/"
CONFIG_PATH="/etc/crowdsec/bouncers/"
CONFIG_FILE="${CONFIG_PATH}crowdsec-haproxy-bouncer.conf"
OLD_CONFIG_FILE="/etc/crowdsec/crowdsec-haproxy-bouncer.conf"
DATA_PATH="/var/lib/crowdsec/lua/haproxy/"

install() {
    mkdir -p ${LIB_PATH}/plugins/crowdsec/
    mkdir -p ${DATA_PATH}/templates/

    cp -r ${LUA_MOD_DIR}/lib/* ${LIB_PATH}/
    cp -r ${LUA_MOD_DIR}/templates/* ${DATA_PATH}/templates/

    if [ ! -f ${LUA_MOD_DIR}/community_blocklist.map ]; then
        cp ${LUA_MOD_DIR}/community_blocklist.map ${DATA_PATH}
    fi
}

migrate_conf() {
    if [ -f "$CONFIG_FILE" ]; then
        return
    fi
    if [ ! -f "$OLD_CONFIG_FILE" ]; then
        return
    fi
    echo "Found $OLD_CONFIG_FILE, but no $CONFIG_FILE. Migrating it."
    mv "$OLD_CONFIG_FILE" "$CONFIG_FILE"
}

if ! [ $(id -u) = 0 ]; then
    echo "Please run the upgrade script as root or with sudo"
    exit 1
fi

if [ ! -d "${CONFIG_PATH}" ]; then
    echo "crowdsec-haproxy-bouncer is not installed, please run the ./install.sh script"
    exit 1
fi

install
migrate_conf
echo "crowdsec-haproxy-bouncer upgraded successfully"