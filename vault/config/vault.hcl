ui            = true
disable_mlock = true

storage "raft" {
  path    = "/vault/file"
  node_id = "vault-mac"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file   = "/vault/tls/vault.crt"
  tls_key_file    = "/vault/tls/vault.key"
  tls_min_version = "tls12"
}

api_addr     = "https://vault.homelab.local:8200"
cluster_addr = "https://127.0.0.1:8201"
