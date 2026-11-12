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
variable "vms" {
  description = "VM name => size"
  type = map(object({
    cpus      = number
    memory_mb = number
  }))
}
