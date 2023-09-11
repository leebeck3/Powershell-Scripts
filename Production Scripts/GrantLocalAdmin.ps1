<#
.SYNOPSIS
    Adds local admin to a specified computer
.DESCRIPTION
    Adds a user to the local Administrator group on the computer.
.EXAMPLE
    .\GrantLocalAdmin.ps1 
.PARAMETER ComputerName
    Computer Name where you want to assign local admin.
.PARAMETER EmployeeCode
    Employee's code that you want assigned to the computer
.NOTES
    No input checking for employee code, only intended for help desk use.
#>

[cmdletbinding()]
Param (
    [Parameter(Mandatory=$True)][string]$ComputerName,
    [Parameter(Mandatory=$True)][string]$SAM
)

#clipboard array
$clipboard = "$SAM added to $ComputerName as a local admin"

#enters PS Session
Enter-PSSession -ComputerName $ComputerName -Credential (Get-Credential)

#Adds the employee to the local administrator group.
Add-LocalGroupMember 'Administrators' $SAM

#Exits the session
Exit-PSSession

#clipboard
Set-Clipboard $clipboard
write-output 'output copied to clipboard.'
Pause
