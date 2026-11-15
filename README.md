# ra-homelab

Home lab automation, run entirely from AAP: RHEL 10 template (Packer), lab VMs
(Terraform), Vault as an SSH CA, and AAP logging in to RHEL with Vault-signed
SSH certificates.

Full design, decisions and troubleshooting history: [docs/DESIGN.md](docs/DESIGN.md).

Lab: VMware Fusion > nested ESXi > vCenter `vcsa.homelab.local`; VMs on ESXi
`192.168.1.155`; AAP at `https://aap.lab.local`.

## How it runs

One AAP workflow, **homelab - Vault SSH lab (end to end)**, chains seven job
templates. Every step is idempotent, so the workflow can be rerun at any time.

| # | Job template | Playbook | What it does | Credentials |
| --- | --- | --- | --- | --- |
| 10 | build RHEL 10 template | `playbooks/10_build_template.yml` | Packer builds `tmpl-rhel10`; skips if it exists (`rebuild_template=true` to replace) | vcenter, lab-secrets |
| 20 | provision VMs | `playbooks/20_provision_vms.yml` | Terraform clones `lab-vault01`, `lab-rhel01`, `lab-rhel02`; writes their IPs into the AAP inventory | vcenter, aap-api |
| 30 | bootstrap hosts | `playbooks/30_bootstrap_hosts.yml` | Hostnames, `/etc/hosts`, Red Hat registration | labadmin, lab-secrets |
| 40 | install Vault | `playbooks/40_vault_install.yml` | Vault on `lab-vault01`: TLS, init, unseal, audit | labadmin |
| 50 | configure Vault SSH CA | `playbooks/50_vault_configure.yml` | Terraform SSH CA + AppRole; creates AAP credentials `vault-ssh-signer` and `rhel-svc-aap-signed` | labadmin, aap-api |
| 60 | trust SSH CA on targets | `playbooks/60_ssh_ca_trust.yml` | Targets trust the CA; creates `svc_aap` | labadmin |
| 70 | verify signed SSH | `playbooks/70_verify.yml` | AAP ad hoc `id -un` as `svc_aap` using only the signed certificate | aap-api |

Packer and Terraform are downloaded (pinned, SHA256-verified) into the job
container by `roles/hashicorp_tools`, so the default execution environment
works without a custom image.

## One-time setup

1. **Push to GitHub.** Create an empty private repo `RamAdhikari/ra-homelab`, then:
   ```bash
   cd ~/ra-homelab
   git remote add origin https://github.com/RamAdhikari/ra-homelab.git
   git push -u origin main
   ```

2. **Credentials in AAP** (organisation `Default`; enter the secrets in the UI):

   | Name | Type | Values |
   | --- | --- | --- |
   | `homelab-github` | Source Control | GitHub username + fine-grained PAT (Contents: read) |
   | `homelab-vcenter` | VMware vCenter | `vcsa.homelab.local`, `Administrator@HOMELAB.LOCAL`, password |
   | `homelab-labadmin` | Machine | `labadmin` + the template build password |
   | `homelab-aap-api` | Red Hat Ansible Automation Platform | `https://host.containers.internal`, a token, verify SSL off (jobs run in rootless Podman on the AAP host; the host's own IP loops back into the container) |
   | `homelab-lab-secrets` | Homelab lab secrets (created by step 4) | build password, Red Hat login and password |

   `homelab-lab-secrets` can only be created after the first seed run creates its type.

3. **Terraform state directory on the AAP execution node:**
   ```bash
   ssh -t aap@aap.lab.local 'sudo install -d -m 0777 -o aap -g aap /var/lib/homelab-tfstate &&
     sudo semanage fcontext -a -t container_file_t "/var/lib/homelab-tfstate(/.*)?" &&
     sudo restorecon -Rv /var/lib/homelab-tfstate'
   ```
   The SELinux label lets job containers use the folder without relabelling it.
   Then copy the state of the VMs that already exist, so AAP manages them instead of cloning duplicates:
   ```bash
   scp ~/ra-homelab/terraform/rhel-vms/terraform.tfstate aap@aap.lab.local:/var/lib/homelab-tfstate/rhel-vms.tfstate
   ```
   `0777` is a lab shortcut that avoids UID mapping issues with rootless job containers.

4. **Seed AAP** (from the Mac, once; reruns are safe):
   ```bash
   cd ~/ra-homelab
   export CONTROLLER_HOST=https://aap.lab.local CONTROLLER_VERIFY_SSL=false
   read -s "CONTROLLER_OAUTH_TOKEN?AAP token: "; export CONTROLLER_OAUTH_TOKEN; echo
   ansible-playbook aap/seed.yml
   ```
   The first run creates the credential type, the inventory and the state-path
   setting, then stops listing any missing credentials. Create them and rerun;
   the second run creates the project, job templates and workflow.

## Run

AAP > Templates > **homelab - Vault SSH lab (end to end)** > Launch.

## Lab-only shortcuts

- Vault runs as one node with a self-signed certificate and one unseal key.
- The unseal key and root token are stored in `/root/vault-init.json` on the
  Vault VM, and `vault-lab-unseal.service` unseals at boot. Not for production.
- AppRole is bound to `192.168.1.0/24` (`vars/lab.yml`); tighten to the AAP node.
- The VMs use DHCP; job 20 rewrites the inventory IPs on every run.

## Layout

```
aap/seed.yml                   AAP config as code (credential type, project, templates, workflow)
playbooks/                     the seven job playbooks + tasks/terraform.yml + templates/
roles/hashicorp_tools/         downloads Packer and Terraform into the job container
packer/rhel10/                 vsphere-iso build + kickstart
terraform/rhel-vms/            VM clones (state: /var/lib/homelab-tfstate/rhel-vms.tfstate)
terraform/vault-config/        Vault SSH CA + AppRole (state: .../vault-config.tfstate)
vars/lab.yml                   shared non-secret settings
collections/requirements.yml   installed by AAP on project sync
```
