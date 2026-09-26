# ☕ Coffee Sales ETL Pipeline

Projeto de Engenharia de Dados desenvolvido no Databricks utilizando a arquitetura Medallion (Bronze, Silver e Gold) para transformar dados brutos de vendas de uma cafeteria em informações analíticas para apoio à tomada de decisão.

## 🚀 Objetivo

Analisar o comportamento de vendas, clientes e faturamento da cafeteria através da ingestão, tratamento e modelagem dos dados. As análises respondem perguntas como:

- Produtos mais vendidos e mais lucrativos
- Horários de maior movimento
- Ticket médio dos clientes
- Clientes recorrentes e VIP
- Formas de pagamento mais utilizadas 

## 🏗️ Arquitetura

- **Bronze:** ingestão e armazenamento dos dados brutos.
- **Silver:** limpeza, padronização e enriquecimento dos dados.
- **Gold:** criação de tabelas analíticas para consumo de negócio. 

## 📊 Fonte de Dados

Dataset **Coffee Sales** disponível no Kaggle:

https://www.kaggle.com/datasets/ihelon/coffee-sales 

## 🔧 Tecnologias

- Databricks
- SQL
- Unity Catalog
- Lakehouse Architecture 

## 📈 Principais Análises

- Faturamento diário
- Vendas por produto
- Ticket médio
- Clientes recorrentes
- Vendas por hora
- Receita por forma de pagamento 

## 💡 Insights Obtidos

- **Latte** é o produto com maior faturamento.
- O pico de vendas ocorre às **10h**.
- Clientes VIP e recorrentes representam pequena parte da base, mas geram grande parcela da receita.
- Pagamentos por cartão representam mais de 95% das vendas. 

## 👩‍💻 Autora

**Alexia Ferreira**  
MVP de Engenharia de Dados - PUC. 
