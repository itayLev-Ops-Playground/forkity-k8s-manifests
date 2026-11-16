#!/bin/bash
set -euo pipefail
curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh
usermod -aG docker jenkins
usermod -aG docker ubuntu
chmod 777 /var/run/docker.sock

systemctl enable docker --now