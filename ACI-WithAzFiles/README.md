# Azure Container Instance with Azure File Share Mount

- [Azure Container Instance with Azure File Share Mount](#azure-container-instance-with-azure-file-share-mount)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Deployment](#deployment)
  - [Testing](#testing)

## Introduction

This guide is for creating aci with az file share mount leveraging private link.

## Prerequisites

This demo can be performed from az cloud shell and doesn't require any prerequisites to be met.

## Deployment

login to azure

```
az login
```

Set the subscription context

```
az account set --subscription <sub_id>
```
Declare variables

```
#Change these four parameters as needed
$ACI_PERS_RESOURCE_GROUP="acirg" #aci resource group name 
$ACI_PERS_STORAGE_ACCOUNT_NAME=("strg" + (Get-Random)) #storage account name for file share creation
$ACI_PERS_LOCATION="eastus2" #deployment region
$ACI_PERS_SHARE_NAME="acishare" #file share name
$ACI_PERS_VNET_NAME="acivnet" #aci vnet name
$ACI_PERS_PE_NAME="storagepe" #storage private endpoint
```

Create a resource group

```
az group create -n $ACI_PERS_RESOURCE_GROUP -l $ACI_PERS_LOCATION --verbose
```

Create the vnet with private endpoint subnet

```
az network vnet create -n $ACI_PERS_VNET_NAME -g $ACI_PERS_RESOURCE_GROUP --address-prefixes 10.10.0.0/16 --location $ACI_PERS_LOCATION --subnet-name PE-Subnet --subnet-prefixes 10.10.240.0/24 --verbose
```

Update PE subnet with network policy

```
az network vnet subnet update -n PE-Subnet --vnet-name $ACI_PERS_VNET_NAME -g $ACI_PERS_RESOURCE_GROUP --disable-private-endpoint-network-policies --verbose
```

Create subnet for aci deployment

```
az network vnet subnet create --address-prefixes 10.10.10.0/24 --name aci-subnet --resource-group $ACI_PERS_RESOURCE_GROUP --vnet-name $ACI_PERS_VNET_NAME --verbose
```

Create the storage account for file share creation

```
az storage account create -g $ACI_PERS_RESOURCE_GROUP -n $ACI_PERS_STORAGE_ACCOUNT_NAME -l $ACI_PERS_LOCATION --sku Standard_LRS --verbose
```

Create the file share

```
az storage share create -n $ACI_PERS_SHARE_NAME --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --verbose
```

Get the storage account key and id

```
$STORAGE_KEY=$(az storage account keys list --resource-group $ACI_PERS_RESOURCE_GROUP --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)
$STORAGE_id=$(az storage account show -g $ACI_PERS_RESOURCE_GROUP -n $ACI_PERS_STORAGE_ACCOUNT_NAME --query id -o tsv)
```

Create PE for connecting to file sub resource

```
az network private-endpoint create --connection-name to-strg -g $ACI_PERS_RESOURCE_GROUP --private-connection-resource-id $STORAGE_id -n $ACI_PERS_PE_NAME --subnet PE-Subnet --vnet-name $ACI_PERS_VNET_NAME --group-ids file -l $ACI_PERS_LOCATION --verbose
```

Get the private endpoint ip address to be used in later stages for private dns host record creation

```
$ACI_PERS_PE_IP=$(az network private-endpoint show -n $ACI_PERS_PE_NAME -g $ACI_PERS_RESOURCE_GROUP --query customDnsConfigs[0].ipAddresses[0] -o tsv)
```

Create private dns zone for private link dns resolution for file storage

```
az network private-dns zone create -g $ACI_PERS_RESOURCE_GROUP -n privatelink.file.core.windows.net --verbose
```

Add A record for storage account fqdn pointing to private endpoint

```
az network private-dns record-set a add-record -g $ACI_PERS_RESOURCE_GROUP -z privatelink.file.core.windows.net -n $ACI_PERS_STORAGE_ACCOUNT_NAME -a $ACI_PERS_PE_IP --verbose
```

Link the private dns zone with aci vnet

```
az network private-dns link vnet create -g $ACI_PERS_RESOURCE_GROUP -n acivnetlink -z privatelink.file.core.windows.net -v $ACI_PERS_VNET_NAME -e false --verbose
```

Deploy the container

```
az container create -g $ACI_PERS_RESOURCE_GROUP -n hellofiles -l $ACI_PERS_LOCATION --image mcr.microsoft.com/azuredocs/aci-hellofiles --ports 80 --azure-file-volume-account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --azure-file-volume-account-key $STORAGE_KEY --azure-file-volume-share-name $ACI_PERS_SHARE_NAME --azure-file-volume-mount-path /aci/logs --subnet aci-subnet --vnet $ACI_PERS_VNET_NAME --ip-address Private --verbose
```

Create nsg and assign on aci vnet to restrict internet outbound traffic

```
az network nsg create --n internet-deny -g $ACI_PERS_RESOURCE_GROUP -l $ACI_PERS_LOCATION --verbose
az network nsg rule create -n deny-outbound-internet --nsg-name internet-deny --priority 1000 -g $ACI_PERS_RESOURCE_GROUP --access Deny --destination-address-prefixes Internet --destination-port-ranges '*' --direction Outbound --protocol '*' --source-address-prefixes * --source-port-ranges * --verbose
az network vnet subnet update --network-security-group internet-deny -n aci-subnet --vnet-name $ACI_PERS_VNET_NAME -g $ACI_PERS_RESOURCE_GROUP --verbose
```
## Testing
Once the container is deployed we can connect to the container from azure portal and run `nslookup` on the file storage fqdn. It should resolve to the private endpoint ip address. Create a file in `/aci/logs` directory where the file share is mounted and verify the creation of the file in azure storage account inside the file share.