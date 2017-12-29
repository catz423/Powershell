#Author: Dan Catinella - 10/27/2017
#Name: Create New Azure Policy

#Policy to Require a Product Owner Tag on resources
$policy = New-AzureRmPolicyDefinition -Name "[Custom] Tag Policy - Product Owner Required" -Description "Policy to deny resource creation if no Product Owner tag is provided" -Policy '{
  "if": {
    "not" : {
      "field" : "tags",
      "containsKey" : "Product Owner"
    }
  },
  "then" : {
    "effect" : "deny"
  }
}'