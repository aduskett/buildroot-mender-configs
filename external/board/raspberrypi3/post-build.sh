#!/usr/bin/env bash
set -e
BOARD_DIR="$(realpath $(dirname $0))"
SYSTEMD=$(grep "BR2_INIT_SYSTEMD" ${BR2_CONFIG} |cut -d'=' -f2)
RW_ROOTFS=$(grep "BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW" ${BR2_CONFIG} |cut -d'=' -f2)
OPENSSH=$(grep "BR2_PACKAGE_OPENSSH" ${BR2_CONFIG} |cut -d'=' -f2)
SSH_KEY_DIR=/data/ssh
DEVICE_TYPE="raspberrypi3"
BUILD_VERSION="2019.11.1"

INITD="y"
if [[ ${SYSTEMD} == "y" ]]; then
  INITD="n"
fi


# Parse arguments.
function parse_args(){
    local o O opts
    o='o:d:g:v:'
    O='data-part-size:,device-type:,generate-mender-image:,build-version:'
    opts="$(getopt -n "${my_name}" -o "${o}" -l "${O}" -- "${@}")"
    eval set -- "${opts}"
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        (-o|--data-part-size)
            DATA_PART_SIZE="${2}"; shift 2
            ;;
        (-d|--device-type)
            DEVICE_TYPE="${2}"; shift 2
            ;;
        (-g|--generate-mender-image)
            GENERATE_MENDER_IMAGE="${2}"; shift 2
            ;;
        (-v|--build-version)
            BUILD_VERSION="${2}"; shift 2
            ;;
        (--)
            shift; break
            ;;
        esac
    done
}


function mender_fixup(){
  # The mender package creates var/lib/mender directory as a symlink to
  # /var/run/mender which is link to /run. However, /run is often times mounted
  # as a tmpfs, which makes the mender folder disapear. Instead, remove the
  # symlink and recreate it as a directory, then symlink data to
  # the new /var/lib/mender directory.
  cd ${TARGET_DIR}

  if [[ -L var/lib/mender ]]; then
    rm -rf var/lib/mender
  fi

  mkdir -p var/lib/mender
  if [[ ! -L data ]]; then
    rm -rf data
    ln -s var/lib/mender data
  fi 

  # These service file remove the broken symlink checks.
  if [[ ${SYSTEMD} == "y" ]]; then
    cp ${BOARD_DIR}/systemd/mender.service ${TARGET_DIR}/usr/lib/systemd/system/
    echo "Removing getty"
    rm -rf ${TARGET_DIR}/etc/systemd/system/getty.target.wants
  fi
  if [[ ${INITD} == "y" ]]; then
      cp ${BOARD_DIR}/initd/S42mender.in ${TARGET_DIR}/etc/init.d/S42mender
      # If the root filing system is read only, logging should happen in /data/
      if [[ ${RW_ROOTFS} ]]; then
        sed s#@MENDER_LOG_PATH@#/var/log/mender.log#g -i ${TARGET_DIR}/etc/init.d/S42mender
      else
        sed s#@MENDER_LOG_PATH@#/data/mender.log@g -i ${TARGET_DIR}/etc/init.d/S42mender
      fi
  fi
}


# If openssh is selected, we should change the ssh key directory to a place
# that won't be overwritten with every new update.
# Idealy, on a system with an eMMC, for security purposes these keys should
# live in a seperate partition that isn't wiped with a factory reset
# (IE: /factory or /persistent).However, in the case of the RPi, there is no
# eMMC, so /data/ is fine.
function sshd_fixup(){
  if [[ ${OPENSSH} == "y" ]]; then
    SSHD_CONFIG=${TARGET_DIR}/etc/ssh/sshd_config
    if [[ ${SYSTEMD} == "y" ]]; then
      /bin/cp ${BOARD_DIR}/systemd/sshd.service ${TARGET_DIR}/usr/lib/systemd/system/
    fi
    if [[ ${INITD} == "y" ]]; then
      /bin/cp ${BOARD_DIR}/initd/S50sshd ${TARGET_DIR}/etc/init.d/S50sshd
    fi
    cp ${BOARD_DIR}/ssh/generate_new_ssh_host_keys ${TARGET_DIR}/usr/bin/
    sed s#@SSH_KEY_DIR@#${SSH_KEY_DIR}#g -i ${TARGET_DIR}/usr/bin/generate_new_ssh_host_keys
    
    sed "/AuthorizedKeysFile/c\AuthorizedKeysFile ${SSH_KEY_DIR}/authorized_keys" -i ${SSHD_CONFIG}
    sed "/ssh_host_rsa_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_rsa_key" -i ${SSHD_CONFIG}
    sed "/ssh_host_ed25519_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_ed25519_key" -i ${SSHD_CONFIG}
    sed "/ssh_host_ecdsa_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_ecdsa_key" -i ${SSHD_CONFIG}
  fi
}

function main(){
  parse_args "${@}"
  mender_fixup
  sshd_fixup
  echo "device_type=${DEVICE_TYPE}" > ${TARGET_DIR}/etc/mender/device_type
}

main "${@}"









