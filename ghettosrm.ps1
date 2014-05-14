###############################################
### VMWare DR Recovery Automation Script	###
### Version 1.0								###
###############################################

# Import DataONTAP modules
Import-Module DataONTAP
# Import VMWare modules
Add-PSSnapin "Vmware.VimAutomation.Core"

# Variables
#$Vcenter ="10.7.7.89"
$Vcenter = "10.7.127.137"
$Filer = "10.7.127.134"
#$Filer = "10.7.127.202"
$Cluster = "Exigen-DR"
$VMFolder = "RECOVERY"
$NAVol = "SP_LUNID*"
$Datastores = "VMFS*_PROD"

# Connect to vCenter and Netapp Filers
#Connect-ViServer -Server $Vcenter
#Connect-NaController $Filer -Credential root -HTTPS

$Vols = Get-NaVol -Name $NAVol

# Breaking Snapmirror Relationship for Production Volumes on DR Site
foreach ($vol in $Vols){
   Write-Host Breaking Mirror for $vol with NO confirmation
   Get-NaSnapmirror $vol | Invoke-NaSnapmirrorQuiesce | Invoke-NaSnapmirrorBreak -Confirm:$false
}

# Rescan All ESX Host HBAs
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs


# Add VMFS Datastores to Cluster
foreach($esx in (Get-VMHost -Location $Cluster)) {
$esxcli = Get-Esxcli -VMHost $esx
   foreach ($vmfs in $esxcli.storage.vmfs.snapshot.list()) {
      Write-Host Adding Datastore $vmfs.VolumeName on $esx
      $esxcli.storage.vmfs.snapshot.mount($false, $vmfs.VolumeName, $null)
   }
}

# Select ESX Host to register backups VMs in a specified folder
$ESXHost = Get-Cluster $Cluster | Get-VMHost | select -First 1


# Scanning Datastores for .vmx files
foreach ($datastore in Get-Datastore $Datastores ) {
   $ds = Get-Datastore -Name $datastore | %{Get-View $_.Id}
   $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
   $SearchSpec.matchpattern = "*.vmx"
   $dsBrowser = Get-View $ds.browser
   $DatastorePath = "[" + $ds.Summary.Name + "]"
   $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | where {$_.FolderPath -notmatch ".snapshot"} | %{$_.FolderPath + ($_.File | select Path).Path}
   Write-Host "$SearchResult"
   foreach ($VMXFile in $SearchResult) {
      New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $VMFolder -RunAsync
   }
}

Write-Host "Disconnecting from VCenter Server"
#Disconnect-ViServer -confirm:$False