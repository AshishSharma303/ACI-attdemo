# ACI secret management with Secure Environment Vairables





## Introduction

This document illustrates how to use  secrets with Azure Container Instances using secure environment variables functionality.These can be added while ACI creation to decouple application code from passwords and secrets. Application Code can utilize these secrets by referring to these values.The secrets can pre exist in Key vault and TF code/pipelines can fetch secret and use it to create ACI with ENV variables or secret mount. However, this document does not covers the creation of YAML pipelines and Azure Key Vault.


![test](/ACI-secretmgmt/env-variables/aci-env.PNG)

## Prerequisites
> 1. Use Azure cloud PowerShell or though local machine connected to the azure subscription to run below AZ cli commands.
> 2. Update the values for below variables as required 
```
rg="aci-rg01"
vnetname="aci-vnet01"
spname="spattakscls01"
subnet="aci-subnet01"
aciname="mytestaci01"
location="eastus2"

```

1. Create a Resource group
```
az group create --name $rg --location $location
```

2. Create a virtual network and multiple subnets which will host the AKS nodes, ACI nodes : 
```
az network vnet create -g $rg -n $vnetname --address-prefixes 10.10.4.0/22
az network vnet subnet create -g $rg --vnet-name $vnetname -n $subnet --address-prefix 10.10.4.0/24
```

Get the VNet and subnet ID into a variable for future use:
```
vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnet --query id --output tsv)

```
3. Create ACI instance with secure environment variables

```
az container create \
    --resource-group $rg \
    --name $aciname \
    --location $location \
    --subnet $subnetid \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --secure-environment-variables username=admin password=123qwe,./

```

4. Access secure env variables from container properties (values are not exposed here)

```
az container show --resource-group $rg --name $aciname --query 'containers[].environmentVariables'

```
5. Enter container bash shell
```
az container exec \
  --resource-group $rg \
  --name $aciname --exec-command "/bin/sh"
```

6. Validate the secrets
```
echo $username
echo $password

```
7. Clean-up the resources
```
az group delete -n $rg --yes

```


