#!/usr/bin/env bash
# One-off: initialises Vault. Writes the unseal keys and root token to ~/vault.init.json (mode 600).
# Move them into your password manager, then delete the file. KEYCHAIN=1 also stores the unseal keys
# in the macOS login keychain so unseal.sh can run without prompting.
set -euo pipefail

SHARES="${SHARES:-3}"
THRESHOLD="${THRESHOLD:-2}"
OUT="$HOME/vault.init.json"

[[ -e "$OUT" ]] && { echo "$OUT already exists; refusing to overwrite." >&2; exit 1; }

umask 077
docker exec vault vault operator init \
  -key-shares="$SHARES" -key-threshold="$THRESHOLD" -format=json > "$OUT"

if [[ "${KEYCHAIN:-0}" == "1" ]]; then
  for i in $(seq 1 "$SHARES"); do
    key=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['unseal_keys_b64'][int(sys.argv[2])])" "$OUT" "$((i-1))")
    security add-generic-password -U -a vault -s "vault-unseal-$i" -w "$key"
  done
  echo "Unseal keys stored in the login keychain as vault-unseal-1..$SHARES."
fi

echo "Initialised. Keys and root token are in $OUT."
echo "Next: make unseal, then make configure. Move $OUT into your password manager and delete it."
