-- =========================================================
-- CAMADA BRONZE - Ingestão dos dados brutos de vendas de café
-- =========================================================

-- Criação do schema Bronze
CREATE SCHEMA IF NOT EXISTS workspace.bronze;

-- Tabela criada via upload de arquivos (index_1.csv e index_2.csv)
-- unificados em uma única tabela com schema comum.
-- (index_2.csv não possui a coluna "card" -> preenchida com NULL)

CREATE TABLE workspace.bronze.transactions_raw (
  date        DATE,
  datetime    TIMESTAMP,
  cash_type   STRING,
  money       DOUBLE,
  coffee_name STRING,
  card        STRING
)
USING delta
COMMENT 'The table contains raw transaction data related to coffee purchases. It includes details such as the date and time of the transaction, type of cash used, the amount of money spent, the name of the coffee purchased, and the payment method (e.g., card). This data can be utilized for sales analysis, understanding purchasing trends, and evaluating different payment methods.';

-- Conferência dos dados brutos e possíveis problemas
SELECT
  cash_type,
  COUNT(*)                                                       AS total,
  COUNT(DISTINCT cash_type)                                      AS tipos_pagamento,
  SUM(CASE WHEN money <= 0 OR money IS NULL THEN 1 ELSE 0 END)   AS money_invalido,
  SUM(CASE WHEN coffee_name IS NULL THEN 1 ELSE 0 END)           AS coffee_nulo
FROM workspace.bronze.transactions_raw
GROUP BY cash_type;

-- 1. Verificação das datas (tipos e formatos)
SELECT
  date, datetime, cash_type, card, money, coffee_name
FROM workspace.bronze.transactions_raw
ORDER BY datetime
LIMIT 20;

-- 2. Identificação de produtos inconsistentes (duplicatas por capitalização)
-- Lista todos os produtos distintos com contagem, ordenado alfabeticamente
-- para identificar inconsistências lado a lado
SELECT
  coffee_name,
  COUNT(*) AS total
FROM workspace.bronze.transactions_raw
GROUP BY coffee_name
ORDER BY coffee_name;

-- 3. Clientes recorrentes - padrão do campo card
-- Agrupado por card calculando total de compras, dias distintos,
-- valor gasto e datas de primeira/última compra
SELECT
  card,
  COUNT(*)                          AS total_compras,
  COUNT(DISTINCT DATE(datetime))    AS dias_distintos,
  ROUND(SUM(money), 2)              AS total_gasto,
  MIN(DATE(datetime))               AS primeira_compra,
  MAX(DATE(datetime))               AS ultima_compra
FROM workspace.bronze.transactions_raw
WHERE card IS NOT NULL
  AND TRIM(card) != ''
GROUP BY card
ORDER BY total_compras DESC
LIMIT 20;
