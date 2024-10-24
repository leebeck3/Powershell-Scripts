#requires -version 7
<#
.SYNOPSIS
    Update a ESXi cluster automatically

.DESCRIPTION
    Gets host baselines that you are wanting to update the cluster to, Tests compliance to ensure that the baseline will function properly, checks hosts for free memory(limited at the time of creation) if VMs need to upgrade and migrates them.

.EXAMPLE
    .\Update-Cluster.ps1 -vCenterServer [String] -Cluster [String]

.NOTES
    Version:       1.1.1
    Author:        Lee Beckermeyer
    Creation Date: 3/27/2023
    Updated Date:  10/24/2024

.PARAMETER vCenterServer
    defines the vCenter server used.
.PARAMETER Cluster
    defines the cluster to remediate.
#>
#[cmdletbinding()]
Param (
    [Parameter(Mandatory=$True)][string]$vCenterServer,
    [Parameter(Mandatory=$True)][string]$Cluster
)

#Register PSGallery
if (Get-PSRepository -Name "PSGallery") {
    Write-Information "PSGallery already registered"
}else {
    Write-Information "Registering PSGallery"
    Register-PSRepository PSGallery
}

#check for modules
$Modules = @('VMware.PowerCLI')
ForEach($Module in $Modules){
    if (Get-Module -ListAvailable -Name $module){
        write-output "module $Module already exists"
    }else{
        Install-Module $Module -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop | Out-Null
        Import-Module $Module -Force -Scope local | Out-Null
    }
}

#main body of script
$vCenterServerCredential = Get-Credential -Message "Enter your vSphere credential"
Try{
    Connect-VIServer $vCenterServer -Credential $vCenterServerCredential
}catch{
    "Error connecting to the server, please relaunch the script"
}

#get the baselines to update to
$BaselineList = get-baseline *
$counter = 1
write-output "List of Baselines to check"
ForEach($Baseline in $BaselineList){
    Write-output "$counter. $($Baseline.Name)"
    $counter += 1
}
$Checker = Read-Host "Please enter the numbers of the baselines you would like to use(comma-delimited list): "
$Checker = $Checker -split ','
$UpdatedBaselineList = @()
ForEach($Number in $Checker){
    $Number = $Number - 1
    $UpdatedBaselineList += $BaselineList[$Number]
}

#Loop through each VM host, updating as needed.
$HostList = Get-Cluster $Cluster | Get-VMHost
ForEach($VMHost in $HostList){

    #Tests Compliance of the host
    Test-Compliance -Entity $VMHost 
    $Compliance = Get-Compliance -Entity $VMHost -Baseline $UpdatedBaselineList
    $ComplianceTest = $True
    ForEach($BaselineObject in $Compliance){
        if($($BaselineObject.Status) -ne 'Compliant'){
            $ComplianceTest = $False
        }
    }

    #puts host in maintenance mode and updates
    if($ComplianceTest -eq $False){
        $VMList = Get-VMHost $VMHost | Get-VM | Where-Object PowerState -eq 'PoweredOn'

        #migrates active VMs based on Free Memory on remaining hosts(assuming 2, rewrite if more in cluster) in cluster
        ForEach($VM in $VMList){
            $MigrationList = Get-Cluster $Cluster | Get-VMHost | Where-Object Name -ne $VMHost

            #checks every host in the migration list for memory
            $ResourceList = @()
            ForEach($MigrationHost in $MigrationList){
                $MemoryTotal = [Math]::Round($Migrationhost.MemoryTotalGB - $MigrationHost.MemoryUsageGB,2)
                $ResourceIndicator = [PSCustomObject]@{
                    Host = $MigrationHost
                    Memory = $MemoryTotal
                }
                $ResourceList += $ResourceIndicator
            }

            #checks hosts for the top free memory, 
            $MaxFree = $ResourceList.Memory | measure-object -Maximum
            $MaxFree = $MaxFree.Maximum
            $VMHostMigrate = ($ResourceList | Where-Object Memory -eq $MaxFree | select-object Host).Host

            $VMMemory = $VM.MemoryTotalGB

            if(($MaxFree - $VMMemory) -gt (0.8 * $MaxFree)){
                write-host "$($VMHostMigrate.Name) has enough free RAM to migrate $($VM.Name) proceed?"
                Pause
                Move-VM $VM -Destination $VMHostMigrate
                Start-Sleep -Seconds 20
            }else{
                write-host "This machine takes over 80% of the available RAM on the new host to perform a vMotion, please check the gui, the script will now abort."
                Pause
                exit
            }
        }

        #Sets maintenance mode
        write-output "Ready to put $($VMHost.Name) in maintenance mode"
        Pause
        Set-VMHost -VMHost $VMHost -State Maintenance
    
        #update the host
        Update-Entity -Baseline $UpdatedBaselineList -Entity $VMHost

        #remove maintenance mode
        write-output "Updated $($VMHost.Name). Ready to remove from maintenance mode"
        Pause
        Set-VMHost -VMHost $VMHost -State Connected
    }
}

#end of script