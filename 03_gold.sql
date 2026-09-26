-- =========================================================
-- CAMADA GOLD - Tabelas analíticas (schema estrela)
-- =========================================================

-- Criação do schema Gold
CREATE SCHEMA IF NOT EXISTS workspace.gold;

-- ---------------------------------------------------------
-- 1) faturamento_diario - 1 linha por dia
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.faturamento_diario
AS
SELECT
  `date`                    AS data,
  ano_mes,
  nome_mes,
  nome_dia_semana,
  tipo_dia,
  COUNT(*)                  AS total_vendas,
  ROUND(SUM(money), 2)      AS receita_total,
  ROUND(AVG(money), 2)      AS ticket_medio,
  ROUND(MAX(money), 2)      AS maior_venda,
  ROUND(MIN(money), 2)      AS menor_venda
FROM workspace.silver.coffee_sales_clean
GROUP BY `date`, ano_mes, nome_mes, nome_dia_semana, tipo_dia
ORDER BY `date`;

-- ---------------------------------------------------------
-- 2) vendas_por_produto - 1 linha por produto
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.vendas_por_produto
AS
SELECT
  coffee_name                                                 AS produto,
  COUNT(*)                                                    AS total_vendas,
  ROUND(SUM(money), 2)                                        AS receita_total,
  ROUND(AVG(money), 2)                                        AS preco_medio,
  ROUND(SUM(money) * 100.0 / SUM(SUM(money)) OVER (), 2)      AS pct_receita_total
FROM workspace.silver.coffee_sales_clean
GROUP BY coffee_name
ORDER BY receita_total DESC;

-- ---------------------------------------------------------
-- 3) ticket_medio - por mês + período + tipo de dia
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.ticket_medio
AS
SELECT
  ano_mes,
  nome_mes,
  ano,
  mes,
  periodo_dia,
  tipo_dia,
  COUNT(*)                            AS total_vendas,
  ROUND(AVG(money), 2)                AS ticket_medio,
  ROUND(MIN(money), 2)                AS ticket_minimo,
  ROUND(MAX(money), 2)                AS ticket_maximo,
  PERCENTILE(money, 0.5)              AS ticket_mediana
FROM workspace.silver.coffee_sales_clean
GROUP BY ano_mes, nome_mes, ano, mes, periodo_dia, tipo_dia
ORDER BY ano_mes;

-- ---------------------------------------------------------
-- 4) vendas_por_hora - 1 linha por hora
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.vendas_por_hora
AS
WITH vendas_hora AS (
  SELECT
    hora,
    periodo_dia,
    COUNT(*)                     AS total_vendas,
    ROUND(SUM(money), 2)         AS receita_total,
    ROUND(AVG(money), 2)         AS ticket_medio
  FROM workspace.silver.coffee_sales_clean
  GROUP BY hora, periodo_dia
),
produto_top_hora AS (
  SELECT
    hora,
    coffee_name,
    ROW_NUMBER() OVER (PARTITION BY hora ORDER BY COUNT(*) DESC) AS rank_produto
  FROM workspace.silver.coffee_sales_clean
  GROUP BY hora, coffee_name
)
SELECT
  v.hora,
  v.periodo_dia,
  v.total_vendas,
  v.receita_total,
  v.ticket_medio,
  p.coffee_name AS produto_mais_vendido
FROM vendas_hora v
LEFT JOIN produto_top_hora p
  ON v.hora = p.hora AND p.rank_produto = 1
ORDER BY v.hora;

-- ---------------------------------------------------------
-- 5) clientes_recorrentes - 1 linha por cartão
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.clientes_recorrentes
AS
WITH perfil_cliente AS (
  SELECT DISTINCT
    card                     AS cartao,
    segmento_cliente,
    total_compras_cliente    AS total_compras,
    dias_distintos_cliente   AS dias_com_compra,
    total_gasto_cliente      AS total_gasto,
    primeira_compra_cliente  AS primeira_compra,
    ultima_compra_cliente    AS ultima_compra,
    dias_como_cliente
  FROM workspace.silver.coffee_sales_clean
  WHERE card IS NOT NULL
    AND segmento_cliente != 'Sem Cartão'
),
produto_top_cliente AS (
  SELECT
    card,
    coffee_name,
    ROW_NUMBER() OVER (PARTITION BY card ORDER BY COUNT(*) DESC) AS rank_produto
  FROM workspace.silver.coffee_sales_clean
  WHERE card IS NOT NULL
  GROUP BY card, coffee_name
)
SELECT
  pc.cartao,
  pc.segmento_cliente,
  pc.total_compras,
  pc.dias_com_compra,
  pc.total_gasto,
  ROUND(pc.total_gasto / NULLIF(pc.total_compras, 0), 2)       AS ticket_medio_cliente,
  pc.primeira_compra,
  pc.ultima_compra,
  pc.dias_como_cliente,
  ROUND(pc.total_compras / NULLIF(CEIL(pc.dias_como_cliente / 30.0), 0), 1) AS compras_por_mes,
  pt.coffee_name                                               AS produto_favorito
FROM perfil_cliente pc
LEFT JOIN produto_top_cliente pt
  ON pc.cartao = pt.card AND pt.rank_produto = 1
ORDER BY total_compras DESC;

-- ---------------------------------------------------------
-- 6) receita_por_pagamento - por forma de pagamento + mês
-- ---------------------------------------------------------
CREATE OR REPLACE TABLE workspace.gold.receita_por_pagamento
AS
SELECT
  cash_type                                                   AS forma_pagamento,
  ano_mes,
  nome_mes,
  ano,
  mes,
  COUNT(*)                                                    AS total_vendas,
  ROUND(SUM(money), 2)                                        AS receita_total,
  ROUND(AVG(money), 2)                                        AS ticket_medio,
  ROUND(SUM(money) * 100.0 / SUM(SUM(money)) OVER (PARTITION BY ano_mes), 2) AS pct_receita_mes
FROM workspace.silver.coffee_sales_clean
GROUP BY cash_type, ano_mes, nome_mes, ano, mes
ORDER BY ano_mes, receita_total DESC;

-- ---------------------------------------------------------
-- Validação final: confirma criação e contagem das 6 tabelas Gold
-- ---------------------------------------------------------
SHOW TABLES IN workspace.gold;

SELECT 'faturamento_diario'     AS tabela, COUNT(*) AS registros FROM workspace.gold.faturamento_diario
UNION ALL
SELECT 'vendas_por_produto',               COUNT(*) FROM workspace.gold.vendas_por_produto
UNION ALL
SELECT 'ticket_medio',                     COUNT(*) FROM workspace.gold.ticket_medio
UNION ALL
SELECT 'clientes_recorrentes',             COUNT(*) FROM workspace.gold.clientes_recorrentes
UNION ALL
SELECT 'vendas_por_hora',                  COUNT(*) FROM workspace.gold.vendas_por_hora
UNION ALL
SELECT 'receita_por_pagamento',            COUNT(*) FROM workspace.gold.receita_por_pagamento
ORDER BY tabela;
