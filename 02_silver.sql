-- =========================================================
-- CAMADA SILVER - Limpeza, padronização e enriquecimento
-- =========================================================

-- Criação do schema Silver
CREATE SCHEMA IF NOT EXISTS workspace.silver;

-- Criação da tabela coffee_sales_clean a partir da Bronze:
-- - Deduplicação de registros
-- - Padronização dos nomes de produtos (ex: "Americano with milk" -> "Americano with Milk")
-- - Criação de dimensões temporais (hora, dia, mês, ano, período do dia, tipo de dia)
-- - Criação de indicadores de recorrência de clientes (segmento: VIP, Recorrente, Ocasional, Único)

CREATE OR REPLACE TABLE workspace.silver.coffee_sales_clean
AS
WITH dedup AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY datetime, coffee_name, money, cash_type
      ORDER BY datetime DESC
    ) AS rn
  FROM workspace.bronze.transactions_raw
),
base AS (
  SELECT
    `date`,
    datetime,
    INITCAP(TRIM(coffee_name))                          AS coffee_name,
    UPPER(TRIM(cash_type))                              AS cash_type,
    card,
    CAST(money AS DECIMAL(10,2))                        AS money,
    HOUR(datetime)                                      AS hora,
    DAY(datetime)                                       AS dia,
    MONTH(datetime)                                     AS mes,
    YEAR(datetime)                                      AS ano,
    DAYOFWEEK(datetime)                                 AS num_dia_semana,
    CASE DAYOFWEEK(datetime)
      WHEN 1 THEN 'Domingo'
      WHEN 2 THEN 'Segunda-feira'
      WHEN 3 THEN 'Terça-feira'
      WHEN 4 THEN 'Quarta-feira'
      WHEN 5 THEN 'Quinta-feira'
      WHEN 6 THEN 'Sexta-feira'
      WHEN 7 THEN 'Sábado'
    END                                                  AS nome_dia_semana,
    CASE MONTH(datetime)
      WHEN 1  THEN 'Janeiro'
      WHEN 2  THEN 'Fevereiro'
      WHEN 3  THEN 'Março'
      WHEN 4  THEN 'Abril'
      WHEN 5  THEN 'Maio'
      WHEN 6  THEN 'Junho'
      WHEN 7  THEN 'Julho'
      WHEN 8  THEN 'Agosto'
      WHEN 9  THEN 'Setembro'
      WHEN 10 THEN 'Outubro'
      WHEN 11 THEN 'Novembro'
      WHEN 12 THEN 'Dezembro'
    END                                                  AS nome_mes,
    DATE_FORMAT(datetime, 'yyyy-MM')                    AS ano_mes,
    CASE
      WHEN HOUR(datetime) BETWEEN 6 AND 11  THEN 'Manhã'
      WHEN HOUR(datetime) BETWEEN 12 AND 17 THEN 'Tarde'
      ELSE 'Noite'
    END                                                  AS periodo_dia,
    CASE
      WHEN DAYOFWEEK(datetime) IN (1, 7) THEN 'Fim de Semana'
      ELSE 'Útil'
    END                                                  AS tipo_dia
  FROM dedup
  WHERE rn = 1
    AND money IS NOT NULL
    AND money > 0
    AND coffee_name IS NOT NULL
),
cliente AS (
  SELECT
    card,
    COUNT(*)                           AS total_compras_cliente,
    COUNT(DISTINCT `date`)             AS dias_distintos_cliente,
    SUM(money)                         AS total_gasto_cliente,
    MIN(`date`)                        AS primeira_compra_cliente,
    MAX(`date`)                        AS ultima_compra_cliente,
    DATEDIFF(MAX(`date`), MIN(`date`)) AS dias_como_cliente
  FROM base
  WHERE card IS NOT NULL AND TRIM(card) != ''
  GROUP BY card
)
SELECT
  b.`date`,
  b.datetime,
  b.coffee_name,
  b.cash_type,
  b.card,
  b.money,
  b.hora,
  b.dia,
  b.mes,
  b.ano,
  b.num_dia_semana,
  b.nome_dia_semana,
  b.nome_mes,
  b.ano_mes,
  b.periodo_dia,
  b.tipo_dia,
  c.total_compras_cliente,
  c.dias_distintos_cliente,
  c.total_gasto_cliente,
  c.primeira_compra_cliente,
  c.ultima_compra_cliente,
  c.dias_como_cliente,
  CASE
    WHEN c.total_compras_cliente >= 50 THEN 'VIP'
    WHEN c.total_compras_cliente BETWEEN 10 AND 49 THEN 'Recorrente'
    WHEN c.total_compras_cliente BETWEEN 2 AND 9  THEN 'Ocasional'
    WHEN c.total_compras_cliente = 1              THEN 'Único'
    ELSE 'Sem Cartão'
  END AS segmento_cliente
FROM base b
LEFT JOIN cliente c ON b.card = c.card;

-- Schema final confirmado no Catalog Explorer (workspace.silver.coffee_sales_clean):
-- date, datetime, coffee_name, cash_type, card, money, hora, dia, mes, ano,
-- num_dia_semana, nome_dia_semana, nome_mes, ano_mes, periodo_dia, tipo_dia,
-- total_compras_cliente, dias_distintos_cliente, total_gasto_cliente,
-- primeira_compra_cliente, ultima_compra_cliente, dias_como_cliente, segmento_cliente

-- ---------------------------------------------------------
-- Validações após a criação da tabela Silver
-- ---------------------------------------------------------

-- Total de registros
SELECT COUNT(*) AS total FROM workspace.silver.coffee_sales_clean;

-- Verificar padronização dos produtos (não deve mais ter duplicatas)
SELECT coffee_name, COUNT(*) AS total
FROM workspace.silver.coffee_sales_clean
GROUP BY coffee_name
ORDER BY coffee_name;

-- Verificar dimensões de tempo criadas
SELECT datetime, hora, nome_dia_semana, periodo_dia, tipo_dia, ano_mes
FROM workspace.silver.coffee_sales_clean
LIMIT 10;

-- Verificar segmentação de clientes (VIP, Recorrente, Ocasional, Único)
SELECT segmento_cliente, COUNT(DISTINCT card) AS clientes, COUNT(*) AS compras
FROM workspace.silver.coffee_sales_clean
WHERE segmento_cliente != 'Sem Cartão'
GROUP BY segmento_cliente
ORDER BY compras DESC;

-- Estatísticas gerais da base tratada
SELECT
  COUNT(*)                              AS total_registros,
  MIN(`date`)                           AS data_inicio,
  MAX(`date`)                           AS data_fim,
  COUNT(DISTINCT `coffee_name`)         AS qtd_produtos,
  COUNT(DISTINCT `card`)                AS qtd_clientes,
  COUNT(DISTINCT `cash_type`)           AS qtd_formas_pagamento
FROM workspace.silver.coffee_sales_clean;

-- Checagem de valores mínimos/máximos (money e datas)
SELECT
  MIN(money) AS money_min,
  MAX(money) AS money_max,
  MIN(date)  AS data_min,
  MAX(date)  AS data_max
FROM workspace.silver.coffee_sales_clean;
