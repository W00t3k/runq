#!/bin/bash
. $(cd ${0%/*};pwd;)/../common.sh

case "$(uname -m)" in
    s390x)
        image=sinenomine/mongodb-s390x
        ;;
    *)
        image=mongo
        ;;
esac

name=$(rand_name)
disk=/tmp/disk$$
dd if=/dev/zero of=$disk bs=1M count=200 >/dev/null
mkfs.xfs $disk

cleanup() {
    echo cleanup
    docker rm -f $name
    rm -f $disk
    myexit
}
trap cleanup 0 2 15

comment="MongoDB"

docker run \
    --runtime runq \
    --name $name \
    -e RUNQ_MEM=512 \
    -v $disk:/dev/disk/writeback/xfs/data/db \
    -d \
    $image \
      mongod --smallfiles --noprealloc --logappend --dbpath /data/db

sleep 3

docker run \
    --runtime runq \
    --rm \
    --link $name:mongo-server \
    $image \
      mongo mongo-server/foo --eval 'db.version()'

checkrc $? 0 "$comment"

