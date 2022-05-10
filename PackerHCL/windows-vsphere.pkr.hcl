packer {
  required_plugins {
    windows-update = {
      version = "0.14.0"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "vsphere_disk_size" {
  type    = string
  default = "81920"
}

variable "cdromscript" {
  type    = string
  default = ""
}

variable "template_name" {
  type    = string
  default = ""
}

variable "vsphere_server" {
  type    = string
  default = env("GOVC_HOST")
}

variable "vsphere_username" {
  type    = string
  default = env("GOVC_USERNAME")
}

variable "vsphere_password" {
  type      = string
  default   = env("GOVC_PASSWORD")
  sensitive = true
}

variable "vsphere_esxi_host" {
  type    = string
  default = env("VSPHERE_ESXI_HOST")
}

variable "vsphere_datacenter" {
  type    = string
  default = env("GOVC_DATACENTER")
}

variable "vsphere_cluster" {
  type    = string
  default = env("GOVC_CLUSTER")
}

variable "vsphere_datastore" {
  type    = string
  default = env("GOVC_DATASTORE")
}

variable "vsphere_folder" {
  type    = string
  default = env("VSPHERE_TEMPLATE_FOLDER")
}

variable "vsphere_network" {
  type    = string
  default = env("VSPHERE_VLAN")
}

variable "winrm_password" {
  type    = string
  default = env("WINRM_PASSWORD")
}

variable "os_iso_name" {
  type    = string
  default = env("os_iso_name")
}

variable "vmtools_iso_name" {
  type    = string
  default = env("vmtools_iso_name")
}

variable "vsphere_iso_datastore" {
  type    = string
  default = env("vsphere_iso_datastore")
}

source "vsphere-iso" "windows-template" {
  CPUs          = 4
  RAM           = 4096
  guest_os_type = "windows9Server64Guest"
  floppy_files = [
    "answerfile/autounattend.xml",
    "FloppyFiles/vmtools.ps1",
    "FloppyFiles/winrm.ps1",
    "FloppyFiles/fixnetwork.ps1",
  ]
  iso_paths = [
    "[${var.vsphere_iso_datastore}] ISO/${var.os_iso_name}",
    "[${var.vsphere_iso_datastore}] ISO/${var.vmtools_iso_name}",
  ]
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }
  disk_controller_type = ["lsilogic-sas"]
  storage {
    disk_size             = var.vsphere_disk_size
    disk_thin_provisioned = true
  }
  ip_wait_timeout = "45m"
  ip_settle_timeout = "120s"
  convert_to_template = false
  insecure_connection = true
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_username
  password            = var.vsphere_password
  host                = var.vsphere_esxi_host
  datacenter          = var.vsphere_datacenter
  cluster             = var.vsphere_cluster
  datastore           = var.vsphere_datastore
  folder              = var.vsphere_folder
  vm_name             = var.template_name
  shutdown_command    = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator        = "winrm"
  winrm_username      = "Alexander"
  winrm_password      = var.winrm_password
  ssh_timeout         = "4h"
  tools_upgrade_policy = "true"
}

build {
  sources = ["source.vsphere-iso.windows-template"]

  provisioner "powershell" {
    script = "windowsscripts/disable-windows-updates.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    scripts = ["windowsscripts/install_dotnet_framework48.ps1", "windowsscripts/disableipv6.ps1", "windowsscripts/disableadministratoraccount.ps1", "windowsscripts/enablerdp.ps1", "windowsscripts/disable_tls.ps1"]
  }

provisioner "windows-update" {
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true"
    ]
  }

   provisioner "powershell" {
    scripts = ["windowsscripts/bigcleanup.ps1", "windowsscripts/Undo-WinRMConfig.ps1", "windowsscripts/powershell_executionpolicy.ps1"]
  }

    post-processor "shell-local" {
    inline = ["pwsh windowsscripts/${var.cdromscript} -vcenter_datacenter ${var.vsphere_datacenter} -vcenter_server ${var.vsphere_server} -vcenter_username ${var.vsphere_username} -vcenter_password ${var.vsphere_password} -vcenter_vmname ${var.template_name}"]
  }
}