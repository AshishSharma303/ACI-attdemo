# ACI-AKS-VirtualNode
Detailed procedure though AZ CLI commands to build the ACI virtual node integration with private AKS cluster. You can use Cloud PowerShell or Windows PowerShell to execute AZ CLI commands.
  - [Prerequisites](#prerequisites)
  - [Enable_Virtual_Nodes_with_AKS_cluster](#Enable_Virtual_Nodes_with_AKS_cluster)
  - [Clean_up_the_resources](#Clean_up_the_resources)

![image](/images/aciburst.png)


## Prerequisites
> 1. Use Azure portal cloud PowerShell or use local machine PowerSell connected to the azure subscription to run below AZ cli commands.
> 2. Account must have permissions to build a Service principal or already created SP can be used to build AKS cluster.
Defining the variables sets for the POC, these values can be changed however it may require minor PS1 code changes provided in the repo. 
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

Get the VNet and subnet ID into a variable for future use:
```
$vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
$subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetnode --query id --output tsv)
$subnetidaci=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetaci --query id --output tsv)
$subnetidagent=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetagent --query id --output tsv)

```

> If required, change the CIDR for VNet and subnets. 


3. Create a service principal account for Private AKS deployment
> Note: user must have permissions to build servie principal account on Azure AD.
```
$sppassword=$(az ad sp create-for-rbac --name $spname --role Contributor --scope $VNET_ID --query password --output tsv)
$httpspid="http://"+$spname
$spid=$(az ad sp show --id $httpspid --query appId --output tsv)
```
> Record the SP ID and SP Password for future usage.

4. Deploy the private AKS cluster

```
az extension add --name aks-preview
az extension update --name aks-preview
az role assignment create --assignee $spid --scope $vnetid --role Contributor

az aks create --resource-group $rg --name $akscluster --load-balancer-sku standard --enable-private-cluster --network-plugin azure --vnet-subnet-id $subnetid --docker-bridge-address 172.17.0.1/16 --dns-service-ip 11.2.0.10 --service-cidr 11.2.0.0/24 --service-principal $spid --client-secret $sppassword --kubernetes-version 1.17.7 --node-count 2 --node-osdisk-size 90 --location eastus2 --vm-set-type VirtualMachineScaleSets --enable-cluster-autoscaler --min-count 2 --max-count 5
```
> --node-vm-size switch can be used for the size of the nodes you want to use, which varies based on what you are using your cluster for and how much RAM/CPU each of your users need. By default, Standard_DS2_v2 is selected.

> Private AKS Private DNS and Private endpoint are created with Private AKS managed service.


5. Build a window virtual machine in the VNet as private AKS cluster cannot be accessed from outside of the virtual network. we will use the kube-subnet-agent01 subnet for this windows vm deployment. 
> Why windows VM?: with windows VM its an advantage of using it as admin server to manage th cluster and as client to access the web application hosted through the AKS PODS.   
``` 
az vm create --resource-group $rg --name $winvm --image Win2019Datacenter --admin-username $vmadmin --admin-password $vmpassword --size $winvmsku --subnet $subnetidagent --public-ip-address-dns-name "winvmakspublicip"
```
Prepare the windows VM with required toolsets such as az cli, kubectl etc.
```
az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi"

$idrsafilepath="https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa"
$idpubfilepath="https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa.pub"
$sshdir="c:\users\"+$vmadmin + "\.ssh"
$id_pubPath="c:\users\"+$vmadmin + "\.ssh" + "\id_rsa.pub"
$id_privPath="c:\users\"+$vmadmin + "\.ssh" + "\id_rsa"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "mkdir $sshdir"

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri $idrsafilepath -OutFile $id_privPath" 

az vm run-command invoke  --command-id RunPowerShellScript --name $winvm -g $rg --scripts "Invoke-WebRequest -Uri $idpubfilepath -OutFile $id_pubPath"

```
> Password is provided the VM in the AZ CLI command, if required please reset the password.
> If you wish to the change the user name then PS1 code requires a change for the certs copy to user profile. 

Below code can be used to build VM from exisiting images
> New-AzVm -ResourceGroupName "myResourceGroup" -Name "myVMfromImage" -ImageName "myImage" -Location "East US" -VirtualNetworkName "myImageVnet" -SubnetName "myImageSubnet" -SecurityGroupName "myImageNSG" -PublicIpAddressName "myImagePIP" -OpenPorts 3389
> az vm create --resource-group $sigResourceGroup --name aibImgVm001 --admin-username azureuser --location $location --image "/subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefName/versions/latest" --generate-ssh-keys



6. Log in the to the VM via RDP
We created a windows VM for the AKS cluster management, as private AKS cluster cannot be connected from outside the VNet scope. This VM has public IP connectivity as it is not connected to Bastion network. RDP to the VM will be on public endpoint.
Open windows PowerShell and execute the following Az Cli's for the cluster preparation and connectivity 

validate Az cli is installed on the VM:
```
az cli --version
```
> Note: if AZ cli is not installed then run the install command: Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

Azure login:
```
az login
```

Install kubectl and containers windows feature on windows server 2019 VM
```
az aks install-cli
$vmadmin="azureadmin"
$hostname=hostname
$kubectldir=";c:\users\"+$vmadmin + "." + $hostname + "\.azure-kubectl;"
[Environment]::SetEnvironmentVariable("Path", $env:Path + $kubectldir, "Machine")

Install-WindowsFeature -Name Containers
```
> Note: Restart the the server after installing the windows feature. 

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
$acrname="kubepubacr01"
$vnetid=$(az network vnet show --resource-group $rg --name $vnetname --query id --output tsv)
$subnetid=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetnode --query id --output tsv)
$subnetidaci=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetaci --query id --output tsv)
$subnetidagent=$(az network vnet subnet show --resource-group $rg --vnet-name $vnetname --name $subnetagent --query id --output tsv)

```

7. Connect to the private AKS cluster
get the creds of AKS cluster
```
az aks get-credentials --name $akscluster --resource-group $rg --output table
kubectl.exe get nodes
kubectl.exe get pods -A
```


## Enable_Virtual_Nodes_with_AKS_cluster
The virtual nodes are configured to use a separate virtual network subnet. ACI subnet must have the delegated permissions to connect Azure resources between the AKS cluster. All of the commands are executed from the windows RDP server we build above in the Virtual Network. 

1. Enable the addons procedure is provided below:
```
az provider register --namespace Microsoft.ContainerInstance
```
> The Microsoft.ContainerInstance provider should report as Registered

2. Enable virtual nodes, via using the az aks enable-addons command.
```
$httpspid="http://"+$spname
$spid=$(az ad sp show --id $httpspid --query appId --output tsv)
Optional: $sppassword=$(az ad sp credential reset --name $spid --query password -o tsv)
Optional: az network vnet subnet update --resource-group $rg --name $subnetaci --vnet-name $vnetname --delegations Microsoft.ContainerInstance/containerGroups

az container create --resource-group $rg --name initacicontainer101 --image mcr.microsoft.com/azuredocs/aci-helloworld --dns-name-label initacilable101 --ports 80
az container list --resource-group $rg --output table

az aks enable-addons --resource-group $rg --name $akscluster --addons virtual-node --subnet-name $subnetaci
```
> Note: Please record the password of the SP, as it cannot be found again.
> Known limitation with ACI virtual nodes: https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-portal#known-limitations

3. valiate if the virtual nodes are attached and visible
```
az aks get nodes
```

4. Deploy and configure ACR
Create ACR with public endpoint as Container Instance managed service does not integrated with private EP enabled ACR.
And Enable Admin user and password from portal on ACR, properties of the ACR resource, Access keys enable Admin User.
```
az acr create --resource-group $rg --name $acrname --sku Standard --location eastus2 --admin-enabled true --public-network-enabled true
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force -RequiredVersion 19.03
$dockerPath=";C:\Program Files\Docker;"
[Environment]::SetEnvironmentVariable("Path", $env:Path + $dockerPath, "Machine")
Start-Service docker | Set-Service -StartupType Automatic

$acrpassword=az acr credential show -n $acrname --query passwords[0].value --output table -o tsv
$acrusername=az acr credential show -n $acrname --query username --output table -o tsv
az acr login --name $acrname --username $acrusername --password $acrpassword
```

5. Test the ACR
An image is ready in MSFT Azure registry, the below code tests "pull and push" to the new newly created ACR. 
```
$msftusername="kubeacr01"
$msftpassword="f+tnktj6xjBun8YAlWn1SJowTp510CQT"
az acr login --name $msftusername --username $msftusername --password $msftpassword
az acr import --name $acrname --source kubeacr01.azurecr.io/23july2020:latest -u $msftusername -p $msftpassword
```

6. YAML executions with AKS-ACI virtual kubenet 
Build the namespace in AKS cluster, in this example namespace name is taken as "attdemo". Same name is used in the application deployment + service YAML's
```
kubectl create ns attdemo
```

create secret object for ACR, ACR is enabled with admin user name and password
```
$acrname=$acrname + ".azurecr.io"
kubectl create secret docker-registry acr-cred --docker-server=$acrname --docker-username=$acrusername --docker-password=$acrpassword --docker-email=admin@attdemo.azure.com -n attdemo
```

Deploy the application deployment and service YAML files, namespace is defined in YAML as attdemo (if required please change)

```
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/applicationCode/yamlAndDockerfile/aks-aci-attdemo.yaml" -OutFile aks-aci-attdemo.yaml
**Note:** Edit the yaml file and point it to your image repository. 
kubectl apply -f aks-aci-attdemo.yaml
Kubectl get pods -n attdemo
```

Burst test: change the deployment replica (for example 1 to 5) in the deployment YAML and verify the deployment and aks-burst with AKS
```
kubectl apply -f aks-aci-attdemo.yaml
Kubectl get pods -n attdemo
kubectl get svc -n attdemo
```
valdiate if the applicaiton is working though the LB service IP we just created though YAML.
https://IP address of the service:8000
Its an internal cert, web page will give cert error "we can ignore it" 

7. Optional step to build the Docker image on your own
```
#----Optional Code for the Docker Build-------#
If application team wants to build the docker file from scratch then, application code needs to be changed to point to the new PaaS service.
Below provided steps should be performed on Linux virtual machine, where Docker engine is installed.
Application code and DockerFile is provided under Git repo: https://github.com/AshishSharma303/ACI-attdemo/tree/master/ACI-AKS-VirtualNodes/applicationCode  
    - Build the Azure PaaS DB: A new PaaSDB of kind MYSQL "Sample AZ code is provided below:"
        A server name maps to a DNS name and must be globally unique in Azure. Substitute <server_admin_password> with your own server admin password.
        $rg="kube-rg01"
        $admin="myadmin"
        $maripassword="Password@123" 
        $mariadbname="myfirstmariadb"
        $mariadbserver=$mariadbname + ".mariadb.database.azure.com"
        $adminserver=$admin + "@" + "$mariadbname"

        az mariadb server create --resource-group $rg --name $mariadbname --location eastus2 --admin-user $admin --admin-password $maripassword --sku-name GP_Gen5_2 --version 10.2
        az mariadb server show --resource-group $rg --name $mariadbname

        Keep the firewall open for all public EP's as this only the POC pourpose, delete the DB once POC is done:
        ​az mariadb server update --resource-group $rg --name $mariadbname --ssl-enforcement Disabled
        az mariadb server firewall-rule create --resource-group $rg --server $mariadbname --name AllowMyIP --start-ip-address 192.168.0.1 --end-ip-address 192.168.0.1

        Connect to the server:
        $mariadbserver=$mariadbname + ".mariadb.database.azure.com"
        $admin=$admin + "@" + "$mariadbname"
        mysql -h $mariadbserver -u $adminserver -p

        View the server status at the mysql> prompt and build databases:
        mysql> status
        mysql> CREATE DATABASE sampledb;
        mysql> USE sampledb;
        mysql> CREATE TABLE inventory (id serial PRIMARY KEY, name VARCHAR(50), quantity INTEGER);
        INSERT INTO inventory (id, name, quantity) VALUES (1, 'banana', 150); 
        INSERT INTO inventory (id, name, quantity) VALUES (2, 'orange', 154);
        SELECT * FROM inventory;
    - Change the network settings of PaaSDB have to allow network settings & give access to VNET which is going to host the AKS and ACI instances. 
    - Unzip tar.gz file
    - Edit the application code file & edit the database connectivity so that application can connect to New PaasDB .
    - It would look like as below
    host: "<dbname>.<type>.database.azure.com", user: "{your_username}", password: {your_password}, database: {your_database}
    - Save the file.
    - Save the Dockerfile & use docker build . -t <Imagetag>
# ----Optional Code for the Docker Build END------#
```


## Clean_up_the_resources
```
az group delete -n $rg --yes
> get the name of MC RG from portal and delete the resource group built for AKS nodes.
```


