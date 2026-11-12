# Non-secret lab values. Password: TF_VAR_vsphere_password (see ../../.env.example).
vsphere_server = "vcsa.homelab.local"
vsphere_user   = "Administrator@HOMELAB.LOCAL"
datacenter     = "Virtual_DC"
cluster        = "My_Cluster"
esxi_host      = "192.168.1.155"
datastore      = "LocalDS"
network        = "VM Network"
folder         = "MyVMs"
template_name  = "tmpl-rhel10"
domain_name    = "homelab.local"
dns_servers    = ["192.168.1.200", "192.168.1.1"]

vms = {
  "lab-vault01" = { cpus = 2, memory_mb = 4096 }
  "lab-rhel01"  = { cpus = 2, memory_mb = 2048 }
  "lab-rhel02"  = { cpus = 2, memory_mb = 2048 }
}
