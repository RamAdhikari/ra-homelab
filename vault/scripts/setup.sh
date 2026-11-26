#!/usr/bin/env bash
# First-time setup in one go: TLS, start, init (keys to keychain), unseal, configure as code,
# admin user, snapshot token, daily snapshots. The root token is read from ~/vault.init.json
# into this process only and never printed.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Create .env from .env.example and set MAC_IP first." >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a
export VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="$PWD/tls/ca.crt"

for c in docker terraform openssl curl python3 security; do
  command -v "$c" >/dev/null || { echo "Missing: $c" >&2; exit 1; }
done

[[ -f tls/vault.crt ]] || scripts/gen-tls.sh
docker compose up -d

echo "Waiting for Vault..."
until curl -s --cacert "$VAULT_CACERT" -o /dev/null "$VAULT_ADDR/v1/sys/seal-status"; do sleep 2; done

initialized=$(curl -s --cacert "$VAULT_CACERT" "$VAULT_ADDR/v1/sys/init" | python3 -c "import json,sys;print(json.load(sys.stdin)['initialized'])")
[[ "$initialized" == "True" ]] || KEYCHAIN=1 scripts/init.sh

scripts/unseal.sh

VAULT_TOKEN=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/vault.init.json')))['root_token'])")
export VAULT_TOKEN

(cd terraform && terraform init -input=false && terraform apply)
scripts/post-configure.sh

sed "s|__REPO__|$(cd .. && pwd)|" launchd/local.homelab.vault-snapshot.plist > ~/Library/LaunchAgents/local.homelab.vault-snapshot.plist
launchctl bootout "gui/$(id -u)/local.homelab.vault-snapshot" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/local.homelab.vault-snapshot.plist
unset VAULT_TOKEN
VAULT_TOKEN="" scripts/snapshot.sh

echo
echo "Done. Vault: https://${MAC_IP}:8200  (UI at /ui)"
echo "Now move ~/vault.init.json into your password manager and delete it."
