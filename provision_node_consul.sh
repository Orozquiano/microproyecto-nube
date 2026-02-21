#!/bin/bash

NODE_IP=$1

sudo apt update -y
sudo apt install -y curl unzip nodejs npm

# ==============================
# Instalar Consul
# ==============================
curl -s -O https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_amd64.zip
unzip -o consul_1.17.0_linux_amd64.zip
sudo mv consul /usr/local/bin/

# ==============================
# Crear aplicación NodeJS
# ==============================
cat <<EOF > app.js
const http = require('http');
const os = require('os');

http.createServer((req, res) => {
  res.end("Hello from " + os.hostname());
}).listen(3000);
EOF

nohup node app.js > app.log 2>&1 &

# ==============================
# Configurar Consul Agent
# ==============================
sudo mkdir -p /etc/consul.d
sudo rm -rf /tmp/consul

cat <<EOF | sudo tee /etc/consul.d/config.json
{
  "datacenter": "dc1",
  "data_dir": "/tmp/consul",
  "node_name": "$(hostname)",
  "server": false,
  "retry_join": ["192.168.100.10"],
  "bind_addr": "$NODE_IP",
  "advertise_addr": "$NODE_IP",
  "client_addr": "0.0.0.0"
}
EOF

cat <<EOF | sudo tee /etc/consul.d/web.json
{
  "service": {
    "name": "web",
    "port": 3000,
    "check": {
      "http": "http://localhost:3000",
      "interval": "10s"
    }
  }
}
EOF

# ==============================
# Iniciar Consul
# ==============================
sudo nohup consul agent -config-dir=/etc/consul.d > /tmp/consul.log 2>&1 &