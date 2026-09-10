#!/bin/bash
##############################################################################
# CLYVO VET - ChallengeAPI
# Remove todos os recursos Azure criados por scripts/setup-azure.sh
# (Resource Group, ACR e Container Group sao removidos juntos, pois o
#  Resource Group e' o "guarda-chuva" de todos eles)
##############################################################################
set -euo pipefail

RESOURCE_GROUP="rg-challengeapi"

echo "== CLYVO VET - Remocao de recursos Azure =="
echo "Resource Group a remover: $RESOURCE_GROUP (ACR + Container Group inclusos)"
read -p "Tem certeza? (s/N): " CONFIRMA
if [[ "$CONFIRMA" != "s" && "$CONFIRMA" != "S" ]]; then
  echo "Cancelado."
  exit 0
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo "Remocao iniciada (assincrona). Tire um print do portal Azure mostrando"
echo "o Resource Group em estado 'Deleting' (ou ja removido) como evidencia."
