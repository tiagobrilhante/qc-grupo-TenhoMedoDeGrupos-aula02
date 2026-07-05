-- Exercício 3.2 — Query no Synapse Serverless SQL Pool direto sobre o Blob (zero ETL).
-- Substitua STORAGE pelo nome da sua storage account antes de executar no Synapse Studio.

SELECT
    CAST(periodo AS DATE) AS dia,
    COUNT(*)              AS pedidos,
    SUM(valor)            AS receita
FROM OPENROWSET(
    BULK 'https://STORAGE.blob.core.windows.net/logs/compras_*.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) WITH (periodo VARCHAR(20), valor DECIMAL(10,2)) AS dados
GROUP BY CAST(periodo AS DATE)
ORDER BY dia;