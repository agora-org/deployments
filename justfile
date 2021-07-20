host := `cat config.yaml | yq --exit-status .$HOSTNAME.ipv4 -r`

ssh:
  ssh root@{{ host }}

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
  ssh root@{{ host }} 'just {{ args }}'

sync-justfile:
  scp remote.justfile root@{{ host }}:justfile

deploy:
  ./deploy

render-templates:
  mkdir -p tmp
  rm -f tmp/*
  ./render-template bitcoind.service > tmp/bitcoind.service
  ./render-template bitcoin.conf > tmp/bitcoin.conf
  ./render-template lnd.conf > tmp/lnd.conf

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
