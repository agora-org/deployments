tail-logs:
  journalctl -f -u bitcoind -u lnd -u agora

list-invoices:
  just lncli listinvoices \
    | yq --raw-output \
      '.invoices[] \
       | "memo:    \(.memo)\n\
          state:   \(.state)\n\
          created: \(.creation_date | tonumber | todate)\n\
          value:   \(.value)\n---"'

setup: install-base-packages install-rust setup-volume setup-bitcoind setup-lightning

install-base-packages:
  #!/usr/bin/env bash
  set -euxo pipefail
  apt-get update
  apt-get install --yes \
    acl \
    atool \
    build-essential \
    golang \
    jq \
    python3-pip \
    ripgrep \
    silversearcher-ag \
    tree \
    unattended-upgrades \
    update-notifier-common \
    vim
  if ! grep _just /root/.bashrc; then
    just --completions bash >> /root/.bashrc
  fi
  touch ~/.hushlogin

install-rust:
  rustup --version || \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path
  cargo install rust-script

setup-volume:
  #!/usr/bin/env bash
  set -euxo pipefail

  if [[ `hostname` != athens ]]; then
    exit
  fi

  if [[ -n `e2label /dev/disk/by-id/scsi-0Linode_Volume_athens` ]]; then
    exit
  fi

  mkfs.ext4 -L athens /dev/disk/by-id/scsi-0Linode_Volume_athens

setup-bitcoind:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! which bitcoind; then
    wget -O bitcoin.tar.gz 'https://bitcoin.org/bin/bitcoin-core-0.21.1/bitcoin-0.21.1-x86_64-linux-gnu.tar.gz'
    echo '366eb44a7a0aa5bd342deea215ec19a184a11f2ca22220304ebb20b9c8917e2b bitcoin.tar.gz' | sha256sum -c -
    tar -xzvf bitcoin.tar.gz -C /usr/local/bin --strip-components=2 "bitcoin-0.21.1/bin/bitcoin-cli" "bitcoin-0.21.1/bin/bitcoind"
  fi
  bitcoind --version
  id --user bitcoin &>/dev/null || useradd --system bitcoin
  if [[ `hostname` == athens ]]; then
    systemctl start mnt-athens.mount
    mkdir -p /mnt/athens/blocks
    chown bitcoin:bitcoin /mnt/athens/blocks
  fi
  systemctl daemon-reload
  systemctl enable bitcoind
  systemctl restart bitcoind --no-block

setup-lightning:
  ./setup-lightning

lncli +command:
  #!/usr/bin/env bash
  set -euxo pipefail

  NETWORK=`cat config.yaml | yq --exit-status .network -r`
  lncli --network $NETWORK --lnddir=/var/lib/lnd {{ command }}
