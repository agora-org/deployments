host := `cat config.yaml | yq .$HOSTNAME.ipv4 -r`

ssh:
  ssh root@{{ host }}

test-on-vagrant:
  ssh-keygen -f /home/shahn/.ssh/known_hosts -R 192.168.50.4
  vagrant up
  ssh-keyscan 192.168.50.4 >> ~/.ssh/known_hosts
  HOSTNAME=vagrant ./setup-from-local
  ssh root@192.168.50.4 just tail-logs

test-render-templates:
  HOSTNAME=vagrant just render-templates
  HOSTNAME=kos just render-templates
  HOSTNAME=athens just render-templates

run +args: sync-justfile
  ssh root@{{ host }} 'just {{ args }}'

sync-justfile:
  scp remote.justfile root@{{ host }}:justfile

# todo:
# - figure out password file
# - figure out wallet creation

render-templates:
  mkdir -p tmp
  rm -f tmp/*
  ./render-template bitcoind.service > tmp/bitcoind.service
  ./render-template bitcoin.conf > tmp/bitcoin.conf
  ./render-template lnd.conf > tmp/lnd.conf
