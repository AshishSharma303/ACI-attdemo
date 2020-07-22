


$keyfilepath = "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa"
$certfilepath = "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa.pub"
$userFolderpath = [Environment]::GetFolderPath("UserProfile");
$sshPath = $userFolderpath + "\.ssh"
$rsapath = $sshPath + "\id_rsa" # RSA File path
$certpath= $sshPath + "\id_rsa.pub" # Cert File Path
$sshPath = $userFolderpath + "\.ssh"
$kubectlpath = $userFolderpath + "\.azure-kubectl"
$azclipath = $sshPath + "\AzureCLI.msi"

if($sshPath.exists -ne $true)
{
       Write-Host "Creating ssh folder to store keys.."
       $null = New-Item -Path $userFolderpath -Name ".ssh" -ItemType "directory"
}

if($kubectlpath.exists -ne $true)
{
       Write-Host "Creating kubectl folder.."
       $null = New-Item -Path $userFolderpath -Name ".azure-kubectl" -ItemType "directory"
}


## copy the certs file in the folder
Invoke-WebRequest -Uri $keyfilepath -OutFile $rsapath
Invoke-WebRequest -Uri $certfilepath -OutFile $certpath

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile $azclipath ; 
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; 
rm $azclipath 

$env:path += ";"+$kubectlpath+";"
az aks install-cli 







#Copy the certs
#Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa" -OutFile "c:\Users\ashis\.ssh\id_rsa"
#Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AshishSharma303/ACI-attdemo/master/ACI-AKS-VirtualNodes/Certs/id_rsa.pub" -OutFile "c:\Users\ashis\.ssh\id_rsa.pub"

# Azure CLI using PowerShell
# Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

# Install kubectl on widdows virtual machine 
#az aks install-cli


