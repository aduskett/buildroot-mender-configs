#!/bin/sh

set -ue

# Prevent a double login prompt
if [[ -d ${TARGET_DIR}/etc/systemd/system/getty.target.wants ]]; then
    rm -rf ${TARGET_DIR}/etc/systemd/system/getty.target.wants
fi

# The mender package creates this directory as a link, and it should be a folder.
mkdir -p ${TARGET_DIR}/run/mender
if [[ -L ${TARGET_DIR}/data ]]; then
  rm ${TARGET_DIR}/data
fi 

cd ${TARGET_DIR}
ln -s run/mender data
