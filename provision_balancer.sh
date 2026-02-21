#!/bin/bash

sudo apt update -y
sudo apt install -y curl unzip haproxy

# ==============================
# Instalar Consul (Server)
# ==============================
curl -s -O https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_amd64.zip
unzip -o consul_1.17.0_linux_amd64.zip
sudo mv consul /usr/local/bin/

sudo mkdir -p /etc/consul.d
sudo rm -rf /tmp/consul

cat <<EOF | sudo tee /etc/consul.d/config.json
{
  "datacenter": "dc1",
  "data_dir": "/tmp/consul",
  "node_name": "balancer",
  "server": true,
  "bootstrap_expect": 1,
  "bind_addr": "192.168.100.10",
  "advertise_addr": "192.168.100.10",
  "client_addr": "0.0.0.0",
  "ui": true
}
EOF

sudo nohup consul agent -config-dir=/etc/consul.d > /tmp/consul.log 2>&1 &

# ==============================
# Configurar HAProxy
# ==============================
sudo bash -c 'cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode http
    option httplog
    timeout connect 5000
    timeout client 50000
    timeout server 50000

frontend http
    bind *:80
    default_backend web-backend

backend web-backend
    balance roundrobin
    option httpchk GET /
    stats enable
    stats uri /haproxy?stats
    stats auth admin:admin
    server-template web 5 _web._tcp.service.consul resolvers consul resolve-prefer ipv4 check

resolvers consul
    nameserver consul 127.0.0.1:8600
    resolve_retries 3
    timeout retry 1s
    hold valid 10s
EOF'

# ==============================
# Crear página 503 personalizada
# ==============================
sudo mkdir -p /etc/haproxy/errors

sudo bash -c 'cat > /etc/haproxy/errors/503.http <<EOF
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<html>
  <head>
    <title>Servicio No Disponible</title>
    <style>
      body { font-family: Arial; text-align: center; padding-top: 100px; }
      h1 { color: #cc0000; }
    </style>
  </head>
  <body>
    <h1>Lo sentimos</h1>
    <p>El servicio está temporalmente fuera de línea.</p>
    <p>Por favor intente más tarde.</p>
  </body>
</html>
EOF'

sudo systemctl restart haproxy