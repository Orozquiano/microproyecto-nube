#!/bin/bash

sudo apt update -y
sudo apt install -y curl unzip haproxy

# ==============================
# INSTALAR NODE 20 (para Artillery)
# ==============================
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Instalar Artillery global
sudo npm install -g artillery

# ==============================
# INSTALAR CONSUL (Server)
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
# PAGINA 503 PERSONALIZADA
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
    <p>El servicio esta temporalmente fuera de linea.</p>
    <p>Por favor intente mas tarde.</p>
  </body>
</html>
EOF'

# ==============================
# CONFIGURAR HAPROXY
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
    errorfile 503 /etc/haproxy/errors/503.http

frontend http
    bind *:80
    default_backend web-backend

backend web-backend
    balance roundrobin
    option httpchk GET /
    option http-server-close
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
# CREAR SCRIPT DE PRUEBA ARTILLERY
# ==============================

cat <<EOF | sudo tee /home/vagrant/load-test.yml
config:
  target: "http://localhost"
  phases:
    - name: "Carga baja"
      duration: 30
      arrivalRate: 5

    - name: "Carga media"
      duration: 30
      arrivalRate: 20

    - name: "Carga alta"
      duration: 30
      arrivalRate: 50

    - name: "Pico de tráfico"
      duration: 20
      arrivalRate: 100

scenarios:
  - flow:
      - get:
          url: "/"
EOF

sudo chown vagrant:vagrant /home/vagrant/load-test.yml

sudo systemctl restart haproxy

echo "------------------------------------"
echo "BALANCER LISTO"
echo "Consul UI: http://localhost:8500"
echo "HAProxy: http://localhost:8080"
echo "HAProxy Stats: http://localhost:8080/haproxy?stats"
echo "Artillery instalado correctamente"
echo "------------------------------------"