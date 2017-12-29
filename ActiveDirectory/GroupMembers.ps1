
#Get list of AD Groups and Members that match the filter and Output to CSV

$file = Join-Path -path "C:\temp" -ChildPath "Groups.csv"

Get-ADGroup -filter "Groupcategory -eq 'Security' -AND GroupScope -ne 'domainlocal' -AND Member -like '*' -AND Name -like 'IT Ops*'" | 
foreach { 
 Write-Host "Exporting $($_.name)" -ForegroundColor Cyan
 $name = $_.name -replace " ","-"
 $file = Join-Path -path "C:\temp" -ChildPath "$name.csv"
 $output = Get-ADGroupMember -Identity $_.distinguishedname -Recursive |  
 Get-ADUser -Properties SamAccountname,Title,Department,EmailAddress |
 Select Name,SamAccountName,Title,Department,EmailAddress,DistinguishedName,ObjectClass
 $output | Export-Csv -Path $file -NoTypeInformation
 }
