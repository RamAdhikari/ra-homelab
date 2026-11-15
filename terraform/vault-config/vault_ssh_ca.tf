# Vault SSH CA + AppRole for AAP. Apply after Vault is initialised and unsealed:
#   export VAULT_ADDR=https://lab-vault01.homelab.local:8200
#   export VAULT_CACERT=../../ansible/vault-ca.pem
#   export VAULT_TOKEN=<admin or root token>
terraform {
  # State path is passed at init: -backend-config=path=/var/lib/homelab-tfstate/vault-config.tfstate
  backend "local" {}
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4" # matches the mirror in roles/hashicorp_tools
    }
  }
}

provider "vault" {}

variable "aap_controller_cidrs" {
  description = "Source addresses Vault sees AAP coming from"
  type        = list(string)
  default     = ["192.168.1.0/24"] # lab: whole subnet. Tighten to the AAP host /32.
}

variable "ssh_cert_ttl" {
  description = "Lifetime of each signed SSH certificate, in seconds. AAP gets a new one per job."
  type        = number
  default     = 7200
}

resource "vault_mount" "ssh" {
  path        = "ssh-client-signer"
  type        = "ssh"
  description = "SSH user CA for AAP"
}

resource "vault_ssh_secret_backend_ca" "ca" {
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "aap_linux" {
  backend                 = vault_mount.ssh.path
  name                    = "aap-linux"
  key_type                = "ca"
  algorithm_signer        = "rsa-sha2-256"
  allow_user_certificates = true
  allow_host_certificates = false
  allowed_users           = "svc_aap"
  default_user            = "svc_aap"
  allowed_extensions      = "permit-pty"
  default_extensions      = { "permit-pty" = "" }
  key_id_format           = "aap-{{token_display_name}}-{{public_key_hash}}"
  ttl                     = var.ssh_cert_ttl
  max_ttl                 = var.ssh_cert_ttl
}

resource "vault_policy" "aap_ssh_sign" {
  name   = "aap-ssh-sign"
  policy = <<-EOT
    path "ssh-client-signer/sign/aap-linux" {
      capabilities = ["create", "update"]
    }
  EOT
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "aap" {
  backend               = vault_auth_backend.approle.path
  role_name             = "aap-controller"
  token_policies        = [vault_policy.aap_ssh_sign.name]
  token_ttl             = 600
  token_max_ttl         = 1200
  token_bound_cidrs     = var.aap_controller_cidrs
  secret_id_bound_cidrs = var.aap_controller_cidrs
  secret_id_ttl         = 7776000
}

output "aap_role_id" {
  value = vault_approle_auth_backend_role.aap.role_id
}

output "ssh_ca_public_key" {
  value = vault_ssh_secret_backend_ca.ca.public_key
}
