terraform {
  required_version = ">= 1.3"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

# Address, token and CA come from VAULT_ADDR, VAULT_TOKEN and VAULT_CACERT.
provider "vault" {}

resource "vault_audit" "file" {
  type = "file"
  options = {
    file_path = "/vault/logs/audit.log"
  }
}

resource "vault_mount" "homelab" {
  path        = "homelab"
  type        = "kv"
  options     = { version = "2" }
  description = "Home lab secrets. One path per project, plus shared/."
}

resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_policy" "snapshot" {
  name   = "snapshot"
  policy = <<-EOT
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "project" {
  for_each = var.projects
  name     = each.key
  policy   = <<-EOT
    path "homelab/data/${each.key}/*" {
      capabilities = ["read"]
    }
    path "homelab/metadata/${each.key}/*" {
      capabilities = ["read", "list"]
    }
    path "homelab/data/shared/*" {
      capabilities = ["read"]
    }
    path "homelab/metadata/shared/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "project" {
  for_each              = var.projects
  backend               = vault_auth_backend.approle.path
  role_name             = each.key
  token_policies        = concat([vault_policy.project[each.key].name], each.value.extra_policies)
  token_ttl             = 3600
  token_max_ttl         = 14400
  secret_id_bound_cidrs = var.client_cidrs
  token_bound_cidrs     = var.client_cidrs
}

output "approle_role_ids" {
  value = { for k, r in vault_approle_auth_backend_role.project : k => r.role_id }
}
