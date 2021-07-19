athens := "66.175.216.63"
kos := "66.175.211.57"
vagrant := "192.168.50.4"
export TARGET := "vagrant"
host := if TARGET == "athens" {
  athens
} else {
  if TARGET == "kos" {
    kos
  } else {
    vagrant
  }
}
hostname := TARGET

ssh:
  ssh root@{{ host }}

test-on-vagrant:
  ssh-keygen -f "/home/shahn/.ssh/known_hosts" -R "192.168.50.4"
  vagrant up
  ssh-keyscan 192.168.50.4 >> ~/.ssh/known_hosts
  just TARGET=vagrant setup-from-local
  ssh root@192.168.50.4 just tail-logs

run +target: sync-justfile
  ssh root@{{ host }} 'just {{ target }}'

sync-justfile:
  scp remote.justfile root@{{ host }}:justfile

# todo:
# - figure out password file
# - figure out wallet creation

render-templates:
  mkdir -p tmp
  rm -f tmp/*
  ./render-template bitcoin.conf > tmp/bitcoin.conf
  ./render-template lnd.conf > tmp/lnd.conf

setup-from-local target="setup": render-templates
  #!/usr/bin/env bash
  set -euxo pipefail

  scp 50reboot-on-upgrades root@{{ host }}:/etc/apt/apt.conf.d/

  scp bitcoind.service root@{{ host }}:/etc/systemd/system/
  ssh root@{{ host }} 'mkdir -p /etc/bitcoin'
  ssh root@{{ host }} 'chmod 710 /etc/bitcoin'
  scp tmp/bitcoin.conf root@{{ host }}:/etc/bitcoin/

  scp lnd.service root@{{ host }}:/etc/systemd/system/
  ssh root@{{ host }} 'mkdir -p /etc/lnd'
  ssh root@{{ host }} 'chmod 710 /etc/lnd'

  scp tmp/lnd.conf root@{{ host }}:/etc/lnd/

  ssh root@{{ host }} 'just --version || \
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | \
    bash -s -- --to /usr/local/bin'

  ssh root@{{ host }} 'cat ~/.bashrc' | head -1 | grep .cargo/env || \
    ssh root@{{ host }} sed \
      -i \
      '"1s;^;export PATH=\"\$HOME/.cargo/bin:\$PATH\"\n;"' \
      '~/.bashrc'

  ssh root@{{ host }} 'hostnamectl set-hostname {{ hostname }}'

  just TARGET={{ TARGET }} run {{ target }}
