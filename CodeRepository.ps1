#code Repository

#arrays,lists,other similar objects

#LOOPS

#foreach loop, mainly for working with objects
$Array = @('1','2','3','4','5')
ForEach($a in $Array){
    write-output $a
}

#for loop
[int32]$max = 5
For($num=1;$num -le $max;$num++)
{
    Write-output $num
}

#while loop
$num = 1
$max = 5
While($num -le $max){
    write-output $num
    $num++
}

#how to use very specific commandlets

#ForEach-Object -parallel
#concurrentbag, sends data back to the bag in no particular order, depending on when the code block finishes.
#Throttle limit specifies how many instances run at the same time. useful for controlling resources. or speeding up pings on computers
$ConcurrentBag = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new() 
$ComputerList = @('a','b','c','d')
$ComputerList | ForEach-Object -parallel{
    [int32]$max = 200
    $List = $Using:ConcurrentBag
    For($num=1;$num -le $max;$num++)
    {
        $List.add(($_ + $num))
    }
} -ThrottleLimit 5


#Copy and Paste Example
<#
.SYNOPSIS
    Brief Description
.DESCRIPTION
    Detailed Description
.EXAMPLE
    Example of Use
.PARAMETER Example1
    An example of a parameter description.
.PARAMETER Example2
    An example of a parameter description.
.OUTPUTS
    Objects/output of script
.NOTES
    Misc Notes
.LINK
    N/A
.COMPONENT
    N/A
.ROLE
    N/A
.FUNCTIONALITY
    N/A
#>
<# uncomment on use. cmdletbinding() makes variables behave like C# variables, might need to be deleted for use.
[cmdletbinding()]
Param (
    [Parameter(Mandatory=$True)][string]$Example1,
    [Parameter(Mandatory=$True)][string]$Example2
)

if ($Null -eq $Example1){
    $ComputerName = Read-Host 'Example1 input: '
}
if ($Null -eq $Example2){
    $EmployeeCode = Read-Host 'Example2 input: '
}

#>

#searching for employees who haven't logged in
Get-ADUser -Filter * -Properties LastLogon | Where-Object {([datetime]::FromFileTime($_.LastLogon)) -le (Get-Date -Year 2021 -Month 8 -Day 4)} | Select-Object Name,@{Name="lastLogon";Expression={[datetime]::FromFileTime($_.'LastLogon')}}