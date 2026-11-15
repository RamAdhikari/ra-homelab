# Clone two Windows Server 2022 VMs from tmpl-win2022 (job 11); vSphere customisation runs Sysprep, set the local
# Administrator password, and join them to the AD domain (vSphere guest customisation).
terraform {
  required_version = ">= 1.4.0"
  # State path is passed at init: -backend-config=path=/var/lib/homelab-tfstate/win-vms.tfstate
  backend "local" {}
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6" # 2.12.0 from the mirror in roles/hashicorp_tools
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  name          = var.esxi_host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  for_each = var.vms

  name             = each.key
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  host_system_id   = data.vsphere_host.host.id
  datastore_id     = data.vsphere_datastore.ds.id
  folder           = var.folder

  num_cpus = each.value.cpus
  memory   = each.value.memory_mb

  guest_id  = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type
  firmware  = data.vsphere_virtual_machine.template.firmware

  wait_for_guest_net_timeout = 15

  network_interface {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      timeout = 45 # Sysprep specialise + domain join + reboots, slow when nested

      windows_options {
        computer_name         = each.key
        admin_password        = var.win_admin_password
        join_domain           = var.domain_name
        domain_admin_user     = var.domain_join_user
        domain_admin_password = var.domain_join_password
        time_zone             = var.time_zone
        full_name             = "homelab"
        organization_name     = "homelab"
      }

      # DHCP address; AD DNS first so the domain join can find a DC.
      network_interface {
        dns_server_list = var.dns_servers
      }
    }
  }

  lifecycle {
    ignore_changes = [clone[0].template_uuid, clone[0].customize]
  }
}

output "vm_ips" {
  description = "VM name => first IPv4 address reported by VMware Tools"
  value       = { for k, v in vsphere_virtual_machine.vm : k => v.default_ip_address }
}
