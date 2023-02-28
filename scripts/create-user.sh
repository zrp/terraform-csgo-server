#!/usr/bin/env bash

# Create steam user
sudo adduser csgoserver --disabled-password -gecos ""

# Add csgoserver to sudo users
sudo usermod -aG sudo csgoserver
sudo su -c "echo 'csgoserver     ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Give .ssh access
sudo -i -u csgoserver bash <<EOF
# Give ssh access
mkdir -p .ssh
chmod 700 .ssh
touch .ssh/authorized_keys
chmod 600 .ssh/authorized_keys
TOKEN=$(curl -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key >> .ssh/authorized_keys
EOF

exit 0
