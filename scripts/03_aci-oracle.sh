#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Passo 3: Deploy do container do BANCO (Oracle) no Azure Container
# Instances (ACI), com volume persistente na Conta de Armazenamento e
# credenciais lidas do Key Vault. Nome do ACI com o RM do representante do
# grupo como PREFIXO (regra do checkpoint).
##############################################################################
set -euo pipefail

# ALTERE PARA O RM DO REPRESENTANTE DO GRUPO (igual aos scripts anteriores)
rm=rm562156

resourceGroup="rg-challengeapi"
location="mexicocentral"
acrName="clyvovetacr$rm"
imageOracle="$rm-clyvovet-oracle"
tag="v1"
aciName="$rm-clyvovet-oracle"
dnsLabel="$rm-clyvovet-oracle"          # precisa ser unico globalmente
storageAccountName="clyvovetdata$rm"
fileShareName="oracle-data-volume"
keyVaultName="clyvovet-kv-$rm"

storageKey=$(az storage account keys list \
  --resource-group "$resourceGroup" \
  --account-name "$storageAccountName" \
  --query "[0].value" --output tsv)

echo "== CLYVO VET - Passo 3: Deploy ACI - Oracle =="

az container create \
  --resource-group "$resourceGroup" \
  --name "$aciName" \
  --location "$location" \
  --image "$acrName.azurecr.io/$imageOracle:$tag" \
  --cpu 2 \
  --memory 4 \
  --os-type Linux \
  --dns-name-label "$dnsLabel" \
  --ports 1521 \
  --registry-login-server "$acrName.azurecr.io" \
  --registry-username "$(az keyvault secret show --vault-name "$keyVaultName" --name acr-username --query value -o tsv)" \
  --registry-password "$(az keyvault secret show --vault-name "$keyVaultName" --name acr-password --query value -o tsv)" \
  --azure-file-volume-account-name "$storageAccountName" \
  --azure-file-volume-account-key "$storageKey" \
  --azure-file-volume-share-name "$fileShareName" \
  --azure-file-volume-mount-path /opt/oracle/oradata \
  --secure-environment-variables \
    ORACLE_PASSWORD="$(az keyvault secret show --vault-name "$keyVaultName" --name oracle-password --query value -o tsv)" \
  --restart-policy Always

fqdn=$(az container show --resource-group "$resourceGroup" --name "$aciName" --query ipAddress.fqdn --output tsv)

echo ""
echo "== OK =="
echo "ACI do Oracle: $aciName"
echo "FQDN         : $fqdn"
echo "Porta        : 1521"
echo ""
echo "O Oracle XE demora ~1-2 minutos para terminar de inicializar (e rodar o"
echo "script_bd.sql embutido na imagem, na primeira vez). Acompanhe com:"
echo "  az container logs --resource-group $resourceGroup --name $aciName --follow"
echo ""
echo "Proximo passo: ./scripts/04_aci-api-dotnet.sh"
