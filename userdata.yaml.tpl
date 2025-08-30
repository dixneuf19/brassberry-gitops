#cloud-config

hostname: "oracle-arm-${hostname_suffix}"
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
ssh_pwauth: false

# May block tailscale initialization

# package_upgrade: true

packages:
  - nginx
  - libnginx-mod-stream

# May block tailscale initialization
# package_reboot_if_required: true

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

          upstream stream_lms_player {
              %{ for addr in ip_addrs ~}
              server ${addr}:32483;
              %{ endfor ~}
          }

          upstream stream_lms_web {
              %{ for addr in ip_addrs ~}
              server ${addr}:30900;
              %{ endfor ~}
          }

          upstream stream_lms_cli {
              %{ for addr in ip_addrs ~}
              server ${addr}:30990;
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

          server {
              listen 3483;
              proxy_pass stream_lms_player;
          }

          server {
              listen 3483 udp;
              proxy_pass stream_lms_player;
          }

          server {
              listen 9000;
              proxy_pass stream_lms_web;
          }

          server {
              listen 9090;
              proxy_pass stream_lms_cli;
          }
      }

runcmd:
  # One-command install, from https://tailscale.com/download/
  - curl -fsSL https://tailscale.com/install.sh | sh
  - [
      "sh",
      "-c",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf && echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf && sudo sysctl -p /etc/sysctl.d/99-tailscale.conf",
    ]
  # Make this node available over Tailscale SSH
  - tailscale set --ssh
  # Configure this machine as an exit node
  - tailscale set --advertise-exit-node
  # Configure this machine as a relay node
  # Generate an auth key from your Admin console
  # https://login.tailscale.com/admin/settings/keys
  # Setup tailscale connection
  - tailscale up -authkey ${tailscale_auth_key}

  # Open port 22 for SSH access
  # To use for debugging
  # - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 22 -j ACCEPT

  # Open port 80 and 443 for ingress
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

  # Open port 3483 for LMS player
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 3483 -j ACCEPT
  - iptables -I INPUT 6 -m state --state NEW -p udp --dport 3483 -j ACCEPT
  # Open port 9000 for LMS web
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 9000 -j ACCEPT
  # Open port 9090 for LMS cli
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 9090 -j ACCEPT

  # See https://docs.k0sproject.io/v1.23.8+k0s.0/networking/
  # Open port 10250 for kubelet access
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 10250 -j ACCEPT
  # Kube-router
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 179 -j ACCEPT
  # Konnectivity
  - iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8132 -j ACCEPT

  # Save rules for reboot
  - netfilter-persistent save

  # Restart nginx
  - systemctl restart nginx

final_message: "The system is finally up, after $UPTIME seconds"
