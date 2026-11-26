#!/usr/bin/env bash
# Saves a Raft snapshot to backups/ and keeps the newest $KEEP.
# Token: $VAULT_TOKEN, or the keychain item vault-snapshot-token (a periodic token with the snapshot policy).
set -euo pipefail

cd "$(dirname "$0")/.."
ADDR="https://127.0.0.1:8200"
KEEP="${KEEP:-14}"
TOKEN="${VAULT_TOKEN:-$(security find-generic-password -a vault -s vault-snapshot-token -w)}"
CURL=(curl -sS --fail --cacert tls/ca.crt -H "X-Vault-Token: $TOKEN")

mkdir -p backups
file="backups/vault-$(date +%Y%m%d-%H%M%S).snap"
"${CURL[@]}" "$ADDR/v1/sys/storage/raft/snapshot" -o "$file"
"${CURL[@]}" -X POST "$ADDR/v1/auth/token/renew-self" >/dev/null

# shellcheck disable=SC2012  # names are ours: vault-YYYYmmdd-HHMMSS.snap
ls -1t backups/vault-*.snap | tail -n +"$((KEEP+1))" | xargs -r rm -f
echo "Saved $file"
