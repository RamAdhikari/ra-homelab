# RHEL 10 template for the home lab (vsphere-iso, kickstart from an OEMDRV CD).
# Secrets come from the environment:
#   export PKR_VAR_vsphere_password='...'
#   export PKR_VAR_build_password='...'
# Run:  packer init . && packer validate . && packer build .

packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vsphere = {
      version = ">= 2.4.0"
      source  = "github.com/vmware/vsphere"
    }
  }
}

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
variable "iso_path" { type = string }
variable "vm_name" {
  type    = string
  default = "tmpl-rhel10"
}
# rhel9_64Guest works on any ESXi 7.0 U3+/8.x. Switch to rhel10_64Guest only if
# your ESXi build lists "Red Hat Enterprise Linux 10" as a guest OS.
variable "guest_os_type" {
  type    = string
  default = "rhel9_64Guest"
}
variable "build_username" {
  type    = string
  default = "labadmin"
}
variable "build_password" {
  type      = string
  sensitive = true
}

source "vsphere-iso" "rhel10" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  datacenter = var.datacenter
  cluster    = var.cluster
  host       = var.esxi_host
  datastore  = var.datastore
  folder     = var.folder

  vm_name       = var.vm_name
  guest_os_type = var.guest_os_type
  firmware      = "efi"
  CPUs          = 2
  RAM           = 4096
  notes         = "RHEL 10 base template. Built by Packer ${formatdate("YYYY-MM-DD", timestamp())}."

  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = 40960
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  iso_paths = [var.iso_path]

  # Anaconda auto-loads ks.cfg from any volume labelled OEMDRV, so no HTTP
  # server or inst.ks boot argument is needed.
  cd_label = "OEMDRV"
  cd_content = {
    "ks.cfg" = templatefile("${path.root}/ks.cfg.pkrtpl.hcl", {
      username = var.build_username
      password = var.build_password
    })
  }
  remove_cdrom = true

  boot_order = "disk,cdrom"
  boot_wait  = "5s"
  # Edit the first menu entry ("Install") and point Anaconda at the kickstart CD
  # explicitly; OEMDRV auto-detection did not fire on this build.
  boot_command = [
    "<up>e<wait><down><down><end><wait>",
    " inst.ks=cdrom:/ks.cfg<wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]

  communicator     = "ssh"
  ssh_username     = var.build_username
  ssh_password     = var.build_password
  ssh_timeout      = "60m"
  ip_wait_timeout  = "60m"
  shutdown_command = "sudo shutdown -P now"

  convert_to_template = true
}

build {
  sources = ["source.vsphere-iso.rhel10"]

  # Generalise so every clone gets its own identity.
  provisioner "shell" {
    inline = [
      "sudo dnf clean all",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo sh -c 'cat /dev/null > /var/log/wtmp'",
      "sudo sync"
    ]
  }
}
