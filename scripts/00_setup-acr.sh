#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Passo 0: Resource Group + Azure Container Registry (ACR) + build/push das
# duas imagens (Banco e App) diretamente na nuvem com ACR Tasks. Este script
# foi preparado para o Azure Cloud Shell e nao exige Docker local.
# (Aula 12 - ACI/ACR) e a regra do Checkpoint: nome da imagem com o RM do
# representante do grupo como PREFIXO.
##############################################################################
set -euo pipefail

# ALTERE PARA O RM DO REPRESENTANTE DO GRUPO
rm=rm562156

resourceGroup="rg-challengeapi"
# CONTA ESTUDANTE (Azure for Students) costuma restringir as regioes
# liberadas por politica ("Allowed resource deployment regions"). Se o passo
# abaixo falhar com RequestDisallowedByPolicy, a mensagem de erro lista as
# regioes permitidas na sua assinatura - troque aqui e rode de novo.
location="mexicocentral"

acrName="clyvovetacr$rm"          # so letras/numeros, precisa ser unico globalmente
imageOracle="$rm-clyvovet-oracle"
imageApi="$rm-clyvovet-api"
tag="v1"

# Este script fica no repositorio DevOps, enquanto a API pode estar em outro
# repositorio/pasta. Informe API_DIR ao executar ou mantenha a API em uma pasta
# irma chamada ChallengeAPI ou ChallengeAPI-main.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
devopsDir="$(cd "$scriptDir/.." && pwd)"
apiDir="${API_DIR:-}"

if [[ -z "$apiDir" ]]; then
  for candidate in "$devopsDir/../ChallengeAPI" "$devopsDir/../ChallengeAPI-main"; do
    if [[ -f "$candidate/ChallengeAPI.csproj" ]]; then
      apiDir="$candidate"
      break
    fi
  done
fi

if [[ -z "$apiDir" || ! -d "$apiDir" ]]; then
  echo "!! Nao encontrei a pasta da API. Execute informando o caminho, por exemplo:"
  echo "!! API_DIR=../ChallengeAPI ./scripts/00_setup-acr.sh"
  exit 1
fi

apiDir="$(cd "$apiDir" && pwd)"

if [[ ! -f "$apiDir/ChallengeAPI.csproj" || ! -f "$apiDir/docker/Dockerfile" ]]; then
  echo "!! A pasta '$apiDir' nao contem ChallengeAPI.csproj e docker/Dockerfile."
  exit 1
fi

if [[ ! -f "$devopsDir/docker/Dockerfile.oracle" || ! -f "$devopsDir/scripts/script_bd.sql" ]]; then
  echo "!! O repositorio DevOps precisa conter docker/Dockerfile.oracle e scripts/script_bd.sql."
  exit 1
fi

echo "== CLYVO VET - Passo 0: Resource Group + ACR =="
echo "Repositorio DevOps: $devopsDir"
echo "Repositorio da API : $apiDir"

# Resource Group (idempotente) -------------------------------------------------
if ! az group show --name "$resourceGroup" &>/dev/null; then
  echo "Resource group '$resourceGroup' nao existe. Criando em '$location'..."
  if ! az group create --name "$resourceGroup" --location "$location"; then
    echo ""
    echo "!! Se o erro acima falar de 'RequestDisallowedByPolicy', copie uma"
    echo "!! das regioes permitidas listadas na mensagem, troque a variavel"
    echo "!! 'location' no topo deste script para ela e rode de novo."
    exit 1
  fi
else
  echo "Resource group '$resourceGroup' ja existe."
fi

# Registra os providers necessarios (obrigatorio em assinaturas novas) --------
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.ContainerInstance --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.KeyVault --wait

# ACR ---------------------------------------------------------------------------
if ! az acr show --name "$acrName" --resource-group "$resourceGroup" &>/dev/null; then
  az acr create \
    --resource-group "$resourceGroup" \
    --name "$acrName" \
    --sku Basic \
    --location "$location" \
    --admin-enabled true
else
  echo "ACR '$acrName' ja existe."
fi

loginServer=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
echo "ACR login server: $loginServer"

# ACR Tasks recebe cada contexto separadamente, executa o Dockerfile na Azure
# e publica a imagem automaticamente no registro.
echo "== Build na Azure: Oracle + schema/dados embutidos =="
(
  cd "$devopsDir"
  az acr build \
    --registry "$acrName" \
    --resource-group "$resourceGroup" \
    --image "$imageOracle:$tag" \
    --file docker/Dockerfile.oracle \
    .
)

echo "== Build na Azure: API ASP.NET Core =="
(
  cd "$apiDir"
  az acr build \
    --registry "$acrName" \
    --resource-group "$resourceGroup" \
    --image "$imageApi:$tag" \
    --file docker/Dockerfile \
    .
)

echo "== Imagens publicadas no ACR =="
az acr repository list --name "$acrName" --output table

echo ""
echo "== OK =="
echo "ACR: $acrName ($loginServer)"
echo "Imagem do banco: $loginServer/$imageOracle:$tag"
echo "Imagem da API  : $loginServer/$imageApi:$tag"
echo ""
echo "Proximo passo: ./scripts/01_store-account.sh"
