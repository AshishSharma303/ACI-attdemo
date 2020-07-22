# ACI-AKS-VirtualNode
Artefacts hosted in this repo are for the ACI integration with AKS.
---

## plan and deploy the Pre-reqs


### Create a servie principal account for Private AKS deploymnet
Use Azure cloud shell to run the below AZ cli commands:

$spname="spattakscluster01"
az ad sp create-for-rbac --name $spname --skip-assignment

### Create a virtual network and multiple subnets which will host the AKS nodes, ACI nodes : 
$vnetName="kube-vnet01"
$subneting="kube-subnet-ing01"
$subnetagent="kube-subnet-agent01"
$subnetnode="kube-subnet-node01"
$subnetaci="kube-subnet-aci01"

az network vnet create -g kube-rg01 -n kube-vnet01 --address-prefixes 10.0.4.0/22
az network vnet subnet create -g kube-rg01 --vnet-name kube-vnet01 -n kube-subnet-ing01  --address-prefix 10.0.4.0/24
az network vnet subnet create -g kube-rg01 --vnet-name kube-vnet01 -n kube-subnet-agent01 --address-prefix 10.0.5.0/24
az network vnet subnet create -g kube-rg01 --vnet-name kube-vnet01 -n kube-subnet-node01 --address-prefix 10.0.6.0/24

