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

test-render-templates:
  just TARGET=vagrant render-templates
  just TARGET=kos render-templates
  just TARGET=athens render-templates

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

setup-from-local recipe="setup": render-templates
  #!/usr/bin/env rust-script
  //! ```cargo
  //! [dependencies]
  //! cradle = "=0.0.12"
  //! ```
  use cradle::*;

  const TARGET: &str = "{{ TARGET }}";
  const HOST: &str = "{{ host }}";
  const HOSTNAME: &str = "{{ hostname }}";
  const RECIPE: &str = "{{ recipe }}";

  fn scp(source: &str, destination: &str) {
    cmd_unit!(LogCommand, "scp", source, format!("root@{}:{}", HOST, destination));
  }

  fn ssh<I: Input, O: Output>(command: I) -> O {
    cmd!(LogCommand, "ssh", format!("root@{}", HOST), command)
  }

  fn copy_bitcoind_files() {
    scp("tmp/bitcoind.service", "/etc/systemd/system/");
    let () = ssh("mkdir -p /etc/bitcoin");
    let () = ssh("chmod 710 /etc/bitcoin");
    scp("tmp/bitcoin.conf", "/etc/bitcoin/");
    if TARGET == "athens" {
      scp("mnt-athens.mount", "/etc/systemd/system/");
    }
  }

  fn copy_lnd_files() {
    scp("lnd.service", "/etc/systemd/system/");
    let () = ssh("mkdir -p /etc/lnd");
    let () = ssh("chmod 710 /etc/lnd");
    scp("tmp/lnd.conf", "/etc/lnd/");
  }

  fn install_just() {
    let Status(status) = ssh("just --version");
    if !status.success() {
      let mut command = "curl --proto =https --tlsv1.2 -sSf https://just.systems/install.sh".to_string();
      command.push_str("| bash -s -- --to /usr/local/bin");
      let () = ssh(&command);
    }
  }

  fn add_cargo_bin_to_path() {
    let line = "export PATH=\"$HOME/.cargo/bin:$PATH\"\n";
    let StdoutUntrimmed(mut bashrc) = ssh("cat ~/.bashrc");
    if !bashrc.starts_with(line) {
      bashrc.insert_str(0, line);
      let () = ssh((Stdin(bashrc), "cat > ~/.bashrc"));
    }
  }

  fn main() {
    scp("50reboot-on-upgrades", "/etc/apt/apt.conf.d/");
    copy_bitcoind_files();
    copy_lnd_files();
    install_just();
    add_cargo_bin_to_path();
    let () = ssh(("hostnamectl", "set-hostname", HOSTNAME));
    cmd_unit!("just", format!("TARGET={}", TARGET), "run", RECIPE);
  }
