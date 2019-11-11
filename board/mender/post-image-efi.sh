#!/bin/bash

mkdir -p ${BINARIES_DIR}/data-part/
echo "device_type=buildroot" > ${BINARIES_DIR}/data-part/device_type
sh support/scripts/genimage.sh $2 board/mender/genimage-efi.cfg

function create_mender_image(){
  echo "Creating ${BINARIES_DIR}/${1}"
  ${HOST_DIR}/bin/mender-artifact \
    --compression lzma \
    write rootfs-image \
    -t BUILDROOT_DEVICE \
    -n ${BR2_VERSION} \
    -f ${BINARIES_DIR}/rootfs.ext2 \
    -o ${BINARIES_DIR}/${1}
}

# Uncomment this line to generate a mender artifact after the image is built.
# create_mender_image "update-${BR2_VERSION}.mender"
