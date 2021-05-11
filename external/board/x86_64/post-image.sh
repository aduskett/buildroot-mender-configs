#!/usr/bin/env bash
set -e
CWD=$(pwd)
BOARD_DIR="$(realpath "$(dirname "$0")")"
GENIMAGE_CFG="${BOARD_DIR}/genimage-efi.cfg"
IMAGES_DIR="${CWD}/external/images/${DEVICE_TYPE}"
DATA_PART_SIZE="32M"
DEVICE_TYPE="buildroot-x86_64"
GENERATE_MENDER_IMAGE="false"
ARTIFACT_NAME="2021.02.1"


# Parse arguments.
function parse_args(){
    local o O opts
    o='a:o:d:g:'
    O='artifact-name:,data-part-size:,device-type:,generate-mender-image:'
    opts="$(getopt -o "${o}" -l "${O}" -- "${@}")"
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
        (-a|--artifact-name)
            ARTIFACT_NAME="${2}"; shift 2
            ;;
        (--)
            shift; break
            ;;
        esac
    done
}

# Create the data partition
function make_data_partition(){
    rm -rf "${BINARIES_DIR}"/data-part.ext4
    rm -rf "${BINARIES_DIR}"/data-part
    mkdir -p "${BINARIES_DIR}"/data-part

    "${HOST_DIR}"/sbin/mkfs.ext4 \
    -d "${BINARIES_DIR}"/data-part \
    -r 1 \
    -N 0 \
    -m 5 \
    -L "data" \
    -O 64bit "${BINARIES_DIR}"/data-part.ext4 "${DATA_PART_SIZE}"
    "${HOST_DIR}"/sbin/e2fsck -y "${BINARIES_DIR}"/data-part.ext4
}


# Create a mender image.
function generate_mender_image(){
  if [[ ${GENERATE_MENDER_IMAGE} == "true" ]]; then
    echo "Creating ${BINARIES_DIR}/${DEVICE_TYPE}-${ARTIFACT_NAME}.mender"
    "${HOST_DIR}"/bin/mender-artifact \
      --compression lzma \
      write rootfs-image \
      -t "${DEVICE_TYPE}" \
      -n "${BR2_VERSION}" \
      -f "${BINARIES_DIR}"/rootfs.ext2 \
      -o "${BINARIES_DIR}"/"${DEVICE_TYPE}"-"${ARTIFACT_NAME}".mender
  fi
}


function generate_image(){
  mkdir -p "${IMAGES_DIR}"
  UUID_ROOT=$(dumpe2fs "${BINARIES_DIR}/rootfs.ext2" 2>/dev/null | sed -n 's/^Filesystem UUID: *\(.*\)/\1/p')
  UUID_DATA=$(dumpe2fs "${BINARIES_DIR}/data-part.ext4" 2>/dev/null | sed -n 's/^Filesystem UUID: *\(.*\)/\1/p')
  sed "s/UUID_ROOT_TMP/${UUID_ROOT}/g" ${BOARD_DIR}/genimage.cfg > "${BINARIES_DIR}/genimage.cfg"
  sed "s/DISK_IMG/${DEVICE_TYPE}.img/g" -i "${BINARIES_DIR}/genimage.cfg"
  sed "s/UUID_ROOT_TMP/${UUID_ROOT}/g" -i "${BINARIES_DIR}/efi-part/EFI/BOOT/grub.cfg"
  sed "s/UUID_DATA_TMP/${UUID_DATA}/g" -i "${BINARIES_DIR}/genimage.cfg"
  sh support/scripts/genimage.sh -c "${BINARIES_DIR}"/genimage.cfg
  echo "cp ${BINARIES_DIR}/${DEVICE_TYPE}.img ${IMAGES_DIR}/${DEVICE_TYPE}.img"
  cp "${BINARIES_DIR}/${DEVICE_TYPE}.img" "${IMAGES_DIR}/${DEVICE_TYPE}.img"
}

# Main function.
function main(){
  parse_args "${@}"
  make_data_partition
  generate_image
  generate_mender_image
  exit $?

}
main "${@}"
