# ACI secret management with Secret Mount


![test](/ACI-secretmgmt/secret-mount/aci_secret.PNG)





## Prerequisites
> 1. Use Azure cloud PowerShell or though local machine connected to the azure subscription to run below AZ cli commands.
> 2. Create a Key Vault and add two secrets  e.g. username and password
> 3. Define the variables inputs for the POC, these values can be changed however it may require minon PS code chanegs. 
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
3. Create ACI instance with secret mount

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

4. Enter container instance bash shell

```
az container exec \
  --resource-group $rg \
  --name $aciname --exec-command "/bin/sh"
```

5. Validate the secrets
```
ls /mnt/secrets
cat /mnt/secrets/username
cat /mnt/secrets/password

```
### Clean-up the resources
```
az group delete -n $rg --yes

```


