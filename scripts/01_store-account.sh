#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Passo 1: Conta de Armazenamento + File Share, usada para persistir os
# dados do Oracle (/opt/oracle/oradata) fora do ciclo de vida do container -
# exatamente o padrao ensinado em aula (Aula 12 - Storage Account como
# volume do banco) e exigido no checkpoint ("Persistir os dados do banco
# em uma Conta de Armazenamento").
##############################################################################
set -euo pipefail

# ALTERE PARA O RM DO REPRESENTANTE DO GRUPO (igual ao 00_setup-acr.sh)
rm=rm562156

resourceGroup="rg-challengeapi"
location="mexicocentral"
storageAccountName="clyvovetdata$rm"     # so letras minusculas/numeros, unico globalmente
fileShareName="oracle-data-volume"

echo "== CLYVO VET - Passo 1: Storage Account + File Share =="

if ! az storage account show --name "$storageAccountName" --resource-group "$resourceGroup" &>/dev/null; then
  az storage account create \
    --resource-group "$resourceGroup" \
    --name "$storageAccountName" \
    --location "$location" \
    --sku Standard_LRS
else
  echo "Conta de armazenamento '$storageAccountName' ja existe."
fi

connectionString=$(az storage account show-connection-string \
  --name "$storageAccountName" \
  --resource-group "$resourceGroup" \
  --query connectionString --output tsv)

if ! az storage share exists --name "$fileShareName" --account-name "$storageAccountName" --connection-string "$connectionString" --query exists -o tsv | grep -qi true; then
  az storage share create \
    --name "$fileShareName" \
    --account-name "$storageAccountName" \
    --connection-string "$connectionString"
else
  echo "File share '$fileShareName' ja existe."
fi

echo ""
echo "== OK =="
echo "Storage Account: $storageAccountName"
echo "File Share     : $fileShareName"
echo ""
echo "Proximo passo: ./scripts/02_key-vault.sh"
