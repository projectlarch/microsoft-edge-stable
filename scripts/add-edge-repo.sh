#!/bin/sh
# Add Microsoft's Edge yum repository and trust its signing key. Runs as root in a Fedora container.
# Writes nothing to stdout, so callers can capture the output of the scripts that use it.
set -eu

KEY_URL=https://packages.microsoft.com/keys/microsoft.asc

cat > /etc/yum.repos.d/microsoft-edge.repo <<EOF
[microsoft-edge]
name=Microsoft Edge
baseurl=https://packages.microsoft.com/yumrepos/edge
enabled=1
gpgcheck=1
gpgkey=$KEY_URL
EOF

rpm --import "$KEY_URL" >&2
