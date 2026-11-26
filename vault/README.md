# Home lab Vault

A single HashiCorp Vault for the whole lab, running in Docker Desktop on the Mac. Integrated (Raft) storage, TLS from a lab CA, and its mounts, policies and auth set up as code in `terraform/`.

## Layout in Vault

| Path | Use |
| --- | --- |
| `homelab/<project>/...` (KV v2) | Secrets for one project, e.g. `homelab/golden-image-pipeline/aws` |
| `homelab/shared/...` | Secrets several projects use, e.g. `homelab/shared/vcenter` |
| `auth/approle/role/<project>` | Machine login for a project (AAP uses this) |
| `auth/userpass/users/ram` | Your admin login |

Each project's policy reads its own path and `shared/` only. Add a project in `terraform/variables.tf` (`projects`) and run `make configure`.

## First-time setup

Needs Docker Desktop (set to start at login), Terraform 1.6 or later, and the `vault` CLI (`brew install hashicorp/tap/vault`).

```bash
cd vault
cp .env.example .env                 # set MAC_IP to the Mac's 192.168.1.x address
make setup                           # does everything below in one go, or run the steps yourself:
make tls                             # lab CA + server cert
make up
KEYCHAIN=1 make init                 # writes ~/vault.init.json; unseal keys also go to the keychain
make unseal
export VAULT_TOKEN=<root token from ~/vault.init.json>
make configure                       # Terraform: KV, policies, AppRole, userpass, audit log
make post-configure                  # admin user, snapshot token, then revoke the root token
make schedule-snapshots              # daily Raft snapshot to backups/, keeps 14
```

Then move `~/vault.init.json` into your password manager and delete it.

## Day to day

```bash
make unseal                          # after the Mac or Docker restarts; Vault starts sealed
vault login -method=userpass username=ram
vault kv put homelab/golden-image-pipeline/aws \
  access_key_id="$AWS_ACCESS_KEY_ID" secret_access_key="$AWS_SECRET_ACCESS_KEY"   # values from env, not history
```

## Using it from AAP

1. Copy `tls/ca.crt` to AAP and use it as the CA certificate in the Vault credentials.
2. Address: `https://<MAC_IP>:8200`. Check from the AAP VM: `curl --cacert ca.crt https://<MAC_IP>:8200/v1/sys/health`.
3. AppRole for a project:
   ```bash
   cd terraform && terraform output approle_role_ids
   vault write -f -field=secret_id auth/approle/role/golden-image-pipeline/secret-id
   ```
4. In AAP, create a HashiCorp Vault Secret Lookup credential with that role ID and secret ID, API version v2, path prefix `homelab`. Point credentials such as AWS at it as their input source, with paths like `golden-image-pipeline/aws` and keys `access_key_id` and `secret_access_key`.

## Moving the SSH CA here

If the Vault SSH CA from the earlier test runs somewhere else, re-create its SSH secrets engine on this Vault and give AAP's AppRole the signing policy through `extra_policies` in `projects`. Re-signing is quick, but the host CA public key on the RHEL and Windows targets (`TrustedUserCAKeys`) must be updated to this Vault's key.

## Notes

- Vault sees AAP's requests as coming from Docker Desktop's VM address, not the real client IP, so AppRole logins aren't bound to an IP range.
- If Vault can't read `tls/vault.key` on start (`docker compose logs vault`), run `chmod 644 tls/vault.key`. The file stays out of git.
- Restore: `vault operator raft snapshot restore -force backups/<file>.snap`.
- `make check` runs shellcheck, `terraform validate` and `docker compose config`.
