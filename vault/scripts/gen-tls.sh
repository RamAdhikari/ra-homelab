#!/usr/bin/env bash
# Creates a lab CA and a server certificate for Vault. Re-run to renew the server cert; the CA is kept.
set -euo pipefail

cd "$(dirname "$0")/../tls"
: "${MAC_IP:?Set MAC_IP to the Mac IP on the lab network}"

if [[ ! -f ca.key ]]; then
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -key ca.key -sha256 -days 3650 \
    -subj "/CN=Homelab Vault CA" -out ca.crt
fi

cat > vault.ext <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:vault.homelab.local, DNS:localhost, IP:127.0.0.1, IP:${MAC_IP}
EOF

openssl genrsa -out vault.key 2048
openssl req -new -key vault.key -subj "/CN=vault.homelab.local" -out vault.csr
openssl x509 -req -in vault.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile vault.ext -out vault.crt
rm -f vault.csr vault.ext

chmod 600 ca.key vault.key
echo "Created tls/ca.crt and tls/vault.crt (SANs: vault.homelab.local, localhost, 127.0.0.1, ${MAC_IP})"
