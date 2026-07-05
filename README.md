# Como rodar o N3 — Grupo TenhoMedoDeGrupos (Aula 2)

Instruções para reproduzir os exercícios do **Nível 3** (Vector Search real + Synapse Serverless).
As respostas, análises e resultados estão no documento principal
**`entrega-grupo-TenhoMedoDeGrupos-aula02.md`**.

> Executado no **Azure Cloud Shell**. O `terraform/` daqui provisiona tudo que o N3 precisa
> (Storage + AI Search + Synapse). É um subconjunto do
> [lab da disciplina](https://github.com/elthonf/aie-cloud/tree/main/aulas/02-storage-bancos/lab)
> — o `synapse.tf` é a nossa adição (Ex. 3.2).

## Pré-requisitos

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) autenticada: `az login`
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Python 3.10+ (já disponível no Cloud Shell)
- Ser **Owner** (ou ter *User Access Administrator*) na subscription — o Terraform cria
  *role assignments* de acesso ao Blob e ao AI Search.

## 1. Infraestrutura (Terraform)

Provisiona: Resource Group, Storage Account (HNS habilitado) com containers `catalogo` e `logs`,
Azure AI Search (SKU free + semantic ranker), Synapse workspace + Data Lake Gen2 filesystem, e as
permissões RBAC necessárias.

```bash
cd terraform

# senha do admin SQL do Synapse (não fica em arquivo)
export TF_VAR_sql_admin_password="$(openssl rand -base64 24)"

terraform init
terraform plan
terraform apply

# guarde os endpoints em variáveis de ambiente (usados pelos scripts)
export STORAGE_ACCOUNT_NAME="$(terraform output -raw storage_account_name)"
export SEARCH_ENDPOINT="$(terraform output -raw search_endpoint)"
cd ..
```

> Ao terminar tudo, para não gerar custo: `cd terraform && terraform destroy`.

## 2. Vector Search no AI Search — Ex. 3.1

Sobe o catálogo para o Blob, gera embeddings dos produtos e indexa no AI Search com campo
vetorial (HNSW), depois roda 3 queries por similaridade.

```bash
# 1) subir o catálogo para o container "catalogo"
az storage blob upload -c catalogo -f data/produtos.csv -n produtos.csv \
  --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login

# 2) instalar deps — no Cloud Shell (disco de 5GB) instale o torch CPU-only primeiro,
#    senão o pip puxa ~3GB de pacotes CUDA e estoura o disco ([Errno 28] No space left):
pip install --user --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
pip install --user --no-cache-dir --no-deps sentence-transformers
pip install --user --no-cache-dir transformers huggingface-hub tokenizers safetensors \
  scikit-learn scipy pillow tqdm azure-search-documents azure-storage-blob azure-identity

# 3) rodar o vector search (baixa o modelo ~80MB no 1º uso)
cd scripts && python vector_search.py && cd ..
```

Saída: as 3 queries de exemplo com os Top-3 produtos por similaridade vetorial.

## 3. Analytics no Synapse Serverless — Ex. 3.2

```bash
cd scripts

# gera logs_compras_{jan,fev,mar}.csv (1.000 registros cada) e sobe ao container "logs"
python gerar_logs.py
az storage blob upload-batch -d logs -s . --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login
cd ..
```

Depois, no **Synapse Studio** (workspace `terraform output -raw synapse_workspace_name`) →
*Serverless SQL Pool*, execute **`scripts/synapse_query.sql`** (troque `STORAGE` pelo
`$STORAGE_ACCOUNT_NAME`). O total de bytes processados aparece na aba *Resultados*.

> **Ex. 3.3 (benchmark Cosmos × SQL × AI Search)** é uma comparação analítica — a tabela e a
> recomendação estão no documento principal, sem script associado.
