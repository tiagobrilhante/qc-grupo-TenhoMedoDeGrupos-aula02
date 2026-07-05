"""
Exercício 3.1 — Vector search verdadeira no Azure AI Search.

Gera embeddings dos produtos (nome + descrição) e indexa no AI Search com um
campo vector (HNSW). Depois roda 3 queries por similaridade vetorial.

Executado no Azure Cloud Shell.
Requer: pip install --user -r requirements.txt

Variáveis de ambiente:
  SEARCH_ENDPOINT        endpoint do Azure AI Search (https://<nome>.search.windows.net)
  STORAGE_ACCOUNT_NAME   nome da storage account com o container "catalogo/produtos.csv"
"""
import os
import csv

from sentence_transformers import SentenceTransformer
from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex, SimpleField, SearchableField, SearchField,
    SearchFieldDataType, VectorSearch, HnswAlgorithmConfiguration,
    VectorSearchProfile,
)
from azure.search.documents import SearchClient
from azure.storage.blob import BlobServiceClient

DIMENSION = 384  # all-MiniLM-L6-v2 produz vetores 384-dim
INDEX_NAME = "produtos-vector-index"


def main():
    endpoint = os.environ["SEARCH_ENDPOINT"]
    storage = os.environ["STORAGE_ACCOUNT_NAME"]
    credential = DefaultAzureCredential()

    print("→ Carregando modelo de embedding...")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    # Baixar produtos
    blob = BlobServiceClient(f"https://{storage}.blob.core.windows.net", credential=credential)
    csv_text = blob.get_blob_client("catalogo", "produtos.csv").download_blob().readall().decode("utf-8")
    rows = list(csv.DictReader(csv_text.splitlines()))

    # Gerar embeddings de "nome + descricao"
    print(f"→ Gerando embeddings de {len(rows)} produtos...")
    textos = [f"{r['nome']}. {r['descricao']}" for r in rows]
    embeddings = model.encode(textos).tolist()
    print(f"✓ Embeddings gerados (dim={len(embeddings[0])})")

    # Definir índice com campo vector
    index_client = SearchIndexClient(endpoint=endpoint, credential=credential)
    index = SearchIndex(
        name=INDEX_NAME,
        fields=[
            SimpleField(name="id", type=SearchFieldDataType.String, key=True),
            SearchableField(name="nome", type=SearchFieldDataType.String),
            SearchableField(name="descricao", type=SearchFieldDataType.String),
            SimpleField(name="categoria", type=SearchFieldDataType.String, filterable=True),
            SearchField(
                name="content_vector",
                type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                searchable=True,
                vector_search_dimensions=DIMENSION,
                vector_search_profile_name="produtos-hnsw-profile",
            ),
        ],
        vector_search=VectorSearch(
            algorithms=[HnswAlgorithmConfiguration(name="produtos-hnsw")],
            profiles=[VectorSearchProfile(name="produtos-hnsw-profile", algorithm_configuration_name="produtos-hnsw")],
        ),
    )
    try:
        index_client.delete_index(INDEX_NAME)
    except Exception:
        pass
    index_client.create_index(index)

    # Indexar
    search_client = SearchClient(endpoint=endpoint, index_name=INDEX_NAME, credential=credential)
    docs = [
        {
            "id": r["id"], "nome": r["nome"], "descricao": r["descricao"],
            "categoria": r["categoria"], "content_vector": embeddings[i],
        }
        for i, r in enumerate(rows)
    ]
    search_client.upload_documents(docs)
    print(f"✓ {len(docs)} produtos indexados com vetores")

    # Busca por vetor: gerar embedding da query e buscar nearest
    queries = [
        "preciso de uma cadeira boa para minha coluna",
        "algo para acompanhar séries",
        "presente para um amigo que ama café",
    ]
    for q in queries:
        q_vec = model.encode(q).tolist()
        print(f"\n=== Vector search: '{q}' ===")
        results = search_client.search(
            search_text=None,
            vector_queries=[{
                "kind": "vector",
                "vector": q_vec,
                "k_nearest_neighbors": 3,
                "fields": "content_vector",
            }],
        )
        for r in results:
            print(f"  [{r['@search.score']:.4f}] {r['nome']}")


if __name__ == "__main__":
    main()