#!/bin/bash
set -euo pipefail

# start sonarqube container image
docker run -d --name sonarqube -p 9000:9000 sonarqube:community

# Install trivy

apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install trivy
trivy --version


# Install kubectl

curl -LO https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl
curl -LO https://dl.k8s.io/release/v1.36.5/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Add jenkins to sudoers

if ! id jenkins >/dev/null 2>&1; then
    echo "User 'jenkins' does not exist." >&2
    exit 1
fi

sudoers_file="/etc/sudoers.d/jenkins"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

printf '%s\n' 'jenkins ALL=(ALL) NOPASSWD: ALL' > "$tmp_file"
chmod 0440 "$tmp_file"

visudo -cf "$tmp_file"
install -o root -g root -m 0440 "$tmp_file" "$sudoers_file"
visudo -c

echo "Configured passwordless sudo for jenkins."

# Install dependecies

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre

install -d -m 0755 /etc/apt/keyrings

# Node.js 22, matching the Node major version used by the Docker images.

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
cat > /etc/apt/sources.list.d/nodesource.sources <<EOF
Types: deb
URIs: https://deb.nodesource.com/node_22.x
Suites: nodistro
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/nodesource.gpg
EOF

apt-get update
apt-get install -y nodejs 

echo
echo "Installed tool versions:"
java -version
node --version
npm --version
docker --version
docker compose version
