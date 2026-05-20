# OLAP модель

```
CREATE SCHEMA IF NOT EXISTS olap;


CREATE TABLE olap.dim_baking_good (
    baking_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    size NUMERIC(10,2),
    unit_name VARCHAR(20),  
    price INT NOT NULL
);

CREATE TABLE olap.dim_bakery (
    bakery_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(100) NOT NULL
);

CREATE TABLE olap.dim_client (
    client_id INT PRIMARY KEY,
    last_name VARCHAR(80),
    first_name VARCHAR(80),
    middle_name VARCHAR(80),
    phone_number VARCHAR(11)
);

CREATE TABLE olap.dim_order_type (
    order_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE
);

```
### Создаем таблицу Продажи

```
CREATE TABLE olap.fact_sales (
    sale_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,      
    baking_id INT NOT NULL,
    bakery_id INT NOT NULL,
    client_id INT NOT NULL,
    order_type_id INT NOT NULL,
    quantity NUMERIC(10,2) NOT NULL,
    unit_price INT NOT NULL,              -- цена за единицу на момент продажи
    revenue NUMERIC(15,2) GENERATED ALWAYS AS (quantity * unit_price) STORED, -- вычисляемая выручка
    FOREIGN KEY (baking_id) REFERENCES olap.dim_baking_good(baking_id),
    FOREIGN KEY (bakery_id) REFERENCES olap.dim_bakery(bakery_id),
    FOREIGN KEY (client_id) REFERENCES olap.dim_client(client_id),
    FOREIGN KEY (order_type_id) REFERENCES olap.dim_order_type(order_type_id)
);
```
### Создаем индексы для ускорения аналитических запросов
```
CREATE INDEX idx_fact_sales_baking ON olap.fact_sales(baking_id);
CREATE INDEX idx_fact_sales_bakery ON olap.fact_sales(bakery_id);
CREATE INDEX idx_fact_sales_client ON olap.fact_sales(client_id);
CREATE INDEX idx_fact_sales_order_type ON olap.fact_sales(order_type_id);
```

## Аналитические вопросы

1. Какие хлебобулочные изделия приносят наибольшую выручку и продаются в наибольшем количестве(популярность)
2. Кака  выручка генерируется каждой пекарней (эффективность)
3. Какой тип заказа (самовывоз или доставка) даёт больше выручки и заказов (анализ каналов продаж)


## Факт и измерения

### - Главный факт: fact_sales – продажи на уровне позиции заказа (каждая строка order_baking_goods)
- Зерно факта: одна строка = одна товарная позиция в одном заказе
  Атрибуты факта: quantity, price вычисляемая сумма (quantity * price)

- Измерения (размеры, по которым будет группировка и фильтрация):
  - dim_baking_good – товар (название, размер, рецепт, ключевое - название и цена)
  - dim_bakery – пекарня (название, адрес)
  - dim_client – клиент (имя, фамилия, телефон)
  - dim_order_type – тип заказа (самовывоз / доставка) – вырожденное измерение

## Заполнение OLAP-таблиц из OLTP

```sql
-- товары
INSERT INTO olap.dim_baking_good (baking_id, name, size, unit_name, price)
SELECT 
    b.baking_id,
    b.name,
    b.size,
    u.unit_name,
    b.price
FROM bakery_db.baking_goods b
JOIN bakery_db.units u ON b.unit_id = u.unit_id;

-- пекарни
INSERT INTO olap.dim_bakery (bakery_id, name, address)
SELECT bakery_id, name, address
FROM bakery_db.bakeries;

-- клиенты
INSERT INTO olap.dim_client (client_id, last_name, first_name, middle_name, phone_number)
SELECT client_id, last_name, first_name, middle_name, phone_number
FROM bakery_db.clients;

-- типы заказов
INSERT INTO olap.dim_order_type (type_name)
SELECT DISTINCT type_of_order FROM bakery_db.orders WHERE type_of_order IS NOT NULL;


-- fact_sales
INSERT INTO olap.fact_sales (order_id, baking_id, bakery_id, client_id, order_type_id, quantity, unit_price)
SELECT 
    obg.order_id,
    obg.baking_id,
    o.bakery_id,
    o.client_id,
    ot.order_type_id,
    obg.quantity,
    bg.price AS unit_price
FROM bakery_db.order_baking_goods obg
JOIN bakery_db.orders o ON obg.order_id = o.order_id
JOIN bakery_db.baking_goods bg ON obg.baking_id = bg.baking_id
JOIN olap.dim_order_type ot ON ot.type_name = o.type_of_order
ON CONFLICT DO NOTHING;
```

## Аналитические запросы 

### 1. Топ-5 товаров по выручке и по количеству проданных единиц

```sql
SELECT 
    bg.name AS товар,
    SUM(fs.revenue) AS выручка,
    SUM(fs.quantity) AS количество
FROM olap.fact_sales fs
JOIN olap.dim_baking_good bg ON fs.baking_id = bg.baking_id
GROUP BY bg.baking_id, bg.name
ORDER BY общая_выручка DESC
LIMIT 5;
```
![Скриншот](4.png)
### 2. Выручка по пекарням

```sql
SELECT 
    b.name AS пекарня,
    COUNT(DISTINCT fs.order_id) AS количество_заказов,
    SUM(fs.revenue) AS выручка,
    ROUND(AVG(fs.revenue), 2) AS среднее
FROM olap.fact_sales fs
JOIN olap.dim_bakery b ON fs.bakery_id = b.bakery_id
GROUP BY b.bakery_id, b.name
ORDER BY выручка DESC;
```
![Скриншот](5.png)

### 3. Сравнение выручки и числа заказов по типу (самовывоз и доставка)

```sql
SELECT 
    ot.type_name AS тип,
    COUNT(DISTINCT fs.order_id) AS количество,
    SUM(fs.revenue) AS выручка,
    ROUND(SUM(fs.revenue) / COUNT(DISTINCT fs.order_id), 2) AS средний_чек_на_заказ
FROM olap.fact_sales fs
JOIN olap.dim_order_type ot ON fs.order_type_id = ot.order_type_id
GROUP BY ot.type_name
ORDER BY выручка DESC;
```

![Скриншот](6.png)
