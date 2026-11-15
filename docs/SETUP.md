# ra-homelab setup guide

Step-by-step setup of the lab automation in AAP, from an empty AAP organisation to
a green end-to-end run. Follow the steps in order. Every value you type is listed;
secrets are entered only in the AAP UI or at a hidden prompt, never in files.

For how it works, see [DESIGN.md](DESIGN.md).

| Step | What | Where | Time |
| --- | --- | --- | --- |
| 1 | Check lab prerequisites | vCenter, ESXi | 5 min |
| 2 | Push the repo and create a GitHub token | Mac, GitHub | 5 min |
| 3 | Get an AAP API token | AAP UI, Mac | 5 min |
| 4 | Create the Terraform state folder | AAP VM | 2 min |
| 5 | Create the first four credentials | AAP UI | 10 min |
| 6 | Seed AAP (first run) | Mac | 2 min |
| 7 | Create the two custom-type credentials | AAP UI | 5 min |
| 8 | Seed AAP (second run) | Mac | 3 min |
| 9 | Run the workflow | AAP UI | 1-2 h first time |
| 10 | Seed again and run the test jobs | Mac, AAP UI | 5 min |

---

## 1. Lab prerequisites

| Item | Expected | Check |
| --- | --- | --- |
| vCenter | `https://vcsa.homelab.local/ui` loads | Browser |
| ESXi for VMs | 192.168.1.155, datastore `LocalDS`, port group `VM Network` | vCenter |
| vCenter folders | `Templates` and `MyVMs` exist under `Virtual_DC` | vCenter › VMs and Templates |
| Cluster name | `My_Cluster` (if different, edit the `*.tfvars` and `*.pkrvars.hcl` files) | vCenter |
| RHEL ISO | `[LocalDS] iso/rhel-10.1-x86_64-dvd.iso` | `ssh root@192.168.1.155 'ls /vmfs/volumes/LocalDS/iso/'` |
| Windows ISO | `[LocalDS] en-us_windows_server_2022_updated_nov_2024_x64.iso` | `ssh root@192.168.1.155 'ls /vmfs/volumes/LocalDS/*.iso'` |
| VMware Tools ISO | `/vmimages/tools-isoimages/windows.iso` on ESXi | `ssh root@192.168.1.155 'ls /vmimages/tools-isoimages/'` |
| AD DNS / DC | 192.168.1.200, domain `homelab.local` | `nslookup homelab.local 192.168.1.200` |
| AAP | `https://aap.lab.local` loads; you can log in as an admin | Browser |
| Internet from AAP | Jobs download from HashiCorp, GitHub, Galaxy, PyPI | (first workflow run shows it) |
| Red Hat account | Developer account (free) for RHEL registration | access.redhat.com |

## 2. GitHub repo and token

**2.1 Push the code** (skip if `git status` shows it is already pushed):

```bash
cd ~/ra-homelab
git remote -v || git remote add origin https://github.com/RamAdhikari/ra-homelab.git
git push -u origin main
```

**2.2 Create a token AAP can read the repo with:** GitHub › Settings › Developer
settings › Personal access tokens › **Fine-grained tokens** › Generate new token.

| Field | Value |
| --- | --- |
| Name | `aap-homelab` |
| Expiration | 90 days (note the date) |
| Repository access | Only select repositories › `RamAdhikari/ra-homelab` |
| Permissions › Repository › Contents | **Read-only** |
| Permissions › Repository › Metadata | Read-only (set automatically) |

Copy the token; GitHub shows it once. You need it in step 5.

## 3. AAP API token (for running the seed from the Mac)

**3.1 Create the token:** log in to `https://aap.lab.local` as your admin user (or
`claude`) › user menu (top right) › User details › **API tokens** › Create.
Scope **Write**. Copy it; AAP shows it once.

**3.2 Store it in the macOS Keychain** (encrypted; nothing in files or shell history):

```bash
security add-generic-password -U -s aap-lab-token -a "$USER" -w
# paste the token at the prompt
```

**3.3 Load it in any terminal where you run the seed:**

```bash
export CONTROLLER_HOST=https://aap.lab.local CONTROLLER_VERIFY_SSL=false
export CONTROLLER_OAUTH_TOKEN=$(security find-generic-password -s aap-lab-token -w)
```

> Make a **second** token the same way for the `homelab-aap-api` credential in step 5.
> Separate tokens let you revoke one without breaking the other.

**3.4 Collections on the Mac** (once):

```bash
cd ~/ra-homelab
ansible-galaxy collection install -r collections/requirements.yml
```

If this fails with `CERTIFICATE_VERIFY_FAILED`, give Python the macOS CA bundle and retry:

```bash
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain /Library/Keychains/System.keychain > ~/.mac-ca-bundle.pem
echo 'export SSL_CERT_FILE=~/.mac-ca-bundle.pem' >> ~/.zshrc && export SSL_CERT_FILE=~/.mac-ca-bundle.pem
```

## 4. Terraform state folder on the AAP VM

Jobs run in throwaway containers, so Terraform state lives on the AAP host.

```bash
ssh -t aap@aap.lab.local '
  sudo install -d -m 0777 -o aap -g aap /var/lib/homelab-tfstate &&
  sudo semanage fcontext -a -t container_file_t "/var/lib/homelab-tfstate(/.*)?" &&
  sudo restorecon -Rv /var/lib/homelab-tfstate &&
  ls -ldZ /var/lib/homelab-tfstate'
```

The listing must show `container_file_t`. If `semanage` is missing:
`sudo dnf -y install policycoreutils-python-utils`.

If VMs were already created from the Mac, copy their state so AAP adopts them
instead of creating duplicates:

```bash
scp ~/ra-homelab/terraform/rhel-vms/terraform.tfstate aap@aap.lab.local:/var/lib/homelab-tfstate/rhel-vms.tfstate
ssh -t aap@aap.lab.local 'sudo chmod 0666 /var/lib/homelab-tfstate/*.tfstate'
```

## 5. Credentials, part 1 (built-in types)

In AAP: **Automation Execution › Infrastructure › Credentials › Create credential**.
Organisation for all of them: **Default**. Names must match exactly.

### 5.1 `homelab-github`

| Field | Value |
| --- | --- |
| Credential type | Source Control |
| Username | your GitHub username (`RamAdhikari`) |
| Password | the fine-grained token from step 2.2 |

### 5.2 `homelab-vcenter`

| Field | Value |
| --- | --- |
| Credential type | VMware vCenter |
| vCenter Host | `vcsa.homelab.local` |
| Username | `Administrator@HOMELAB.LOCAL` |
| Password | vCenter SSO administrator password |
| Verify SSL | **Off** (self-signed lab certificate) |

### 5.3 `homelab-labadmin`

| Field | Value |
| --- | --- |
| Credential type | Machine |
| Username | `labadmin` |
| Password | the `labadmin` password (same as the RHEL template build password) |
| Privilege Escalation Method | `sudo` |
| Privilege Escalation Username / Password | leave empty (`labadmin` has passwordless sudo) |

### 5.4 `homelab-aap-api`

| Field | Value |
| --- | --- |
| Credential type | Red Hat Ansible Automation Platform |
| Red Hat Ansible Automation Platform (host) | **`https://host.containers.internal`** |
| OAuth Token | the second token from step 3 |
| Username / Password | leave empty |
| Verify SSL | **Off** |

Why not `https://aap.lab.local`: jobs run in rootless Podman containers on the AAP
host, and from inside them the host's own IP is not reachable.
`host.containers.internal` is Podman's name for the host. It only works from jobs;
you keep using `https://aap.lab.local` in the browser and on the Mac.

### 5.5 Galaxy credential on the organisation

The project installs collections from Galaxy at every sync. Check:
**Access Management › Organizations › Default › Galaxy credentials** lists
`Ansible Galaxy`. Add it if missing.

## 6. Seed AAP, first run

```bash
cd ~/ra-homelab
export CONTROLLER_HOST=https://aap.lab.local CONTROLLER_VERIFY_SSL=false
export CONTROLLER_OAUTH_TOKEN=$(security find-generic-password -s aap-lab-token -w)
ansible-playbook aap/seed.yml
```

Expected: it creates the credential types **Homelab lab secrets** and **Homelab
domain join**, the inventory, and the Terraform state-path setting, then **stops
on purpose** with:

```
Create these credentials in AAP (organisation Default), then rerun:
{"name": "homelab-lab-secrets", ...}, {"name": "homelab-domain-join", ...}
```

## 7. Credentials, part 2 (custom types)

### 7.1 `homelab-lab-secrets`

| Field | Value |
| --- | --- |
| Credential type | **Homelab lab secrets** |
| labadmin password baked into the template | the `labadmin` password. Also becomes the Windows local Administrator password |
| Red Hat login | your Red Hat account username |
| Red Hat password | your Red Hat account password |

### 7.2 `homelab-domain-join`

| Field | Value |
| --- | --- |
| Credential type | **Homelab domain join** |
| Domain join user | an AD account allowed to join computers, in UPN form, e.g. `administrator@homelab.local` |
| Domain join password | that account's password |

## 8. Seed AAP, second run

```bash
ansible-playbook aap/seed.yml
```

Expected: no failed tasks. It syncs the project from GitHub, creates the job
templates (10, 11, 20, 21, 30, 40, 50, 60, 61, 70) and the workflow
**homelab - Vault SSH lab (end to end)**.

If "Sync the project from GitHub" fails, read the sync log:

```bash
ID=$(curl -sk -H "Authorization: Bearer $CONTROLLER_OAUTH_TOKEN" \
  "https://aap.lab.local/api/controller/v2/project_updates/?project__name=ra-homelab&order_by=-id&page_size=1" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["results"][0]["id"])')
curl -sk -H "Authorization: Bearer $CONTROLLER_OAUTH_TOKEN" \
  "https://aap.lab.local/api/controller/v2/project_updates/$ID/stdout/?format=txt" | tail -40
```

## 9. Run the workflow

AAP › Templates › **homelab - Vault SSH lab (end to end)** › Launch.

| Job | First run | What success looks like |
| --- | --- | --- |
| 10 RHEL template | ~10-40 min | "Template built" (or "already exists") |
| 11 Windows template | ~30-60 min | "tmpl-win2022 built" (or "already exists") |
| 20 RHEL VMs | ~5-10 min | Terraform applied; 3 hosts written to the inventory |
| 21 Windows VMs | ~15-30 min | Terraform applied (Sysprep + domain join); 2 hosts in `win_targets` |
| 30 RHEL bootstrap | ~3 min | Registered with Red Hat; BaseOS/AppStream enabled |
| 40 Vault | ~3 min | Vault initialised and unsealed |
| 50 Vault SSH CA | ~2 min | `vault-ssh-signer`, `rhel-svc-aap-signed`, `win-svc-aap-signed` created |
| 60 RHEL trust | ~1 min | `svc_aap` created; `TrustedUserCAKeys` set |
| 61 Windows OpenSSH | ~5 min | OpenSSH Server installed; `svc_aap` created; CA trusted |
| 70 Verify | ~1 min | "logged in as svc_aap with a Vault-signed certificate" for RHEL and Windows |

Watch template builds on the VM console in vCenter. Every job is safe to rerun;
rerunning the workflow skips anything already done.

## 10. Test job templates

Run the seed once more; it adds the templates that use the credentials job 50 created:

```bash
ansible-playbook aap/seed.yml
```

| Job template | Shows |
| --- | --- |
| homelab 90 - connectivity check (signed cert) | RHEL: host, user `svc_aap`, OS, uptime, certificate ID + serial |
| homelab 91 - Windows connectivity check (signed cert) | Windows: host, domain, user, OS, uptime, certificate ID + serial |
| homelab 80 - run job with JIT certificate | The certificate issued for the run and its 2-hour validity |

Launch one twice: the serial changes, because each run gets a fresh certificate.

## 11. Optional: Vault web UI

1. `https://192.168.1.29:8200/ui`, accept the self-signed certificate warning.
2. Method **Token**, with the root token (lab only):
   ```bash
   ssh labadmin@192.168.1.29 "sudo python3 -c \"import json;print(json.load(open('/root/vault-init.json'))['root_token'])\""
   ```

## 12. Credentials at a glance

| Credential | Type | Created by | Used by jobs | Rotate by |
| --- | --- | --- | --- | --- |
| `homelab-github` | Source Control | You (step 5.1) | project sync | New GitHub token, edit credential |
| `homelab-vcenter` | VMware vCenter | You (5.2) | 10, 11, 20, 21 | Edit credential after a vCenter password change |
| `homelab-labadmin` | Machine | You (5.3) | 30, 40, 50, 60 | Change on VMs, edit credential and `homelab-lab-secrets` |
| `homelab-aap-api` | Red Hat AAP | You (5.4) | 20, 21, 50, 70 | New AAP token, edit credential, delete the old token |
| `homelab-lab-secrets` | Homelab lab secrets | You (7.1) | 10, 11, 21, 30, 61 | Edit credential (rebuild templates for a new build password) |
| `homelab-domain-join` | Homelab domain join | You (7.2) | 21 | Edit credential |
| `vault-ssh-signer` | HashiCorp Vault Signed SSH | Job 50 | via the two below | Rerun job 50 (new AppRole secret ID) |
| `rhel-svc-aap-signed` | Machine (certificate from Vault) | Job 50 | 70, 80, 90 | Rerun job 50 (new key) |
| `win-svc-aap-signed` | Machine (certificate from Vault) | Job 50 | 70, 91 | Rerun job 50 (new key) |

## 13. Quick troubleshooting

| Symptom | Fix |
| --- | --- |
| Seed: 401 / 404 | Token not loaded or expired: step 3.3; create a new token |
| Seed stops listing credentials | Expected on the first run: create them (step 7) and rerun |
| Project sync fails | Check `homelab-github` token and repo access; Galaxy credential on the organisation |
| Any job: `lsetxattr ... operation not permitted` | Step 4 labelling; the setting must be `/var/lib/homelab-tfstate:/var/lib/homelab-tfstate` with no `:z`/`:Z` |
| Job 20/21: `... is not writable inside the job` | Step 4: folder missing or not labelled |
| Job 20/21/50/70: AAP API timed out | `homelab-aap-api` host must be `https://host.containers.internal` |
| Job 21: domain join timeout | Check the join account (UPN form) and that 192.168.1.200 answers DNS |
| Job 30: registration failed | Red Hat login in `homelab-lab-secrets` |
| Job 61: WinRM refused | Try username `.\Administrator`; check the Administrator password = `labadmin` password |
| Vault sealed after a host reboot | Rerun job 40 |

More history and causes: DESIGN.md section 13.
