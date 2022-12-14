#!/bin/sh

##
## Mount kernel filesystems and Create initial devices.
##

PATH=/usr/bin:/usr/sbin:/bin:/sbin

mount -t proc -o nodev,noexec,nosuid proc /proc

[ -e /dev/console ] || mknod -m 0600 /dev/console c 5 1
[ -e /dev/null ] || mknod -m 0666 /dev/null c 1 3

. /scripts/functions

##
## Mount kernel virtual file systems, ala debian init script of the
## same name.  We use different options in some cases, so move the
## whole thing here to avoid re-running after the pivot.
##
mount_kernelfs()
{
    # keep /tmp, /var/tmp, /run, /run/lock in tmpfs
    tmpfs_size="10M"
    for d in run run/lock ; do
	cmd_run mkdir -p /$d
        mounttmpfs /$d "defaults,noatime,size=$tmpfs_size,mode=1777"
    done

    # On wheezy, if /var/run is not a link
    # fix it and make it a link to /run.
    if [ ! -L /var/run ] ; then
       rm -rf /var/run
       (cd /var && ln -s ../run run)
    fi

    for d in tmp var/tmp ; do
	cmd_run mkdir -p /$d
        mounttmpfs /$d "defaults,noatime,mode=1777"
    done

    cmd_run mount -o nodev,noexec,nosuid -t sysfs sysfs /sys || {
        log_failure_msg "Could not mount sysfs on /sys"
        /sbin/boot-failure 1
    }

    # take care of mountdevsubfs.sh duties also
    d=/run/shm
    if [ ! -d $d ] ; then
	cmd_run mkdir --mode=755 $d
    fi
    mounttmpfs $d "nosuid,nodev"

    TTYGRP=5
    TTYMODE=620
    d=/dev/pts
    if [ ! -d $d ] ; then
	cmd_run mkdir --mode=755 $d
    fi
    cmd_run mount -o "noexec,nosuid,gid=$TTYGRP,mode=$TTYMODE" -t devpts  devpts $d || {
        log_failure_msg "Could not mount devpts on $d"
        /sbin/boot-failure 1
    }
}

make_fw_env_config()
{
    # Look for the NOR flash node in the device tree with property
    # "env_size".
    env_file=$(find /proc/device-tree -name env_size)
    [ -n "$env_file" ] || {
        log_failure_msg "Unable to find u-boot environment device-tree node"
        return 1
    }
    env_sz="0x$(hexdump $env_file | awk '{print $2 $3}')"
    [ -n "$env_sz" ] || {
        log_failure_msg "Unable to find u-boot environment size"
        return 1
    }
    mtd=$(grep uboot-env /proc/mtd | sed -e 's/:.*$//')
    [ -c "/dev/$mtd" ] || {
        log_failure_msg "Unable to find u-boot environment mtd device: /dev/$mtd"
        return 1
    }
    sect_sz="0x$(grep uboot-env /proc/mtd | awk '{print $3}')"
    [ -n "$sect_sz" ] || {
        log_failure_msg "Unable to find u-boot environment mtd erase size"
        return 1
    }

    (cat <<EOF
# MTD device name       Device offset   Env. size       Flash sector size
/dev/$mtd               0x00000000      $env_sz         $sect_sz
EOF
) > /etc/fw_env.config
    
}

log_begin_msg "Mounting kernel filesystems"
mount_kernelfs
log_end_msg

# mtd devices
# Use the names found in /proc/mtd to create symlinks in /dev.
# /dev/mtd-<NAME>
mtds=$(sed -e 's/://' -e 's/"//g' /proc/mtd | tail -n +2 | awk '{ print $1 ":" $4 }')
for x in $mtds ; do
    dev=/dev/${x%:*}
    name=${x#*:}
    if [ -n "$dev" ] ; then
        [ -c $dev ] || {
            log_failure_msg "$dev is not a valid MTD device."
            /sbin/boot-failure 1
        }
        ln -sf $dev /dev/mtd-$name
    fi
done

make_fw_env_config

mkdir -p $ONIE_RUN_DIR
