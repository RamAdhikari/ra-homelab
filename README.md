# ra-homelab

AAP logs in to RHEL and Windows servers with **just-in-time SSH certificates**
signed by HashiCorp Vault: a new certificate per job, valid 2 hours, only for the
service account `svc_aap`. No stored passwords or static keys.

Everything, from VM templates to the final login test, is code in this repo and
runs from one AAP workflow.

**Full design, flows and troubleshooting history: [docs/DESIGN.md](docs/DESIGN.md).**

## Run it

AAP › Templates › **homelab - Vault SSH lab (end to end)** › Launch.

| # | Job template | What it does |
| --- | --- | --- |
| 10 | build RHEL 10 template | Packer builds `tmpl-rhel10` (skips if it exists) |
| 11 | build Windows 2022 template | Packer builds `tmpl-win2022` (skips if it exists) |
| 20 | provision VMs | Terraform clones `lab-vault01`, `lab-rhel01`, `lab-rhel02` |
| 21 | provision Windows VMs | Terraform clones `lab-win01`, `lab-win02` from `tmpl-win2022`, joins `homelab.local` |
| 30 | bootstrap hosts | RHEL hostnames, Red Hat registration and signing key |
| 40 | install Vault | Vault on `lab-vault01`: TLS, init, unseal, audit |
| 50 | configure Vault SSH CA | SSH CA + AppRole; creates AAP credentials `rhel-svc-aap-signed`, `win-svc-aap-signed` |
| 60 | trust SSH CA on targets | RHEL: `svc_aap` + trust the Vault CA |
| 61 | Windows OpenSSH + trust SSH CA | Windows: OpenSSH Server, `svc_aap`, trust the Vault CA |
| 70 | verify signed SSH | Logs in to RHEL and Windows with certificates only |

Quick tests: **homelab 90** (RHEL) and **homelab 91** (Windows) show hostname, user,
uptime and the certificate serial for each server. **homelab 80** shows the full
certificate issued for a run.

## One-time setup

1. **Push to GitHub** (`RamAdhikari/ra-homelab`, private).
2. **Create credentials in AAP** (organisation `Default`):

   | Name | Type | Values |
   | --- | --- | --- |
   | `homelab-github` | Source Control | GitHub username + PAT (Contents: read) |
   | `homelab-vcenter` | VMware vCenter | `vcsa.homelab.local`, `Administrator@HOMELAB.LOCAL`, password |
   | `homelab-labadmin` | Machine | `labadmin` + its password |
   | `homelab-aap-api` | Red Hat Ansible Automation Platform | `https://host.containers.internal`, API token, verify SSL off |
   | `homelab-lab-secrets` | Homelab lab secrets *(created by the seed)* | `labadmin` password (also the Windows local Administrator password), Red Hat login + password |
   | `homelab-domain-join` | Homelab domain join *(created by the seed)* | AD account allowed to join computers, + password |

   `homelab-aap-api` uses `host.containers.internal` because jobs run in rootless
   Podman on the AAP host, where the host's own IP is not reachable. You keep
   using `https://aap.lab.local` in the browser and from the Mac.

3. **Terraform state folder on the AAP host:**
   ```bash
   ssh -t aap@aap.lab.local 'sudo install -d -m 0777 -o aap -g aap /var/lib/homelab-tfstate &&
     sudo semanage fcontext -a -t container_file_t "/var/lib/homelab-tfstate(/.*)?" &&
     sudo restorecon -Rv /var/lib/homelab-tfstate'
   ```

4. **Seed AAP** (from the Mac; safe to rerun):
   ```bash
   cd ~/ra-homelab
   export CONTROLLER_HOST=https://aap.lab.local CONTROLLER_VERIFY_SSL=false
   read -s "CONTROLLER_OAUTH_TOKEN?AAP token: "; export CONTROLLER_OAUTH_TOKEN; echo
   ansible-playbook aap/seed.yml
   ```
   The first run creates the two custom credential types and stops, listing the
   credentials to create. Create them and rerun. After the workflow has run once,
   run the seed again to add test templates 80, 90 and 91.

## Layout

```
aap/seed.yml                   AAP config as code
playbooks/                     one playbook per job template
roles/hashicorp_tools/         Packer, Terraform and providers for the job container
packer/rhel10/                 RHEL 10 template
packer/win2022/                Windows Server 2022 template
terraform/rhel-vms/            Vault + RHEL VMs
terraform/win-vms/             Windows VMs (domain-joined)
terraform/vault-config/        Vault SSH CA, role, policy, AppRole
vars/lab.yml                   shared non-secret settings
docs/DESIGN.md                 design document
```

## Lab-only shortcuts

Single Vault node with a self-signed certificate; unseal key and root token stored
on the Vault VM so it unseals itself after reboots; AppRole limited to the whole
`192.168.1.0/24`; `svc_aap` has full sudo / local Administrator rights. See
DESIGN.md section 12 for the production equivalents.
