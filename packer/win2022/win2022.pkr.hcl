# Windows Server 2022 Standard (Desktop Experience) template for the home lab.
# BIOS boot; the answer file and setup scripts are on a Packer-made floppy (A:),
# so no ISO creation tool is needed in the AAP job container.
# Secrets: PKR_VAR_vsphere_password, PKR_VAR_build_password (Administrator password).
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
variable "os_iso_path" { type = string }
variable "tools_iso_path" {
  type    = string
  default = "[] /vmimages/tools-isoimages/windows.iso"
}
variable "vm_name" {
  type    = string
  default = "tmpl-win2022"
}
variable "build_password" {
  description = "Local Administrator password baked into the template (= labadmin password)"
  type        = string
  sensitive   = true
}

source "vsphere-iso" "win2022" {
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
  guest_os_type = "windows9Server64Guest"
  firmware      = "bios"
  CPUs          = 2
  RAM           = 4096
  notes         = "Windows Server 2022 Standard base template. Built by Packer ${formatdate("YYYY-MM-DD", timestamp())}."

  disk_controller_type = ["lsilogic-sas"]
  storage {
    disk_size             = 40960
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  # D: = Windows ISO, E: = VMware Tools (install-vm-tools.cmd runs e:\setup64)
  iso_paths    = [var.os_iso_path, var.tools_iso_path]
  remove_cdrom = true

  floppy_files = [
    "${path.root}/scripts/disable-network-discovery.cmd",
    "${path.root}/scripts/disable-server-manager.ps1",
    "${path.root}/scripts/disable-winrm.ps1",
    "${path.root}/scripts/enable-rdp.cmd",
    "${path.root}/scripts/enable-winrm.ps1",
    "${path.root}/scripts/install-vm-tools.cmd",
    "${path.root}/scripts/set-temp.ps1",
  ]
  floppy_content = {
    "autounattend.xml" = templatefile("${path.root}/autounattend.xml.pkrtpl", {
      # XML-escape the password for the answer file
      admin_password = replace(replace(replace(var.build_password, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
    })
  }

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.build_password
  winrm_timeout  = "2h"
  ip_wait_timeout = "2h"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer shutdown\""
  shutdown_timeout = "30m"

  convert_to_template = true
}

build {
  sources = ["source.vsphere-iso.win2022"]

  provisioner "powershell" {
    inline = [
      "Write-Output \"Template build on $env:COMPUTERNAME\"",
      "Get-Service VMTools | Select-Object Status, StartType",
      "Clear-RecycleBin -Force -ErrorAction SilentlyContinue",
    ]
  }
}
