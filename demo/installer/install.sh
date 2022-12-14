#!/bin/sh

set -e

cd $(dirname $0)
. ./machine.conf

echo "Demo Installer: platform: $platform"

install_uimage() {
    echo "Copying uImage to NOR flash:"
    flashcp -v demo-${platform}.uImage $mtd_dev
}

hw_load() {
    echo "cp.b $img_start \$loadaddr $img_sz"
}

. ./platform.conf

install_uimage

hw_load_str="$(hw_load)"

echo "Updating U-Boot environment variables"
(cat <<EOF
hw_load $hw_load_str
copy_img echo "Loading Demo $platform image..." && run hw_load
nos_bootcmd run copy_img && setenv bootargs quiet console=\$consoledev,\$baudrate && bootm \$loadaddr
EOF
) > /tmp/env.txt

fw_setenv -f -s /tmp/env.txt

echo "Rebooting..."
reboot
