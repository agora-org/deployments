lnd-version := "v0.13.0-beta"
production := if `hostname` == "athens" { "true" } else { "false" }

tail-logs:
  journalctl -f -u bitcoind -u lnd

setup: install-base-packages install-rust setup-volume setup-bitcoind setup-lnd

install-base-packages:
  #!/usr/bin/env bash
  set -euxo pipefail
  apt-get install --yes \
    atool \
    build-essential \
    jq \
    tree \
    unattended-upgrades \
    update-notifier-common \
    vim
  if ! grep _just /root/.bashrc; then
    just --completions bash >> /root/.bashrc
  fi

install-rust:
  rustup --version || \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path

  cargo install rust-script

setup-volume:
  #!/usr/bin/env bash
  set -euxo pipefail

  if [[ {{ production }} != true ]]; then
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
  if ! which bitcoind; then
    wget -O bitcoin.tar.gz 'https://bitcoin.org/bin/bitcoin-core-0.21.1/bitcoin-0.21.1-x86_64-linux-gnu.tar.gz'
    echo '366eb44a7a0aa5bd342deea215ec19a184a11f2ca22220304ebb20b9c8917e2b bitcoin.tar.gz' | sha256sum -c -
    tar -xzvf bitcoin.tar.gz -C /usr/local/bin --strip-components=2 "bitcoin-0.21.1/bin/bitcoin-cli" "bitcoin-0.21.1/bin/bitcoind"
  fi
  bitcoind --version
  id --user bitcoin &>/dev/null || useradd --system bitcoin
  if [[ {{ production }} == true ]]; then
    mkdir -p /mnt/athens/blocks
    chown bitcoin:bitcoin /mnt/athens/blocks
  fi
  systemctl daemon-reload
  systemctl restart bitcoind

setup-lnd:
  #!/usr/bin/env bash
  set -euxo pipefail
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
  # ssh root@host 'echo -n foofoofoo > /etc/lnd/wallet-password'

lncli +command:
  lncli --network testnet --lnddir=/var/lib/lnd {{ command }}

curl-lnd:
  #!/usr/bin/env bash
  set -euo pipefail
  MACAROON_HEADER="Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /var/lib/lnd/data/chain/bitcoin/testnet/admin.macaroon)"
  curl -X GET --cacert /var/lib/lnd/tls.cert --header "$MACAROON_HEADER" https://localhost:8080/v1/state | jq .
