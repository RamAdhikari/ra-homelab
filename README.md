# ra-homelab

Home lab code: RHEL 10 template, lab VMs, and Vault as SSH CA for AAP.
Lab: VMware Fusion > nested ESXi (192.168.1.155) > vCenter `vcsa.homelab.local`.

None of this has been run yet. Validate each stage before the next.

## Layout

| Path | Purpose |
| --- | --- |
| `packer/rhel10/` | Packer `vsphere-iso` build of template `tmpl-rhel10` (kickstart, user `labadmin`) |
| `terraform/rhel-vms/` | Clones `lab-vault01`, `lab-rhel01`, `lab-rhel02` from the template |
| `ansible/vault_single.yml` | Single-node Vault on `lab-vault01` (Raft, self-signed TLS) |
| `terraform/vault-config/` | Vault SSH CA mount, signing role, policy, AppRole for AAP |
| `ansible/ssh_ca_trust.yml` | Targets trust the Vault CA; creates `svc_aap` |
| `ansible/set_hostnames.yml` | Names the clones and writes /etc/hosts (no guest customization on RHEL 10) |
| `aap/configure.yml` | AAP config as code: lab inventory, then Vault credentials and an ad hoc ping test |

## Run order

```bash
cp .env.example .env && vi .env && source .env

# 0. ISO on the datastore (ESXi SSH enabled)
ssh root@192.168.1.155 'mkdir -p /vmfs/volumes/LocalDS/iso'
scp ~/Downloads/rhel-10.1-x86_64-dvd.iso root@192.168.1.155:/vmfs/volumes/LocalDS/iso/

# 1. Template (about 20-40 min nested)
cd packer/rhel10 && packer init . && packer validate . && packer build . && cd ../..

# 2. VMs
cd terraform/rhel-vms && terraform init && terraform apply && cd ../..

# 3. Vault (needs DNS for lab-*.homelab.local, or put the IPs in inventory.ini)
cd ansible
ansible-playbook -i inventory.ini vault_single.yml -k
export VAULT_ADDR=https://lab-vault01.homelab.local:8200 VAULT_CACERT=$PWD/vault-ca.pem
vault operator init -key-shares=1 -key-threshold=1     # lab only; save the output
vault operator unseal                                   # paste the unseal key
export VAULT_TOKEN=<root token>
vault audit enable file file_path=/var/log/vault/audit.log

# 4. SSH CA + AppRole
cd ../terraform/vault-config && terraform init && terraform apply
vault write -f -field=secret_id auth/approle/role/aap-controller/secret-id

# 5. Host trust
cd ../../ansible && ansible-playbook -i inventory.ini ssh_ca_trust.yml -k

# 6. AAP config as code (phase 1 any time; phase 2 once the two AAP_VAULT_* vars are set)
cd ../aap && ansible-galaxy collection install -r requirements.yml
export CONTROLLER_HOST=https://aap.lab.local CONTROLLER_VERIFY_SSL=false
read -s "CONTROLLER_OAUTH_TOKEN?AAP token: "; export CONTROLLER_OAUTH_TOKEN
export AAP_VAULT_ROLE_ID=... AAP_VAULT_SECRET_ID=...
ansible-playbook configure.yml

# 7. Test by hand
vault write -field=signed_key ssh-client-signer/sign/aap-linux \
  public_key=@aap_key.pub valid_principals=svc_aap > aap_key-cert.pub
ssh -i aap_key -o CertificateFile=aap_key-cert.pub svc_aap@lab-rhel01.homelab.local 'sudo -n true && echo OK'
```

## Known risks

- RHEL 10 needs an x86-64-v3 CPU (AVX2). The installer will refuse to boot if the
  nested CPU does not expose it.
- vSphere guest customization of RHEL 10 depends on the vCenter version. If the clone
  fails at customization, remove the `customize` block and set hostnames with Ansible.
- `guest_os_type` defaults to `rhel9_64Guest` for compatibility with older ESXi.
- A Vault restart leaves it sealed: run `vault operator unseal` again.
