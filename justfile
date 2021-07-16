athens := "66.175.216.63"
kos := "66.175.211.57"
export PRODUCTION := "false"
host := if PRODUCTION == "true" { athens } else { kos }

ssh:
  ssh root@{{ host }}

run +target: sync-justfile
  ssh root@{{ host }} 'just PRODUCTION={{ PRODUCTION }} {{ target }}'

sync-justfile:
  scp remote.justfile root@{{ host }}:justfile

# todo:
# - figure out password file
# - figure out wallet creation
# - set blockdir to /mnt/athens/blocks

setup-from-local target="setup":
  #!/usr/bin/env bash
  set -euxo pipefail

  scp 50reboot-on-upgrades root@{{ host }}:/etc/apt/apt.conf.d/

  scp bitcoind.service root@{{ host }}:/etc/systemd/system/
  ssh root@{{ host }} 'mkdir -p /etc/bitcoin'
  ssh root@{{ host }} 'chmod 710 /etc/bitcoin'
  mkdir -p tmp
  rm -f tmp/*
  ./render-template bitcoin.conf > tmp/bitcoin.conf
  scp tmp/bitcoin.conf root@{{ host }}:/etc/bitcoin/

  scp lnd.service root@{{ host }}:/etc/systemd/system/
  ssh root@{{ host }} 'mkdir -p /etc/lnd'
  ssh root@{{ host }} 'chmod 710 /etc/lnd'

  ./render-template lnd.conf > tmp/lnd.conf
  scp tmp/lnd.conf root@{{ host }}:/etc/lnd/

  ssh root@{{ host }} 'just --version || \
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | \
    bash -s -- --to /usr/local/bin'

  just PRODUCTION={{ PRODUCTION }} run {{ target }}
