Vagrant.configure("2") do |config|

  config.vm.provider "vmware_desktop"

  # =====================
  # SERVIDOR 1
  # =====================
  config.vm.define "server1" do |s1|
    s1.vm.box = "bento/ubuntu-22.04"
    s1.vm.hostname = "server1"
    s1.vm.network "private_network", ip: "192.168.100.11"
    s1.vm.provision "shell", path: "provision_node_consul.sh", args: "192.168.100.11"
  end

  # =====================
  # SERVIDOR 2
  # =====================
  config.vm.define "server2" do |s2|
    s2.vm.box = "bento/ubuntu-22.04"
    s2.vm.hostname = "server2"
    s2.vm.network "private_network", ip: "192.168.100.12"
    s2.vm.provision "shell", path: "provision_node_consul.sh", args: "192.168.100.12"
  end

  # =====================
  # BALANCEADOR
  # =====================
  config.vm.define "balancer" do |lb|
    lb.vm.box = "bento/ubuntu-22.04"
    lb.vm.hostname = "balancer"
    lb.vm.network "private_network", ip: "192.168.100.10"
    lb.vm.network "forwarded_port", guest: 80, host: 8080
    lb.vm.network "forwarded_port", guest: 8500, host: 8500
    lb.vm.provision "shell", path: "provision_balancer.sh"
  end

end