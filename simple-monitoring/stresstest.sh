#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script should run with sudo"
  exit 1
fi

RUN_CPU=false
RUN_RAM=false
RUN_NGINX=false

if [ $# -eq 0 ]; then
    RUN_CPU=true
    RUN_RAM=true
    RUN_NGINX=true
else

    while [ "$1" != "" ]; do
        case $1 in
            -cpu)    RUN_CPU=true ;;
            -ram)    RUN_RAM=true ;;
            -nginx)  RUN_NGINX=true ;;
            *)       echo  "Unknown: $1. Use: -cpu, -ram, -nginx" ; exit 1 ;;

        esac
        shift
    done
fi

echo -e "Installing dependencies (stress, apache2-utils)..."
apt update -y && apt install -y stress apache2-utils

test_cpu() {

    stress --cpu $(nproc) --timeout 70s

}

test_ram() {

    stress --vm 1 --vm-bytes 400M --vm-keep --timeout 70s

}

test_nginx() {

    ab -t 60 -n 1000000 -c 50 -k http://127.0.0.1:8081/

}

if [ "$RUN_CPU" = true ]; then test_cpu; fi
if [ "$RUN_RAM" = true ]; then test_ram; fi
if [ "$RUN_NGINX" = true ]; then test_nginx; fi



