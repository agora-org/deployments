Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/hirsute64"
  config.vm.network "private_network", ip: "192.168.50.4"
  config.vm.network "private_network", ip: "fde4:8dba:82e1::c4"
  config.vm.provision "shell" do |s|
    ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
    s.inline = <<-SHELL
      echo #{ssh_pub_key} >> /root/.ssh/authorized_keys
    SHELL
  end
end
