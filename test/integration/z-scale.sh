#!/bin/bash
. $(cd ${0%/*};pwd;)/../common.sh

n=10
timeout=20
ports=()
names=()

for ((i=0; i<n; i++)); do
    port=$(rand_port)
    name=$(rand_name)
    ports+=($port)
    names+=($name)
    docker run \
        --runtime runq \
        --rm \
        --name $name \
        -e runq_cpu=1 \
        -e runq_mem=64 \
        -d \
        -p $port:$port \
        $image \
        sh -c "echo $port | nc -l -p $port" &
done
wait

sleep 5

rc=0
for p in "${ports[@]}"; do
    test "$(curl -m $timeout -s localhost:$p)" = "$p"
    rc=$(($? + rc))
    echo checked localhost:$p $rc
    sleep .1
done


docker rm -f ${names[@]} 2>/dev/null

checkrc $rc 0 "start $n containers in parallel"

myexit
