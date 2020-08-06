#!/usr/bin/env bash

# jn: prerequisite: setup_variables, create_resourcegroup, create_aks_vnet

# Add the Azure Firewall extension to Azure CLI in case you do not already have it.
az extension add --name azure-firewall
# Create Public IP for Azure Firewall
az network public-ip create -g $RG -n $FWPUBLICIP_NAME -l $LOC --sku "Standard"
# Create Azure Firewall
az network firewall create -g $RG -n $FWNAME -l $LOC
# Configure Azure Firewall IP Config - This command will take several mins so be patient.
az network firewall ip-config create -g $RG -f $FWNAME -n $FWIPCONFIG_NAME --public-ip-address $FWPUBLICIP_NAME --vnet-name $VNET_NAME
# Capture Azure Firewall IP Address for Later Use
FWPUBLIC_IP=$(az network public-ip show -g $RG -n $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show -g $RG -n $FWNAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
# Validate Azure Firewall IP Address Values - This is more for awareness so you can help connect the networking dots
echo $FWPUBLIC_IP
echo $FWPRIVATE_IP
# Create UDR & Routing Table for Azure Firewall
az network route-table create -g $RG --name $FWROUTE_TABLE_NAME
az network route-table route create -g $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP --subscription $SUBID

# Add Network FW Rules
# TCP - * - * - 9000
# TCP - * - * - 443
# If you want to lock down destination IP Addresses you will have to use the destination IP Addresses for the datacenter region you are deploying into, see note from above.
# For Example: East US DC Destination IP Addresses: 13.68.128.0/17,13.72.64.0/18,13.82.0.0/16,13.90.0.0/16,13.92.0.0/16,20.38.98.0/24,20.39.32.0/19,20.42.0.0/17,20.185.0.0/16,20.190.130.0/24,23.96.0.0/17,23.98.45.0/24,23.100.16.0/20,23.101.128.0/20,40.64.0.0/16,40.71.0.0/16,40.76.0.0/16,40.78.219.0/24,40.78.224.0/21,40.79.152.0/21,40.80.144.0/21,40.82.24.0/22,40.82.60.0/22,40.85.160.0/19,40.87.0.0/17,40.87.164.0/22,40.88.0.0/16,40.90.130.96/28,40.90.131.224/27,40.90.136.16/28,40.90.136.32/27,40.90.137.96/27,40.90.139.224/27,40.90.143.0/27,40.90.146.64/26,40.90.147.0/27,40.90.148.64/27,40.90.150.32/27,40.90.224.0/19,40.91.4.0/22,40.112.48.0/20,40.114.0.0/17,40.117.32.0/19,40.117.64.0/18,40.117.128.0/17,40.121.0.0/16,40.126.2.0/24,52.108.16.0/21,52.109.12.0/22,52.114.132.0/22,52.125.132.0/22,52.136.64.0/18,52.142.0.0/18,52.143.207.0/24,52.146.0.0/17,52.147.192.0/18,52.149.128.0/17,52.150.0.0/17,52.151.128.0/17,52.152.128.0/17,52.154.64.0/18,52.159.96.0/19,52.168.0.0/16,52.170.0.0/16,52.179.0.0/17,52.186.0.0/16,52.188.0.0/16,52.190.0.0/17,52.191.0.0/18,52.191.64.0/19,52.191.96.0/21,52.191.104.0/27,52.191.105.0/24,52.191.106.0/24,52.191.112.0/20,52.191.192.0/18,52.224.0.0/16,52.226.0.0/16,52.232.146.0/24,52.234.128.0/17,52.239.152.0/22,52.239.168.0/22,52.239.207.192/26,52.239.214.0/23,52.239.220.0/23,52.239.246.0/23,52.239.252.0/24,52.240.0.0/17,52.245.8.0/22,52.245.104.0/22,52.249.128.0/17,52.253.160.0/24,52.255.128.0/17,65.54.19.128/27,104.41.128.0/19,104.44.91.32/27,104.44.94.16/28,104.44.95.160/27,104.44.95.240/28,104.45.128.0/18,104.45.192.0/20,104.211.0.0/18,137.116.112.0/20,137.117.32.0/19,137.117.64.0/18,137.135.64.0/18,138.91.96.0/19,157.56.176.0/21,168.61.32.0/20,168.61.48.0/21,168.62.32.0/19,168.62.160.0/19,191.233.16.0/21,191.234.32.0/19,191.236.0.0/18,191.237.0.0/17,191.238.0.0/18
# Create the Outbound Network Rule from Worker Nodes to Control Plane
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr1' -n 'ssh' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 9000 443 --action allow --priority 100
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr2' -n 'dns' --protocols 'UDP' --source-addresses '*' --destination-addresses '*' --destination-ports 53 --action allow --priority 200
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr3' -n 'gitssh' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 22 --action allow --priority 300
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr4' -n 'fileshare' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 445 --action allow --priority 400

# Add Application FW Rules
# Required AKS FW Rules
# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#required-ports-and-addresses-for-aks-clusters

# Single F/W Rule
az network firewall application-rule create -g $RG -f $FWNAME \
 --collection-name 'AKS' \
 --action allow \
 --priority 100 \
 -n 'required' \
 --source-addresses '*' \
 --protocols 'http=80' 'https=443' \
 --target-fqdns 'aksrepos.azurecr.io' '*blob.core.windows.net' 'mcr.microsoft.com' '*cdn.mscr.io' 'management.azure.com' 'login.microsoftonline.com' 'ntp.ubuntu.com' 'packages.microsoft.com' 'acs-mirror.azureedge.net' '*.hcp.eastus.azmk8s.io' '*.tun.eastus.azmk8s.io' 'security.ubuntu.com' '*archive.ubuntu.com' 'changelogs.ubuntu.com' 'nvidia.github.io' 'us.download.nvidia.com' 'apt.dockerproject.org' 'dc.services.visualstudio.com' '*.ods.opinsights.azure.com' '*.oms.opinsights.azure.com'  '*.microsoftonline.com' '*.monitoring.azure.com' '*auth.docker.io' '*cloudflare.docker.io' '*cloudflare.docker.com' '*registry-1.docker.io' 'apt.dockerproject.org' 'gcr.io' 'storage.googleapis.com' '*.quay.io' 'quay.io' '*.cloudfront.net' '*.azurecr.io' '*.gk.azmk8s.io' 'raw.githubusercontent.com' 'gov-prod-policy-data.trafficmanager.net' 'api.snapcraft.io' '*.github.com' '*.vault.azure.net' '*.azds.io'

# Associate AKS Subnet to FW
az network vnet subnet update -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --route-table $FWROUTE_TABLE_NAME
# OR if you know the Subnet ID and would prefer to do it that way.
#az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --query id -o tsv
#SUBNETID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --query id -o tsv)
#az network vnet subnet update -g $RG --route-table $FWROUTE_TABLE_NAME --ids $SUBNETID
