#!/usr/bin/env bash
# Run once after `make configure`, with VAULT_TOKEN set to the root token.
# Creates your admin login and the snapshot token, then revokes the root token.
set -euo pipefail

cd "$(dirname "$0")/.."
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}" VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/ca.crt}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN to the root token}"
ADMIN_USER="${ADMIN_USER:-ram}"

read -rsp "New password for Vault user $ADMIN_USER: " pw; echo
PW="$pw" python3 -c 'import json,os;print(json.dumps({"password":os.environ["PW"],"token_policies":"admin","token_ttl":"8h"}))' | \
  curl -sS --fail --cacert "$VAULT_CACERT" -H "X-Vault-Token: $VAULT_TOKEN" \
  -X POST --data @- "$VAULT_ADDR/v1/auth/userpass/users/$ADMIN_USER" >/dev/null
unset pw

snap=$(curl -sS --fail --cacert "$VAULT_CACERT" -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
  --data '{"policies":["snapshot"],"period":"768h","no_parent":true,"display_name":"snapshot"}' \
  "$VAULT_ADDR/v1/auth/token/create-orphan" | python3 -c "import json,sys;print(json.load(sys.stdin)['auth']['client_token'])")
security add-generic-password -U -a vault -s vault-snapshot-token -w "$snap"
unset snap

echo "Admin user $ADMIN_USER created; snapshot token stored in the keychain as vault-snapshot-token."
read -rp "Revoke the root token now? [y/N] " yn
if [[ "$yn" == [yY] ]]; then
  curl -sS --fail --cacert "$VAULT_CACERT" -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
    "$VAULT_ADDR/v1/auth/token/revoke-self" >/dev/null
  echo "Root token revoked. From now on: vault login -method=userpass username=$ADMIN_USER"
fi
