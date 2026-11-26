#!/usr/bin/env bash
# Writes ../vars/vault_unseal.yml: the unseal keys from the macOS keychain (vault-unseal-N),
# encrypted with ansible-vault. Prompts for the Ansible Vault password; enter the same one in
# the AAP credential homelab-ansible-vault. Plain-text keys only ever exist in a 600 temp file.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=vars/vault_unseal.yml

read -rsp "Ansible Vault password: " p1; echo
read -rsp "Again: " p2; echo
[[ "$p1" == "$p2" && -n "$p1" ]] || { echo "Passwords don't match or are empty." >&2; exit 1; }

umask 077
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '%s' "$p1" > "$tmp/pass"; unset p1 p2

{
  echo "---"
  echo "vault_unseal_keys:"
  i=1
  while key=$(security find-generic-password -a vault -s "vault-unseal-$i" -w 2>/dev/null); do
    echo "  - \"$key\""
    i=$((i+1))
  done
} > "$tmp/keys.yml"
n=$(grep -c '^  - ' "$tmp/keys.yml" || true)
[[ "$n" -gt 0 ]] || { echo "No vault-unseal-N items in the keychain." >&2; exit 1; }

ansible-vault encrypt --vault-password-file "$tmp/pass" --output "$OUT" "$tmp/keys.yml"
echo "Wrote $OUT ($n keys, encrypted). Commit it, then set the same password in AAP credential homelab-ansible-vault."
