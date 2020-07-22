# ACI-AKS-VirtualNode
Artefacts hosted in this repo are for the ACI integration with AKS.
---

## plan and deploy the Pre-reqs


### Create a servie principal account for Private AKS deploymnet
Use Azure cloud shell to run the below AZ cli commands:
```
$spname="spattakscluster01"
az ad sp create-for-rbac --name $spname --skip-assignment
Record the appID and Password of the SP created:
$spappid=""
$sppass=""
```

### variables inputs for the POC
```
$rg="kube-rg01"
$vnetname="kube-vnet01"
$rg="kube-rg01"
$subneting="kube-subnet-ing01"
$subnetagent="kube-subnet-agent01"
$subnetnode="kube-subnet-node01"
$subnetaci="kube-subnet-aci01"
```

### Create a Resource group
az group create --name $rg --location eastus2


### Create a virtual network and multiple subnets which will host the AKS nodes, ACI nodes : 
az network vnet create -g $RG -n $vnetName --address-prefixes 10.0.4.0/22
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subneting  --address-prefix 10.0.4.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetagent --address-prefix 10.0.5.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetnode --address-prefix 10.0.6.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetaci --address-prefix 10.0.7.64/26





