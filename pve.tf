terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

// 配置 provider
provider "proxmox" {
  pm_api_url          = "https://server99.ftnt.wiki:8006/api2/json"
  pm_api_token_id     = "terraform@pve!terraform"
  pm_api_token_secret = "77ad0943-9376-4035-a51f-41138d593d0a"
  pm_tls_insecure     = true
  pm_debug            = true
}

# data "template_file" "user_data" {
#   template = file("./user-data.tpl")

#   vars = {
#     hostname     = "ubuntu"
#     default_user = "ubuntu"
#     password     = "fortinet"
#   }
# }


resource "proxmox_vm_qemu" "ubuntu-host" {
  name        = "ubuntu-host-terrform"
  target_node = "Server99"

  clone = "ubuntu-server-20-template"

  cpu    = "1"
  memory = "2048"

  network {
    bridge = "vmbr85"
    model  = "virtio"
  }

  disk {
    size    = "30G"
    storage = "local-lvm"
    type    = "scsi"
  }

  os_type = "cloud-init"


  # cicustom = data.template_file.user_data.rendered

  # Cloud init options
  cicustom                = "user=snippets:snippets/user.yml,meta=snippets:snippets/meta.yml,network=snippets:snippets/meta.yml"
  cloudinit_cdrom_storage = "local-lvm"

  lifecycle {
    ignore_changes = [
      network
    ]
  }

}
