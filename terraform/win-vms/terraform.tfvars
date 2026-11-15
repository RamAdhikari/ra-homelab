# Non-secret lab values. Secrets come from AAP credentials as TF_VAR_*:
#   vsphere_password (homelab-vcenter), win_admin_password (homelab-lab-secrets),
#   domain_join_user / domain_join_password (homelab-domain-join).
vsphere_server = "vcsa.homelab.local"
vsphere_user   = "Administrator@HOMELAB.LOCAL"
datacenter     = "Virtual_DC"
cluster        = "My_Cluster"
esxi_host      = "192.168.1.155"
datastore      = "LocalDS"
network        = "VM Network"
folder         = "MyVMs"
template_name  = "Win2022-VM-Template"
domain_name    = "homelab.local"
dns_servers    = ["192.168.1.200", "192.168.1.1"]

vms = {
  "lab-win01" = { cpus = 2, memory_mb = 4096 }
  "lab-win02" = { cpus = 2, memory_mb = 4096 }
}
