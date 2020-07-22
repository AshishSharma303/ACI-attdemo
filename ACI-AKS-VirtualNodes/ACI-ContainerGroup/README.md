# Container Group Deployment

- [Container Group Deployment](#container-group-deployment)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Deployment Steps](#deployment-steps)
    - [Configure the template](#configure-the-template)
    - [ARM Template Resource Group Deployment](#arm-template-resource-group-deployment)
  - [Testing](#testing)

## Introduction
This is a guide on how to deploy container group using ARM resource group deployment.

## Prerequisites

1. Modify the parameters in container_group_deploy.parameters.json file as per requirement

* containerGroupName : Container group name
* vnetName : Vitrual network name
* vnetAddressPrefix : VIrtual network address prefix
* subnetName : Container group subnet name
* subnetAddressPrefix : Container group subnet address prefix
* Location : Deployment location

2. Variables declared withing the template are

* networkProfileName : Network profile name for vnet injection of container group
* interfaceConfigName : Network profile network interface congif name
* interfaceIpConfig : Network profile network interface ip config name
  
> The container group has three containers - Proxy (nginx frontend), web(drupal middle tier) and a db(postgresql backend)


* container1name : Frontend container name
* container1image : Frontend container image
* container2name : Middle tier container name
* container2image : Middle tier container image
* container3name : Backend container name
* container3image : Backend container image

>The container images in the container_group_deploy.json file are publicly available.

3. A virtual machine needs to be created withing the vnet from where the container instances can be accessed.

## Deployment Steps
Since this is a ARM template resource group deployment, we need the resource group to be created before hand.

```
$rg_name = "rg name"
$location = "eastus2"
az group create -n $rg_name -l $location
```
### Configure the template
Create a new deployment file `container_group_deploy.json` in work working directory or in cloud shell and copy the code.
```

{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "containerGroupName": {
      "type": "string",
      "metadata": {
        "description": "Container Group name"
      }
    },
    "vnetName": {
      "type": "string",
      "metadata": {
        "description": "Virtual Network Name"
      }
    },
    "vnetAddressPrefix": {
      "type": "string",
      "metadata": {
        "description": "Virtual Network address prefix"
      }
    },
    "subnetName": {
      "type": "string",
      "metadata": {
        "description": "Subnet Name"
      }
    },
    "subnetAddressPrefix": {
      "type": "string",
      "metadata": {
        "description": "Subnet Address Prefix"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "EastUS2",
      "metadata": {
        "description": "Deployment Location"
      }
    }
  },
  "variables": {
    "networkProfileName": "cgroup-np",
    "interfaceConfigName": "cgroup-nic",
    "interfaceIpConfig": "cgroup-ipconfig",
    "container1name": "proxy",
    "container1image": "maanan/external:nginx",
    "container2name": "web",
    "container2image": "maanan/external:drupal_8",
    "container3name": "db",
    "container3image": "maanan/external:postgres_9"
  },
  "resources": [
    {
      "type": "Microsoft.Network/virtualNetworks",
      "name": "[parameters('vnetName')]",
      "apiVersion": "2018-07-01",
      "location": "[parameters('location')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "[parameters('vnetAddressPrefix')]"
          ]
        },
        "subnets": [
          {
            "name": "[parameters('subnetName')]",
            "properties": {
              "addressPrefix": "[parameters('subnetAddressPrefix')]",
              "delegations": [
                {
                  "name": "DelegationService",
                  "properties": {
                    "serviceName": "Microsoft.ContainerInstance/containerGroups"
                  }
                }
              ]
            }
          }
        ]
      }
    },
    {
      "name": "[variables('networkProfileName')]",
      "type": "Microsoft.Network/networkProfiles",
      "apiVersion": "2018-07-01",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[resourceId('Microsoft.Network/virtualNetworks', parameters('vnetName'))]"
      ],
      "properties": {
        "containerNetworkInterfaceConfigurations": [
          {
            "name": "[variables('interfaceConfigName')]",
            "properties": {
              "ipConfigurations": [
                {
                  "name": "[variables('interfaceIpConfig')]",
                  "properties": {
                    "subnet": {
                      "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('vnetName'), parameters('subnetName'))]"
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    },
    {
      "name": "[parameters('containerGroupName')]",
      "type": "Microsoft.ContainerInstance/containerGroups",
      "apiVersion": "2019-12-01",
      "location": "eastus2",
      "dependsOn": [
        "[resourceId('Microsoft.Network/networkProfiles', variables('networkProfileName'))]"
      ],
      "properties": {
        "containers": [
          {
            "name": "[variables('container2name')]",
            "properties": {
              "image": "[variables('container2image')]",
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGb": 1.5
                }
              }
            }
          },
          {
            "name": "[variables('container3name')]",
            "properties": {
              "image": "[variables('container3image')]",
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGb": 1.5
                }
              },
              "environmentVariables": [
                {
                  "name": "POSTGRES_PASSWORD",
                  "value": "P@ssw0rd@123"
                },
                {
                  "name": "POSTGRES_USER",
                  "value": "dbuser"
                },
                {
                  "name": "POSTGRES_DB",
                  "value": "postgresdb"
                }
              ]
            }
          },
          {
            "name": "[variables('container1name')]",
            "properties": {
              "image": "[variables('container1image')]",
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGb": 1.5
                }
              },
              "ports": [
                {
                  "port": 443
                }
              ]
            }
          }
        ],
        "networkProfile": {
          "id": "[resourceId('Microsoft.Network/networkProfiles', variables('networkProfileName'))]"
        },
        "osType": "Linux",
        "ipAddress": {
          "type": "Private",
          "ports": [
            {
              "protocol": "tcp",
              "port": 443
            }
          ]
        }
      }
    }
  ]
}
```

The code is deploying a virtual network, a subnet delegated to azure container instance, network profile for the container instance and the container group.

Copy the below code to `container_group_deploy.parameters.json` to define the parameter file

```
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "containerGroupName": { "value": "c-group" },
    "vnetName": { "value": "cgroup-vnet" },
    "vnetAddressPrefix": { "value": "10.10.0.0/16" },
    "subnetName": { "value": "cgroup-subnet" },
    "subnetAddressPrefix": { "value": "10.10.10.0/24" },
    "location": {"value": "eastus2" }
  }
}
```
Modify as needed.

### ARM Template Resource Group Deployment
The arm resource group deployment can be done in multiple ways
az cli can be used

```
az group deployment create -n containergroup -g $rg_name --template-file container_group_deploy.json --parameters container_group_deploy.parameters.json
```

az powershell can also be used to deploy the template

```
New-AzResourceGroupDeployment -Name containergroup -ResourceGroupName $rg_name -TemplateParameterFile container_group_deploy.parameters.json -TemplateFile container_group_deploy.json
```

## Testing

Once the resources are successfully deployed, from azure portal we can get the ip address of the container group and from a virtual machine withing the vnet of from a peered virtual machine we can access the container on port 443.
THe proxy server which is the entry point for the container group and exposed on port 443 has the below configuration and listens on host name demosite.aksinternal.com

```
server {
    listen 443 ssl;
    server_name demosite.aksinternal.com;
    ssl on;
    ssl_certificate         /etc/nginx/certs/crt.crt;
    ssl_certificate_key     /etc/nginx/certs/key.key;

    location / {
        proxy_pass http://localhost;
    }
```
From the proxy the traffic is passed on to the drupal container which is listening on port 80 through a proxy pass to `http://localhost`.
Drupal is a web management framework and in this demo we are using postgre as the backend database and drupal can connect to postgres through `localhost:5432`. Database name, database username and password are defined in the postgre container environmental variables.