athens := "66.175.216.63"
kos := "66.175.211.57"
export PRODUCTION := "false"
host := if PRODUCTION == "true" { athens } else { kos }
hostname := if PRODUCTION == "true" { "athens" } else { "kos" }

run +target: sync-justfile
  ssh root@{{ host }} 'just PRODUCTION={{ PRODUCTION }} {{ target }}'

ssh:
  ssh root@{{ host }}

sync-justfile:
  scp justfile root@{{ host }}:

# todo:
# - figure out password file
# - figure out wallet creation

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

setup: root-check set-hostname install-base-packages setup-volume setup-bitcoind setup-lnd

root-check:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! [[ $(whoami) == "root" ]]; then
    echo you are not root!
    false
  fi

set-hostname:
  hostnamectl set-hostname {{ hostname }}

install-base-packages:
  #!/usr/bin/env bash
  set -euxo pipefail
  apt-get install --yes \
    atool \
    jq \
    tree \
    unattended-upgrades \
    update-notifier-common \
    vim
  if ! grep _just /root/.bashrc; then
    just --completions bash >> /root/.bashrc
  fi

setup-volume:
  #!/usr/bin/env bash
  set -euxo pipefail

  if [[ $PRODUCTION != true ]]; then
    exit
  fi

  if [[ -n `e2label /dev/disk/by-id/scsi-0Linode_Volume_athens` ]]; then
    exit
  fi

  mkfs.ext4 -L athens /dev/disk/by-id/scsi-0Linode_Volume_athens
  mkdir /mnt/athens
  mount /dev/disk/by-id/scsi-0Linode_Volume_athens /mnt/athens
  echo \
    '/dev/disk/by-id/scsi-0Linode_Volume_athens /mnt/athens ext4 defaults,noatime,nofail 0 2' \
    >> /etc/fstab

setup-bitcoind:
  #!/usr/bin/env bash
  set -euxo pipefail
  bark check for volume
  if ! which bitcoind; then
    wget -O bitcoin.tar.gz 'https://bitcoin.org/bin/bitcoin-core-0.21.1/bitcoin-0.21.1-x86_64-linux-gnu.tar.gz'
    echo '366eb44a7a0aa5bd342deea215ec19a184a11f2ca22220304ebb20b9c8917e2b bitcoin.tar.gz' | sha256sum -c -
    tar -xzvf bitcoin.tar.gz -C /usr/local/bin --strip-components=2 "bitcoin-0.21.1/bin/bitcoin-cli" "bitcoin-0.21.1/bin/bitcoind"
  fi
  bitcoind --version
  id --user bitcoin &>/dev/null || useradd --system bitcoin
  systemctl daemon-reload
  systemctl restart bitcoind

lnd-version := "v0.13.0-beta.rc5"

setup-lnd: root-check
  #!/usr/bin/env bash
  set -euxo pipefail
  bark setup lnd
  if ! lnd --version | grep {{lnd-version}}; then
    wget -O lnd-linux-amd64-{{lnd-version}}.tar.gz \
      'https://github.com/lightningnetwork/lnd/releases/download/{{lnd-version}}/lnd-linux-amd64-{{lnd-version}}.tar.gz'
    tar -xzvf lnd-linux-amd64-{{lnd-version}}.tar.gz -C /usr/local/bin/ --strip-components=1 \
      lnd-linux-amd64-{{lnd-version}}/lnd \
      lnd-linux-amd64-{{lnd-version}}/lncli
  fi
  lnd --version
  systemctl daemon-reload
  systemctl restart lnd
  bark create wallet
  # ssh root@{{ host }} 'echo -n foofoofoo > /etc/lnd/wallet-password'

lncli +command: root-check
  lncli --network testnet --lnddir=/var/lib/lnd {{ command }}

tail-logs: root-check
  journalctl -f -u bitcoind -u lnd

curl-lnd: root-check
  #!/usr/bin/env bash
  set -euo pipefail
  MACAROON_HEADER="Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /var/lib/lnd/data/chain/bitcoin/testnet/admin.macaroon)"
  curl -X GET --cacert /var/lib/lnd/tls.cert --header "$MACAROON_HEADER" https://localhost:8080/v1/state | jq .
