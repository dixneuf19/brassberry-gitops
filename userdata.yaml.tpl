#cloud-config

hostname: "oracle-arm"

groups:
  - docker

users:
  - name: ${github_user}
    ssh_import_id:
      - gh:${github_user}
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups:
      - sudo
      - users
      - docker

ssh_pwauth: false

apt:
  sources:
    tailscale.list:
      source: deb https://pkgs.tailscale.com/stable/ubuntu $RELEASE main
      keyid: 2596A99EAAB33821893C0A79458CA832957F5868

packages:
  - tailscale
  - nginx

write_files:
  - content: |
      user www-data;
      worker_processes auto;
      pid /run/nginx.pid;
      include /etc/nginx/modules-enabled/*.conf;

      events {
        worker_connections 768;
        # multi_accept on;
      }

      stream {

          upstream stream_http {
              %{ for addr in ip_addrs ~}
              server ${addr}:32080;
              %{ endfor ~}
          }


          upstream stream_https {
              %{ for addr in ip_addrs ~}
              server ${addr}:32443;
              %{ endfor ~}
          }

          server {
              listen 80;
              proxy_pass stream_http;
          }	

          server {
              listen 443;
              proxy_pass stream_https;
          }	
      }
    path: /etc/nginx/nginx.conf
  
runcmd:
  # Setup tailscale connection
  - tailscale up -authkey ${tailscale_auth_key}

  # Open port 80 and 443
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

  # Reload nginx conf
  - systemctl reload nginx
