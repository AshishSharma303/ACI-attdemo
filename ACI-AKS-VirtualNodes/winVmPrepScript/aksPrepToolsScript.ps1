
#Copy the certs
Invoke-WebRequest -Uri "https://github.com/AshishSharma303/ACI-attdemo/blob/master/ACI-AKS-VirtualNodes/Certs/id_rsa" -OutFile "c:\Users\ashis\.ssh\id_rsa"
Invoke-WebRequest -Uri "https://github.com/AshishSharma303/ACI-attdemo/blob/master/ACI-AKS-VirtualNodes/Certs/id_rsa.pub" -OutFile "c:\Users\ashis\.ssh\id_rsa.pub"

# Azure CLI using PowerShell
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

# Install kubectl on widdows virtual machine 
az aks install-cli




