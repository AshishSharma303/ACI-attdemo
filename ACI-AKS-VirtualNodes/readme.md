# ACI-AKS-VirtualNode
Artefacts hosted in this repo are for the ACI integration with AKS.


## Prerequisites
> Use Azure cloud PowerShell or though local machine connected to the azure subscription to run below AZ cli commands.
Define the variables inputs for the POC, these values can be changed however it may require minon PS code chanegs. 
```
$rg="kube-aks-rg01"
$vnetname="kube-vnet01"
$spname="spattakscls01"
$subneting="kube-subnet-ing01"
$subnetagent="kube-subnet-agent01"
$subnetnode="kube-subnet-node01"
$subnetaci="kube-subnet-aci01"
$akscluster="kube-private-cls"
$winvm="kube-win-vm01"
$winvmsku="Standard_DS2_v2"
$vmadmin="azureadmin"
$vmpassword="Password@123"
```

1. Create a Resource group
```
az group create --name $rg --location eastus2
```

2. Create a virtual network and multiple subnets which will host the AKS nodes, ACI nodes : 
```
az network vnet create -g $RG -n $vnetName --address-prefixes 10.10.4.0/22
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subneting --address-prefix 10.10.4.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetagent --address-prefix 10.10.5.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetnode --address-prefix 10.10.6.0/24
az network vnet subnet create -g $RG --vnet-name $vnetname -n $subnetaci --address-prefix 10.10.7.64/26
```

Get the VNet and subnet ID into a varibale for future use:
```
$vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
$subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetnode --query id --output tsv)
$subnetidaci=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetaci --query id --output tsv)
$subnetidagent=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetagent --query id --output tsv)

```

> If required, change the CIDR for VNet and subnets. 


3. Create a servie principal account for Private AKS deploymnet
> Note: user must have permissions to build servie principal account on Azure AD.
```
$sppassword=$(az ad sp create-for-rbac --name $spname --role Contributor --scope $VNET_ID --query password --output tsv)
$httpspid="http://"+$spname
$spid=$(az ad sp show --id $httpspid --query appId --output tsv)

```

4. Deploy the private AKS cluster

```
$sshkey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMHllCBW7IyUNZmREKYZ+4hN0jQDvXddZaTMEty7NUyFyNhKuIbPzuxE6qFdn8Taf4KI0VRAe/4/7+P2GdZHDeNDQqYYq0iS+6jcMkRmvOik4+iLkJo/NE6Ek8oFCWfW7hkbdpZ14zr0we1A9aOGWAlDLGV52qDhbZPmJ0NDjldIzTnhWRSJJbGrIGBJNGfd3JbS3HrpqKmi6nGxnK++SYNlkRWiLbpSsU7oCcYlEz/S8m6f7etd8qxi9yL+zdbqCjw0bdCwK8pHcNoEDaQkvAxKCnHCJ7ls5GTMHwtK6g8OHX0tCcEx6wHOoKjBuDJsupBx1bONcl0xhS9Neu5mLF ashis@microsoft.com"
az extension add --name aks-preview
az extension update --name aks-preview
az aks create --resource-group $rg --name $akscluster --load-balancer-sku standard --enable-private-cluster --network-plugin azure --vnet-subnet-id $subnetid --docker-bridge-address 172.17.0.1/16 --dns-service-ip 11.2.0.10 --service-cidr 11.2.0.0/24 --service-principal $spid --client-secret $sppassword --kubernetes-version 1.17.7 --ssh-key-value $sshkey --node-count 2 --node-osdisk-size 90 --location eastus2 --vm-set-type VirtualMachineScaleSets --enable-cluster-autoscaler --min-count 2 --max-count 5
```
> --node-vm-size switch can be used for the size of the nodes you want to use, which varies based on what you are using your cluster for and how much RAM/CPU each of your users need. By default Standard_DS2_v2 is selected.

> Private AKS Private DNS and Private endpoint are created with Private AKS managed service.


5. Build a windows virtual manchine in the VNet as private AKS cluster can not be accessed from outside of the virtual network. we will use the kube-subnet-agent01 subnet for the this windows vm deployment. 
``` 
az vm create --resource-group $rg --name $winvm --image win2016datacenter --admin-username $vmadmin --admin-password $vmpassword --size $winvmsku --subnet $subnetidagent --public-ip-address-dns-name "winvmakspublicip"
```
Prepare the windows VM with required toolsets such as az cli, kubectl etc.
```
Set-AzVMCustomScriptExtension -ResourceGroupName $rg -VMName $winvm -Name "aksPrepToolsScript" -FileUri "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/winVmPrepScript/aksPrepToolsScript.ps1" -Run "aksPrepToolsScript.ps1" -Location "eastus2"

or

az vm extension set --resource-group $rg --vm-name $winvm --name "aksPrepToolsScript" --publisher Microsoft.Azure.Extensions --settings '{"fileUris": ["https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/winVmPrepScript/aksPrepToolsScript.ps1"],"commandToExecute": "./aksPrepToolsScript.ps1"}'

or

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi"

$idrsafilepath="https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa"
$idpubfilepath="https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa.pub"
$sshdir="c:\users\"+$vmadmin + "\.ssh"
$id_pubPath="c:\users\"+$vmadmin + "\.ssh" + "\id_rsa.pub"
$id_privPath="c:\users\"+$vmadmin + "\.ssh" + "\id_rsa"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "mkdir $sshdir"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri $idrsafilepath -OutFile $id_privPath" 

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri $idpubfilepath -OutFile $id_pubPath"

$kubectldir=";c:\users\"+$vmadmin + "\.azure-kubectl;"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "mkdir $kubectldir"
az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "[Environment]::SetEnvironmentVariable(\`"Path\`", $env:Path + \`"$($kubectldir)\`", \`"Machine\`")"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "az aks install-cli"

```
> Password is provided the VM in the AZ CLI command, if requried please reset the password.
> If you wishes to the change the user name then PS1 code requries a change for the certs copy to user profile. 

6. Log in the to the VM via RDP
We created a windows VM for the AKS cluster managemnet, as private AKS cluster can not be connected from outside the VNet scope. This Vm has publci IP connectivity as it is not connected to Bastion network. RDP to the VM will be on public endpoint.
Open windows PowerShell and execute the following Az Cli's for the cluster prepration and connectivity 

validate Az cli is installed on the VM:
```
az cli --version
```
> Note: if AZ cli is not installed then run the install command: Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

Azure login:
```
az login
```

Install kubectl on VM
```
az aks install-cli
$vmadmin="azureadmin"
$kubectldir=";c:\users\"+$vmadmin + "\.azure-kubectl;"
[Environment]::SetEnvironmentVariable("Path", $env:Path + $kubectldir, "Machine")
```
Restart the powershell to consume env variable 

Prepare the variable sets in the virtual machine
```
$rg="kube-aks-rg01"
$vnetname="kube-vnet01"
$spname="spattakscls01"
$subneting="kube-subnet-ing01"
$subnetagent="kube-subnet-agent01"
$subnetnode="kube-subnet-node01"
$subnetaci="kube-subnet-aci01"
$akscluster="kube-private-cls"
$winvm="kube-win-vm01"
$winvmsku="Standard_DS2_v2"
$vmadmin="azureadmin"
$vmpassword="Password@123"
$vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
$subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetnode --query id --output tsv)
$subnetidaci=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetaci --query id --output tsv)
$subnetidagent=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetagent --query id --output tsv)
```

7. Connect to the private AKS cluster
get the creds of AKS cluster
```
az aks get-credentials --name $akscluster --resource-group $rg --output table

```









