#!/bin/bash


IFS=$'\n' read -d '' -r -a lines < ../conf/workers

for worker in ${lines[@]}
do
    echo $worker
done