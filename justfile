set positional-arguments

ip := `cat config.yaml | yq --exit-status .$HOSTNAME.ipv4 -r`

ssh *args: sync-justfile
  ssh root@{{ ip }} "$@"

test-on-vagrant:
  ssh-keygen -f ~/.ssh/known_hosts -R 192.168.50.4
  vagrant up
  ssh-keyscan 192.168.50.4 >> ~/.ssh/known_hosts
  HOSTNAME=vagrant ./deploy
  ssh root@192.168.50.4 just tail-logs

test-render-templates:
  HOSTNAME=vagrant just render-templates
  HOSTNAME=kos just render-templates
  HOSTNAME=athens just render-templates

run +args: sync-justfile
  ssh -t root@{{ ip }} just "$@"

lncli +args: (run "lncli" args)

lntop *args:
  ssh -t root@{{ ip }} lntop "$@"

sync-justfile:
  scp remote.justfile root@{{ ip }}:justfile

deploy:
  ./deploy

render-templates:
  mkdir -p tmp
  rm -f tmp/*
  ./render-template agora.service > tmp/agora.service
  ./render-template bitcoin.conf > tmp/bitcoin.conf
  ./render-template bitcoind.service > tmp/bitcoind.service
  ./render-template lnd.conf > tmp/lnd.conf
  ./render-template lntop.toml > tmp/lntop.toml

install-dependencies:
  pip3 install yq

create-wallet:
  #!/usr/bin/env bash
  set -euo pipefail

  cat <<'END'
  To create a new wallet:

  - SSH into target machine with `just ssh`
  - Run `just lncli create`
  - Input new password when prompted
  - Save seed phrase
  - Write password to /etc/lnd/wallet-password
  - Re-run deploy script with `just deploy`
  END
