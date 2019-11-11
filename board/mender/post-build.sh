#!/bin/sh -e
cd ${TARGET_DIR}

# Create a persistent directory to mount the data partition at.
if [[ -L var/lib/mender ]]; then
  rm var/lib/mender
  mkdir -p var/lib/mender
fi

# The common paradigm is to have the persistent data volume at /data for mender.
if [[ ! -L data ]]; then
    ln -s var/lib/mender data
fi

