#!/usr/bin/bash

while [ 1 ]; do
    rocm-smi -u | grep 'GPU use'
    sleep 60
done
