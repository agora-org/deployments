run +target: sync-justfile
  ssh root@66.175.211.57 'just {{ target }}'

ssh:
  ssh root@66.175.211.57

sync-justfile:
  scp justfile root@66.175.211.57:

setup-from-local target="setup":
  scp 50reboot-on-upgrades root@66.175.211.57:/etc/apt/apt.conf.d/

  scp bitcoind.service root@66.175.211.57:/etc/systemd/system/
  ssh root@66.175.211.57 'mkdir -p /etc/bitcoin'
  ssh root@66.175.211.57 'chmod 710 /etc/bitcoin'
  scp bitcoin.conf root@66.175.211.57:/etc/bitcoin/

  scp lnd.service root@66.175.211.57:/etc/systemd/system/
  ssh root@66.175.211.57 'mkdir -p /etc/lnd'
  ssh root@66.175.211.57 'chmod 710 /etc/lnd'
  ssh root@66.175.211.57 'echo -n foofoofoo > /etc/lnd/wallet-password'
  scp lnd.conf root@66.175.211.57:/etc/lnd/
  just run {{ target }}

setup: root-check install-base-packages setup-bitcoind setup-lnd

root-check:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! [[ $(whoami) == "root" ]]; then
    echo you are not root!
    false
  fi

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
  systemctl daemon-reload
  systemctl restart bitcoind

lnd-version := "v0.13.0-beta.rc5"

setup-lnd: root-check
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

lncli +command: root-check
  lncli --network testnet --lnddir=/var/lib/lnd {{ command }}

tail-logs: root-check
  journalctl -f -u bitcoind -u lnd

curl-lnd: root-check
  #!/usr/bin/env bash
  set -euo pipefail
  MACAROON_HEADER="Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /var/lib/lnd/data/chain/bitcoin/testnet/admin.macaroon)"
  curl -X GET --cacert /var/lib/lnd/tls.cert --header "$MACAROON_HEADER" https://localhost:8080/v1/state | jq .
