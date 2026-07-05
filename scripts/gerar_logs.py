"""
Exercício 3.2 — Gera dados de exemplo para o Synapse Serverless.

Cria 3 CSVs (jan/fev/mar) com 1.000 registros cada de logs de compras.
Depois, faça upload ao Blob:
    az storage blob upload-batch -d logs -s .
"""
import csv
import random
import datetime

meses = {"jan": 1, "fev": 2, "mar": 3}
for nome, m in meses.items():
    with open(f"logs_compras_{nome}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["periodo", "valor"])
        for _ in range(1000):
            dia = random.randint(1, 28)
            data = datetime.date(2026, m, dia).isoformat()
            valor = round(random.uniform(20, 2000), 2)
            w.writerow([data, valor])
print("3 arquivos gerados. Upload com: az storage blob upload-batch -d logs -s .")