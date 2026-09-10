#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Passo 2: Azure Key Vault - guarda TODAS as credenciais sensiveis (senha do
# Oracle, connection string, usuario/senha do ACR). Os scripts seguintes leem
# os valores daqui em vez de terem qualquer senha escrita em texto puro -
# exatamente o padrao ensinado em aula e a forma de evitar a penalidade de
# "dados sensiveis expostos no codigo fonte".
##############################################################################
set -euo pipefail

# ALTERE PARA O RM DO REPRESENTANTE DO GRUPO (igual aos scripts anteriores)
rm=rm562156

resourceGroup="rg-challengeapi"
location="mexicocentral"
acrName="clyvovetacr$rm"
keyVaultName="clyvovet-kv-$rm"

# A senha nunca fica gravada no repositorio. Se ORACLE_PASSWORD nao tiver sido
# fornecida pelo ambiente, o script solicita o valor sem exibi-lo no terminal.
if [[ -z "${ORACLE_PASSWORD:-}" ]]; then
  read -r -s -p "Digite uma senha forte para o Oracle: " ORACLE_PASSWORD
  echo
fi

if [[ ${#ORACLE_PASSWORD} -lt 8 ]]; then
  echo "A senha do Oracle deve possuir pelo menos 8 caracteres."
  exit 1
fi

ORACLE_CONNECTION_TEMPLATE="User Id=system;Password=${ORACLE_PASSWORD};Data Source=__ORACLE_HOST__:1521/XEPDB1"
# __ORACLE_HOST__ e substituido pelo FQDN publico do ACI do Oracle no passo 04,
# depois que o container do banco ja estiver criado (mesma tecnica do "sed"
# ensinada em aula para trocar o host da connection string em tempo de deploy).

echo "== CLYVO VET - Passo 2: Key Vault =="

if ! az keyvault show --name "$keyVaultName" --resource-group "$resourceGroup" &>/dev/null; then
  az keyvault create --name "$keyVaultName" --resource-group "$resourceGroup" --location "$location"
else
  echo "Key Vault '$keyVaultName' ja existe."
fi

# Garante que o usuario logado tem permissao para ler/escrever segredos
az role assignment create \
  --assignee "$(az account show --query user.name -o tsv)" \
  --role "Key Vault Administrator" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$keyVaultName" \
  || echo "(role assignment ja existia, seguindo em frente)"

echo "Aguardando propagacao da permissao no Key Vault..."
sleep 15

ACR_USERNAME=$(az acr credential show --name "$acrName" --resource-group "$resourceGroup" --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name "$acrName" --resource-group "$resourceGroup" --query "passwords[0].value" --output tsv)

az keyvault secret set --vault-name "$keyVaultName" --name oracle-password --value "$ORACLE_PASSWORD" >/dev/null
az keyvault secret set --vault-name "$keyVaultName" --name oracle-connection-template --value "$ORACLE_CONNECTION_TEMPLATE" >/dev/null
az keyvault secret set --vault-name "$keyVaultName" --name acr-username --value "$ACR_USERNAME" >/dev/null
az keyvault secret set --vault-name "$keyVaultName" --name acr-password --value "$ACR_PASSWORD" >/dev/null

echo ""
echo "== OK =="
echo "Key Vault: $keyVaultName (segredos: oracle-password, oracle-connection-template, acr-username, acr-password)"
echo ""
echo "Proximo passo: ./scripts/03_aci-oracle.sh"
