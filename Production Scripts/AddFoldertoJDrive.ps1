<#
    .SYNOPSIS
    Creates a folder in a specified filepath and assigns it permissions.

    .DESCRIPTION
    Creates a folder in a specified filepath, creates a local and global group in AD, assigns users to the group and assigns the the local group permissions to the folder. 
    This was designed to run on a helpdesk account and will probably break when permissions for AD are redone.

    .PARAMETER FolderName
    (optional)specifies the folder name to be created, default value is test

    .PARAMETER FolderPath
    (optional)specifies where the folder will be located, default value is \\WindowsFileServer\FolderName

    .PARAMETER EmployeeArrayRO
    (optional)specifies the employee codes to be given read only permission to this folder. defaults to empty if no input is given, these arrays are not cleaned at all so any misspellings will throw an error.

    .PARAMETER EmployeeArrayF
    (optional)specifies the employee codes to be given full access permissions to this folder. defaults to empty if no input is given, these arrays are not cleaned at all so any misspellings will throw an error.
#>

param (
    [string]$FolderName = 'test',
    [string]$FolderPath = "\\WindowsFileServer\$FolderName",
    [array]$EmployeeArrayF = "",
    [array]$EmployeeArrayRO = "",
    [string]$ADDomain = "leetest"
)

<#
$EmployeeArrayF = @'
Lee Beckermeyer
'@ -split '\r?\n'

$EmployeeArrayRO = @'
MCC TestOnPrem
'@ -split '\r?\n'
#>

#defines names for the objects
$GroupNameF = "$FolderName.F"
$GroupNameFLocal = $GroupNameF + '.local'
$GroupNameRO = "$FolderName.RO"
$GroupNameROLocal = $GroupNameRO + '.local'

#defines objects for the loop
$FullAccessObject = [PSCustomObject]@{
    GroupName = $GroupNameF
    GroupNameLocal = $GroupNameFLocal
    EmployeeArray = $EmployeeArrayF
}

$ReadOnlyObject = [PSCustomObject]@{
    GroupName = $GroupNameRO
    GroupNameLocal = $GroupNameROLocal
    EmployeeArray = $EmployeeArrayRO
}

#puts custom objects into an array for parsing.
$GroupArray = @($ReadOnlyObject, $FullAccessObject)

#creates the folder
New-Item -ItemType Directory -Path $FolderPath

ForEach($Group in $GroupArray){

    #defines groups from each object
    $GroupName = $Group.GroupName
    $GroupNameLocal = $Group.GroupNameLocal
    $EmployeeArray = $Group.EmployeeArray

    #determines local group description
    If($GroupName -like '*RO'){
        $Descriptor = 'Read Only rights'
    }elseif($GroupName -like '*F'){
        $Descriptor = 'Filerights'
    }else{
        $Descriptor = 'Script Error, check the script'
    }
    $LocalGroupDescription = "{0} to {1}" -f $Descriptor,$FolderPath

    #add groups
    New-ADGroup -Name $GroupName -GroupCategory Security -GroupScope Global -Path 'OU=LNKEast,DC=danet,DC=local' -Description "Members of $GroupName"
    New-ADGroup -Name $GroupNameLocal -GroupCategory Security -GroupScope 0 -Path 'OU=LNKEast,DC=danet,DC=local' -Description $LocalGroupDescription
    Add-AdGroupMember $GroupNameLocal -Members $GroupName 

    #add users into group
    if($EmployeeArray -ne ''){
        foreach($Username in $EmployeeArray){
            try{
                $Username = $username.trim()
                $User = Get-ADUser -filter "CN -eq `'$Username`'"
                Add-ADGroupMember -Identity $GroupName -Members $User.SamAccountName -ErrorAction Stop
            }
            catch{
                write-host "there was an error adding $Username to $GroupName group."
            }
        }
    }

    #sleeps so the groups can populate to AD
    Start-Sleep 15

    #Add Groups to Folder
    $ACL = Get-ACL -Path $FolderPath

    #permissions for NTFS, pulled from C# [enum]::GetValues('System.Security.AccessControl.Inheritance')
    $GroupIdentity = "$ADDomain\$GroupNameLocal"
    $Inheritance = 'ContainerInherit, ObjectInherit'
    $Propogation = 'None'
    $AccessControlType = 'Allow'

    #assign permissions based on the group name, might need to be revisited if additional permissions are needed.
    if($GroupName -like '*F'){
        $NTFSPermissions = 'Read,ReadAndExecute,ListDirectory,Modify,Write'
    }
    else{
        $NTFSPermissions = 'Read,ReadAndExecute,ListDirectory'
    }

    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($GroupIdentity,$NTFSPermissions,$Inheritance,$Propogation,$AccessControlType)
    $ACL.AddAccessRule($accessRule)

    Set-ACL -Path $FolderPath -ACLObject $ACL
}