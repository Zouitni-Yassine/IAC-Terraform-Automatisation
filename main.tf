terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.102.0"
    }
  }
}
provider "proxmox" {
  endpoint = "https://192.168.56.101:8006/"
  username = "root@pam"
  password = "Yassine"
  insecure = true
}
resource "proxmox_virtual_environment_container" "debian_container" {
  description = "Managed by Terraform"

  node_name = "pve"

  unprivileged = true
  features {
    nesting = true
  }

  initialization {
    hostname = "debian-ct-01"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      password = "Yassine"
    }
  }

  network_interface {
    name = "veth0"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 5
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }
}
