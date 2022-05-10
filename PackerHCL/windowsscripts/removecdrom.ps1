Param(
    $vcenter_server,
    $vcenter_username,
    $vcenter_password,
    $vcenter_datacenter,
    $vcenter_vmname
)

function Get-FolderByPath {
    <#
.SYNOPSIS Retrieve folders by giving a path
.DESCRIPTION The function will retrieve a folder by it's path.
The path can contain any type of leave (folder or datacenter).
.NOTES
Author: Luc Dekens .PARAMETER Path The path to the folder. This is a required parameter.
.PARAMETER
Path The path to the folder. This is a required parameter.
.PARAMETER
Separator The character that is used to separate the leaves in the path. The default is '/'
.EXAMPLE
PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
.EXAMPLE
PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
#>
    param(
        [CmdletBinding()]
        [parameter(Mandatory = $true)]
        [System.String[]]${Path},
        [char]${Separator} = '/'
    )
    process {
        if ((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple") {
            $vcs = $global:defaultVIServers
        }
        else {
            $vcs = $global:defaultVIServers[0]
        }
        $folders = @()
        foreach ($vc in $vcs) {
            $si = Get-View ServiceInstance -Server $vc
            $rootName = (Get-View -Id $si.Content.RootFolder -Property Name).Name
            foreach ($strPath in $Path) {
                $root = Get-Folder -Name $rootName -Server $vc -ErrorAction SilentlyContinue
                $strPath.Split($Separator) | % {
                    $root = Get-Inventory -Name $_ -Location $root -NoRecursion -Server $vc -ErrorAction SilentlyContinue
                    if ((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm") {
                        $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
                    }
                }
                $root | where { $_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl] } | % {
                    $folders += Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
                }
            }
        }
        $folders
    }
}

###############   Remove second CDROM   #################
Connect-VIServer -Server $vcenter_server -User $vcenter_username -Password $vcenter_password
$vm = Get-FolderByPath -Path "DCName/Templates" | Get-VM -Name "$vcenter_vmname"
Get-CDDrive -VM $vm | Where-Object { $_.name -eq "CD/DVD drive 2" } | Remove-CDDrive -Confirm:$false
###############   Upgrade VMTools   #################
$do = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec
$do.Tools = New-Object VMware.Vim.ToolsConfigInfo
$do.Tools.ToolsUpgradePolicy = "manual"
$vm.ExtensionData.ReconfigVM_Task($do)
###############   Convert VM to Template  #################
Set-VM -VM $vm -ToTemplate -Confirm:$false
Disconnect-VIServer -Confirm:$false