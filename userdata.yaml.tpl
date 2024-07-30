#cloud-config

hostname: "droplet-proxy"
# hostname: "oracle-arm"
timezone: Europe/Paris

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
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJCNtGUButejGmyBdz3wfK1VvJ8nAnNzEgj4t995RjER julen@loudnaround.org


ssh_pwauth: false

package_upgrade: true

packages:
  - nginx
  - libnginx-mod-stream

package_reboot_if_required: true

write_files:
  - path: /etc/nginx/nginx.conf
    defer: true
    content: |
      user www-data;
      worker_processes auto;
      pid /run/nginx.pid;
      error_log /var/log/nginx/error.log;
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

runcmd:
  # One-command install, from https://tailscale.com/download/
  - curl -fsSL https://tailscale.com/install.sh | sh
  # Generate an auth key from your Admin console
  # https://login.tailscale.com/admin/settings/keys
  # Setup tailscale connection
  - tailscale up -authkey ${tailscale_auth_key}

  # # Open port 80 and 443 for ingress
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

  # # See https://docs.k0sproject.io/v1.23.8+k0s.0/networking/
  # # Open port 10250 for kubelet access
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 10250 -j ACCEPT
  # # Kube-router
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 179 -j ACCEPT
  # # Konnectivity
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8132 -j ACCEPT
  
  # # Save rules for reboot
  # - netfilter-persistent save

  # Reload nginx conf
  - systemctl restart nginx

final_message: "The system is finally up, after $UPTIME seconds"
