#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Passo 4: Deploy do container da API (.NET) no ACI. A connection string
# vem do Key Vault com um placeholder de host, que e' trocado pelo FQDN
# publico real do ACI do Oracle (ja criado no passo 03) via "sed" - mesma
# tecnica ensinada em aula. Nome do ACI com o RM como PREFIXO.
##############################################################################
set -euo pipefail

# ALTERE PARA O RM DO REPRESENTANTE DO GRUPO (igual aos scripts anteriores)
rm=rm562156

resourceGroup="rg-challengeapi"
location="mexicocentral"
acrName="clyvovetacr$rm"
imageApi="$rm-clyvovet-api"
tag="v1"
aciName="$rm-clyvovet-api"
dnsLabel="$rm-clyvovet-api"              # precisa ser unico globalmente
aciNameOracle="$rm-clyvovet-oracle"
keyVaultName="clyvovet-kv-$rm"

oracleFqdn=$(az container show --resource-group "$resourceGroup" --name "$aciNameOracle" --query ipAddress.fqdn --output tsv)

if [ -z "$oracleFqdn" ]; then
  echo "!! Nao encontrei o ACI do Oracle ($aciNameOracle). Rode antes o"
  echo "!! scripts/03_aci-oracle.sh."
  exit 1
fi

connectionString=$(az keyvault secret show --vault-name "$keyVaultName" --name oracle-connection-template --query value -o tsv \
  | sed "s/__ORACLE_HOST__/$oracleFqdn/")

echo "== CLYVO VET - Passo 4: Deploy ACI - API .NET =="
echo "Oracle FQDN usado na connection string: $oracleFqdn"

az container create \
  --resource-group "$resourceGroup" \
  --name "$aciName" \
  --location "$location" \
  --image "$acrName.azurecr.io/$imageApi:$tag" \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --dns-name-label "$dnsLabel" \
  --ports 8080 \
  --registry-login-server "$acrName.azurecr.io" \
  --registry-username "$(az keyvault secret show --vault-name "$keyVaultName" --name acr-username --query value -o tsv)" \
  --registry-password "$(az keyvault secret show --vault-name "$keyVaultName" --name acr-password --query value -o tsv)" \
  --environment-variables \
    ASPNETCORE_ENVIRONMENT=Production \
  --secure-environment-variables \
    ConnectionStrings__OracleConnection="$connectionString" \
  --restart-policy Always

apiFqdn=$(az container show --resource-group "$resourceGroup" --name "$aciName" --query ipAddress.fqdn --output tsv)

echo ""
echo "== RECURSOS PRONTOS =="
echo "API      : http://$apiFqdn:8080"
echo "Swagger  : http://$apiFqdn:8080/swagger"
echo "Health   : http://$apiFqdn:8080/health"
echo "Oracle   : $oracleFqdn:1521 (system / ver senha no Key Vault -> oracle-password)"
echo ""
echo "Teste rapido:"
echo "  curl http://$apiFqdn:8080/health"
echo ""
echo "Para o CRUD via SELECT direto no banco (evidencia do video):"
echo "  sqlplus system/\$(az keyvault secret show --vault-name $keyVaultName --name oracle-password --query value -o tsv)@//$oracleFqdn:1521/XEPDB1"
