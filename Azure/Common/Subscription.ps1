## COMMON AZURE PS Statements

#Set Default Subscription
Select-AzureRMsubscription -SubscriptionName "AZURE EA - DEVELOPMENT"

#Confirm Defaut Subscription
Get-AzureRMContext

#Get Azure Region Compute Options and Export to CSV
Get-AzureRmVMSize -Location "North Central US" | where-object {$_.Name -like "*_D*"} | Export-CSV C:\Temp\temp.csv

