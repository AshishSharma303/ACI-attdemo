# ACI secret management with Secret Mount





## Introduction

This document illustrates how to use secrets with Azure Container Instances using native ACI secret mount functionality. These can be added while ACI creation to decouple application code from passwords and secrets. Application Code can utilize these secrets by referring to these values.The secrets can pre exist in Key vault and TF code/pipelines can fetch secret and use it to create ACI with ENV variables or secret mount. However This document does not covers the creation of YAML pipelines and Azure Key Vault.


![test](/ACI-secretmgmt/secret-mount/aci_secret.PNG)

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

3. Get the VNet and subnet ID into a variable for future use:
```
vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnet --query id --output tsv)

```
4. Create ACI instance with secret mount

```
az container create \
    --resource-group $rg \
    --name $aciname \
    --location $location \
    --subnet $subnetid \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --secrets username="myadminuser" password="123qwe,./" \
    --secrets-mount-path /mnt/secrets

```

5. Enter container instance bash shell

```
az container exec \
  --resource-group $rg \
  --name $aciname --exec-command "/bin/sh"
```

6. Validate the secrets
```
ls /mnt/secrets
cat /mnt/secrets/username
cat /mnt/secrets/password

```
7. Clean-up the resources

```
az group delete -n $rg --yes

```

### NOTE
Azure Container Instance supports Managed Service Identity which can be used to access Key Vault from container run time and fetch the secrets. However, this option is not recommended due to below reasons:

1. Managed Service Identity is not supported with Azure Container Instances deployed inside virtual network.
2. Azure Container Instance is not a trusted service for Key Vault.Hence it requires Key Vault firewall to be enabled.

