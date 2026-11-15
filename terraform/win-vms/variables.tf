variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" {
  type      = string
  sensitive = true
}
variable "datacenter" { type = string }
variable "cluster" { type = string }
variable "esxi_host" { type = string }
variable "datastore" { type = string }
variable "network" { type = string }
variable "folder" { type = string }
variable "template_name" { type = string }
variable "domain_name" { type = string }
variable "dns_servers" { type = list(string) }
variable "time_zone" {
  description = "Windows time zone index (255 = AUS Eastern Standard Time)"
  type        = number
  default     = 255
}
variable "win_admin_password" {
  description = "Local Administrator password set on each clone (same as labadmin)"
  type        = string
  sensitive   = true
}
variable "domain_join_user" {
  type = string
}
variable "domain_join_password" {
  type      = string
  sensitive = true
}
variable "vms" {
  description = "VM name (also the Windows computer name, max 15 chars) => size"
  type = map(object({
    cpus      = number
    memory_mb = number
  }))
}
