#!/usr/bin/env bash
# Runner do N3 (rodar no Azure Cloud Shell, a partir da RAIZ do repo).
# Provisiona Storage + AI Search (+ tenta Synapse) e roda o Ex. 3.1 (vector search).
#
#   git clone https://github.com/tiagobrilhante/qc-grupo-TenhoMedoDeGrupos-aula02.git
#   cd qc-grupo-TenhoMedoDeGrupos-aula02
#   LOCATION=eastus bash scripts/run_n3.sh
#
# LOCATION deve ser uma região liberada pela sua subscription. Descubra as suas com:
#   az policy assignment list -o json | grep -i -A2 location
set -uo pipefail
LOCATION="${LOCATION:-eastus}"

echo "==== N3 runner — Quantum Commerce (aula 02) | região: $LOCATION ===="

# ---- 1. Infraestrutura (Terraform) --------------------------------------
export TF_VAR_sql_admin_password="${TF_VAR_sql_admin_password:-Aa1!$(openssl rand -hex 8)}"
terraform -chdir=terraform init -input=false
# O apply pode falhar SÓ no Synapse se a subscription não permitir Azure SQL
# (SqlServerRegionDoesNotAllowProvisioning). Seguimos mesmo assim: Search+Storage bastam p/ o 3.1.
terraform -chdir=terraform apply -auto-approve -var="location=$LOCATION" \
  || echo "AVISO: apply parcial (Synapse pode ter falhado por política de região). Seguindo com Search+Storage."

STORAGE=$(terraform -chdir=terraform output -raw storage_account_name)
SEARCH=$(terraform -chdir=terraform output -raw search_endpoint)
export SEARCH_ENDPOINT="$SEARCH" STORAGE_ACCOUNT_NAME="$STORAGE"

# ---- 2. Dependências Python (Cloud Shell: torch CPU-only p/ não estourar o disco) ----
echo "→ Instalando dependências (torch CPU-only)..."
pip install --user --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
pip install --user --no-cache-dir --no-deps sentence-transformers
pip install --user --no-cache-dir transformers huggingface-hub tokenizers safetensors \
  scikit-learn scipy pillow tqdm azure-search-documents azure-storage-blob azure-identity

# ---- 3. Ex. 3.1 — Vector Search -----------------------------------------
echo "→ Subindo data/produtos.csv para o container catalogo..."
az storage blob upload -c catalogo -f data/produtos.csv -n produtos.csv \
  --account-name "$STORAGE" --auth-mode login --overwrite -o none

echo ""
echo "======= EX 3.1 — resultados do vector search ======="
python scripts/vector_search.py

# ---- 4. Ex. 3.2 — dados do Synapse (só se o Synapse subiu) ---------------
if terraform -chdir=terraform output -raw synapse_workspace_name >/dev/null 2>&1; then
  SYNAPSE=$(terraform -chdir=terraform output -raw synapse_workspace_name)
  echo "→ Gerando e subindo os CSVs de logs..."
  ( cd scripts && python gerar_logs.py )
  az storage blob upload-batch -d logs -s scripts --pattern 'logs_compras_*.csv' \
    --account-name "$STORAGE" --auth-mode login --overwrite -o none
  echo "[3.2] Abra o Synapse Studio ($SYNAPSE) e rode scripts/synapse_query.sql (troque STORAGE por $STORAGE)."
else
  echo "[3.2] Synapse não provisionado (subscription não permite Azure SQL) — etapa pulada."
fi

echo ""
echo "Quando terminar: terraform -chdir=terraform destroy -auto-approve -var=\"location=$LOCATION\""
