# Name of the (managed) Node Resource Group to which the VNET is attached
MC_RESOURCE_GROUP=$(az aks show --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} --query "nodeResourceGroup" -o tsv)

# name of the VNET automatically created for the AKS cluster
MC_VNET=$(az network vnet list -g ${MC_RESOURCE_GROUP} --query "[0].name" -o tsv)

# ID of the subnet named 'aks-appgateway' automatically created for use by the ALB controller
export ALB_SUBNET_ID=$(az network vnet subnet show --resource-group ${MC_RESOURCE_GROUP} --vnet-name ${MC_VNET} --name aks-appgateway --query id -o tsv)
