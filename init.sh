#!/bin/bash

# Use amneziawg-go userspace implementation so no host kernel module is required
export WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go

# /dev/net/tun is required for the userspace tunnel.
# If missing, try to load it (requires CAP_SYS_MODULE and /lib/modules mounted from host).
if [ ! -c /dev/net/tun ]; then
  modprobe tun 2>/dev/null \
    || insmod /lib/modules/tun.ko 2>/dev/null \
    || true
fi

if [ ! -c /dev/net/tun ]; then
  echo "ERROR: /dev/net/tun does not exist and could not be loaded automatically."
  echo "Option A (automatic): add CAP_SYS_MODULE and mount /lib/modules:/lib/modules:ro — see docs/synology-compose.yml"
  echo "Option B (manual):    run 'sudo insmod /lib/modules/tun.ko' on the host, then recreate the container."
  exit 1
fi

# Ensure config directory exists, then clear any stale configurations
mkdir -p /etc/amnezia/amneziawg
find /etc/amnezia/amneziawg -mindepth 1 -delete

COUNTER=0
for s in $(find /config -name "*.conf")
do
  if test -f ${s}
  then
    COUNTER=$(( COUNTER + 1 ))
    basename=$(basename ${s})
    name=${basename%.conf}
    echo "awg interface '${name}' will be created from config file '${basename}'"
    cp ${s} /etc/amnezia/amneziawg/${name}.conf
    chmod 600 /etc/amnezia/amneziawg/${name}.conf
    awg-quick up ${name} || { echo "ERROR: awg-quick up ${name} failed"; exit 1; }
  fi
done

if [[ $COUNTER -lt 1 ]]
then
  echo "There are no config files in the /config folder"
  exit 1
fi

sleep infinity
