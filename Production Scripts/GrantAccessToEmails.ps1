<#
    .Synopsis
    Gives an array of users access to an second array of user's mailboxes. runs very slowly because exchange powershell

    .DESCRIPTION
    Gives an array of users access to an second array of user's mailboxes. runs very slowly because exchange powershell

    .PARAMETER ExchangeAccount
    (optional) will default to lee.beckermeyer@duncanaviation.com, you can change this setting in the powershell so it defaults to someone else's email.
    takes format as your duncanaviation email.
    
    .PARAMETER AccessRights
    (optional) will set the access rights to the mailbox, default is FullAccess, you can specify multiple values by comma delimiting them, other valid values are ChangeOwner, ChangePermission, DeleteItem, ExternalAccount, ReadPermission

    .PARAMETER InheritanceType
    (optional) will set the inheritance type for the folders in the mailbox, default is all, other options are children, descendents, SelfandChildren
#>

param (
    [string]$ExchangeAccount = 'lee.beckermeyer@duncanaviation.com',
    [string]$AccessRights = 'fullaccess',
    [string]$InheritanceType = 'all'
)

#connects to exchange online, don't know if it will work with chrome or if it just pulls up 
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName $ExchangeAccount -CommandName Get-Mailbox,Add-MailboxPermission

#people who need access to mailboxes
$AccessorArray = @'
Lee Beckermeyer
'@ -split '\r?\n'

#mailboxes to give access to
$AccesseeArray = @'
Lee Beckermeyer
'@ -split '\r?\n'

ForEach($Accessor in $AccessorArray){

    #$UPN = (Get-ADUser -filter "Name -eq `'$Accessor`'").UserPrincipalName

    ForEach($Accessee in $AccesseeArray){
        Get-Mailbox -ResultSize unlimited -Filter "DisplayName -eq `'$Accessee`'" | Add-MailboxPermission -User $Accessor -AccessRights $AccessRights -InheritanceType $InheritanceType
    }

}

#disconnects from exchange online
Disconnect-ExchangeOnline -confirm:$false