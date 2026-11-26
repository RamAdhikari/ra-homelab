variable "projects" {
  description = "One KV path, policy and AppRole per project. extra_policies adds policies such as an SSH signing policy."
  type = map(object({
    extra_policies = optional(list(string), [])
  }))
  default = {
    golden-image-pipeline = {}
  }
}

variable "client_cidrs" {
  # Docker Desktop on macOS NATs published ports, so Vault sees the Docker VM's address, not the real client.
  # Binding to 192.168.1.0/24 would lock AAP out. Leave empty unless Vault sees real client IPs.
  description = "Networks allowed to use AppRole logins and tokens. Empty means no restriction."
  type        = list(string)
  default     = []
}
