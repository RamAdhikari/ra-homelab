#!/usr/bin/env bash
# Unseals Vault after a restart. Uses keys from the macOS keychain (vault-unseal-N) if present, otherwise prompts.
set -euo pipefail

cd "$(dirname "$0")/.."
ADDR="https://127.0.0.1:8200"
CURL=(curl -sS --cacert tls/ca.crt)

sealed() { "${CURL[@]}" "$ADDR/v1/sys/seal-status" | python3 -c "import json,sys;print(json.load(sys.stdin)['sealed'])"; }

[[ "$(sealed)" == "False" ]] && { echo "Vault is already unsealed."; exit 0; }

i=1
while [[ "$(sealed)" == "True" ]]; do
  if ! key=$(security find-generic-password -a vault -s "vault-unseal-$i" -w 2>/dev/null); then
    read -rsp "Unseal key $i: " key; echo
  fi
  printf '{"key":"%s"}' "$key" | "${CURL[@]}" -X PUT --data @- "$ADDR/v1/sys/unseal" >/dev/null
  i=$((i+1))
done

echo "Vault is unsealed."
