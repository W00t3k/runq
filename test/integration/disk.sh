#!/bin/bash
. $(cd ${0%/*};pwd;)/../common.sh

if [ $UID -ne 0 ]; then
    checkrc 1 0 "not root - skipped"
    exit 1
fi

if [ ! -x /usr/bin/qemu-img ]; then
    checkrc 1 0 "/usr/bin/qemu-img exists"
    exit 1
fi

set -u

dev1=/dev/nbd0
dev2=/dev/ram0
dev3=/tmp/file-$$

qcow1=/tmp/qcow1-$$
qcow2=/tmp/qcow2-$$

mnt1=/a/b/c
mnt2=/c
mnt3=/d

cleanup() {
    qemu-nbd -d $dev1
    rm -f $qcow1
    rm -f $qcow2
    rm -f $dev3
    test -b $dev2 && dd if=/dev/zero of=$dev2 bs=1M >/dev/null 2>&1
}
trap "cleanup; myexit" 0 2 15

modprobe nbd
modprobe brd

qemu-img create -f qcow2 $qcow1 100m >/dev/null
qemu-img create -f qcow2 $qcow2 100m >/dev/null

qemu-nbd -d $dev1
qemu-nbd -c $dev1 $qcow1

dd if=/dev/zero of=$dev3 bs=1M count=100 >/dev/null

mkfs.ext2 -F $dev1
mkfs.ext4 -F $dev2
mkfs.xfs $dev3

qemu-nbd -d $dev1

comment="create and mount qcow2, raw file and block device"
cmd="set -e"
cmd="$cmd;   dd if=/dev/urandom of=$mnt1/testfile bs=1M count=10"
cmd="$cmd && dd if=/dev/urandom of=$mnt2/testfile bs=1M count=10"
cmd="$cmd && dd if=/dev/urandom of=$mnt3/testfile bs=1M count=10"
cmd="$cmd && md5sum $mnt1/testfile $mnt2/testfile $mnt3/testfile > $mnt1/testfile.md5"
cmd="$cmd; exit \$?"

docker run \
    --runtime runq \
    --name $(rand_name) \
    --rm \
    -v $qcow1:/dev/disk/writeback/ext2/$mnt1 \
    --device $dev2:/dev/disk/none/ext4/$mnt2 \
    -v $dev3:/dev/disk/unsafe/xfs/$mnt3 \
    $image \
    sh -c "$cmd"

checkrc $? 0 "$comment"

comment="re-mount and verify qcow2, raw file and block device"
cmd="cat $mnt1/testfile.md5"
cmd="$cmd && md5sum -c $mnt1/testfile.md5"
cmd="$cmd && set -x; md5sum -c $mnt1/testfile.md5 2>&1 | grep ': OK' | wc -l | xargs test 3 -eq "

#
#
#
docker run \
    --runtime runq \
    --name $(rand_name) \
    --rm \
    -v $qcow1:/dev/disk/writeback/ext2/$mnt1 \
    --device $dev2:/dev/disk/none/ext4/$mnt2 \
    -v $dev3:/dev/disk/unsafe/xfs/$mnt3 \
    $image \
    sh -c "$cmd"

checkrc $? 0 "$comment"

#
#
#
comment="block dev without mount"

cmd="test -b /dev/vda && test -b /dev/vdb; exit \$?"

docker run \
    --runtime runq \
    --name $(rand_name) \
    --rm \
    --device /dev/ram1:/dev/disk/none/none/a \
    --device /dev/ram2:/dev/disk/none/none/b \
    $image \
    sh -c "$cmd"

checkrc $? 0 "$comment"

