#!/usr/bin/env bash
set -e
BOARD_DIR="$(realpath "$(dirname "$0")")"
DATA_PART_SIZE="32M"
DEVICE_TYPE="buildroot-x86_64"
GENERATE_MENDER_IMAGE="false"
ARTIFACT_NAME="1.0"


# Parse arguments.
parse_args() {
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

# Generate a mender bootstrap artifact.
# See https://northerntech.atlassian.net/browse/MEN-2585
generate_mender_bootstrap_artifact() {
  rm -rf "${BINARIES_DIR}"/data-part
  mkdir -p "${BINARIES_DIR}"/data-part
  img_checksum=$(sha256sum "${BINARIES_DIR}"/rootfs.ext4 |awk '{print $1}')

  "${HOST_DIR}"/bin/mender-artifact \
    write bootstrap-artifact \
    --artifact-name "${ARTIFACT_NAME}" \
    --device-type "${DEVICE_TYPE}" \
    --provides "rootfs-image.version:${ARTIFACT_NAME}" \
    --provides "rootfs-image.checksum:${img_checksum}" \
    --clears-provides "rootfs-image.*" \
    --output-path "${BINARIES_DIR}"/data-part/bootstrap.mender \
    --version 3
}

# Create the data partition
make_data_partition() {
    rm -rf "${BINARIES_DIR}"/data-part.ext4
    rm -rf "${BINARIES_DIR}"/data-part
    mkdir -p "${BINARIES_DIR}"/data-part

    "${HOST_DIR}"/sbin/mkfs.ext4 \
    -d "${BINARIES_DIR}"/data-part \
    -r 1 \
    -N 0 \
    -m 5 \
    -L "data" \
    "${BINARIES_DIR}/data-part.ext4" "${DATA_PART_SIZE}"
    "${HOST_DIR}"/sbin/e2fsck -y "${BINARIES_DIR}"/data-part.ext4
}


# Create a mender image.
generate_mender_image() {
  if [[ "${GENERATE_MENDER_IMAGE}" == "true" ]]; then
    echo "Creating ${BINARIES_DIR}/${DEVICE_TYPE}-${ARTIFACT_NAME}.mender"
    "${HOST_DIR}/bin/mender-artifact" \
      --compression lzma \
      write rootfs-image \
        -t "${DEVICE_TYPE}" \
        -n "${BR2_VERSION}" \
        -f "${BINARIES_DIR}/rootfs.ext2" \
        -o "${BINARIES_DIR}/${DEVICE_TYPE}-${ARTIFACT_NAME}.mender"
  fi
}


generate_image() {
    sh support/scripts/genimage.sh -c "${BOARD_DIR}/genimage-efi.cfg"
}

# Main function.
main() {
  parse_args "${@}"
  generate_mender_bootstrap_artifact
  make_data_partition
  generate_image
  generate_mender_image
  exit $?
}

main "${@}"
