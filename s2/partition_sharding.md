# Секционирование, шардирование

## Создаем секции
```
-- 1. RANGE Partitioning (по датам) - для orders с датой заказа
-- Сначала добавим колонку даты в orders
ALTER TABLE bakery_db.orders ADD COLUMN order_date DATE DEFAULT CURRENT_DATE;

-- Создадим секционированную таблицу заказов по диапазонам дат
CREATE TABLE bakery_db.orders_range (
    order_id SERIAL,
    client_id INT NOT NULL,
    bakery_id INT NOT NULL,
    type_of_order VARCHAR(50),
    order_date DATE NOT NULL
) PARTITION BY RANGE (order_date);

-- Создаем секции по кварталам
CREATE TABLE orders_2024_q1 PARTITION OF bakery_db.orders_range
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF bakery_db.orders_range
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE orders_2024_q3 PARTITION OF bakery_db.orders_range
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE orders_2024_q4 PARTITION OF bakery_db.orders_range
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- 2. LIST Partitioning - для доставки по районам (на основе address)
CREATE TABLE bakery_db.delivery_list (
    delivery_id SERIAL,
    order_id INT NOT NULL,
    courier_id INT NOT NULL,
    address VARCHAR(150),
    district VARCHAR(50) -- добавим район для секционирования
) PARTITION BY LIST (district);

-- Создаем секции по районам
CREATE TABLE delivery_center PARTITION OF bakery_db.delivery_list
    FOR VALUES IN ('Центральный');

CREATE TABLE delivery_north PARTITION OF bakery_db.delivery_list
    FOR VALUES IN ('Северный');

CREATE TABLE delivery_south PARTITION OF bakery_db.delivery_list
    FOR VALUES IN ('Южный');

-- 3. HASH Partitioning - для равномерного распределения клиентов
CREATE TABLE bakery_db.clients_hash (
    client_id SERIAL,
    phone_number VARCHAR(11),
    last_name VARCHAR(80),
    first_name VARCHAR(80),
    middle_name VARCHAR(80),
    birth_date DATE
) PARTITION BY HASH (client_id);

-- Создаем 4 секции для равномерного распределения
CREATE TABLE clients_hash_p0 PARTITION OF bakery_db.clients_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE clients_hash_p1 PARTITION OF bakery_db.clients_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE clients_hash_p2 PARTITION OF bakery_db.clients_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE clients_hash_p3 PARTITION OF bakery_db.clients_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

```

### RANGE Секционирование

Запрос по дате (одна секция)
``` 
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bakery_db.orders_range
WHERE order_date BETWEEN '2024-05-01' AND '2024-05-31';
```

![Скриншот](img/73.png") - одна партиция, seq scan, без индекса
Проверка на наличие данных в секциях

```
SELECT 
    tableoid::regclass AS partition_name,
    COUNT(*) as rows_count,
    MIN(order_date) as min_date,
    MAX(order_date) as max_date
FROM bakery_db.orders_range
GROUP BY tableoid::regclass
ORDER BY partition_name;
```

![Скриншот]("img/74.png")

Запрос по диапазону (несколько секций)

```
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bakery_db.orders_range
WHERE order_date BETWEEN '2024-06-01' AND '2024-09-30';
```

![Скриншот]("img/75.png")
Запрос без ключа (все секции)
```
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bakery_db.orders_range
WHERE client_id = 1;
```

![Скриншот]("img/76 1.png")
![Скриншот]("img/76 2.png")

### LIST Секционирование

Смотрим распределение по районам
```SELECT 
    tableoid::regclass AS partition_name,
    district,
    COUNT(*) as cnt
FROM bakery_db.delivery_list
GROUP BY tableoid::regclass, district
ORDER BY partition_name;
```
![Скриншот]("img/77.png")
Запрос с IN

```
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bakery_db.delivery_list
WHERE district IN ('Центральный', 'Северный');
```
![Скриншот]("img/79.png")

### HASH Секционирование

```
-- Смотрим распределение по HASH секциям
SELECT 
    tableoid::regclass AS partition_name,
    COUNT(*) as cnt,
    MIN(client_id) as min_id,
    MAX(client_id) as max_id
FROM bakery_db.clients_hash
GROUP BY tableoid::regclass
ORDER BY partition_name;

-- Точный запрос по ID (одна секция)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM bakery_db.clients_hash
WHERE client_id = 15;
```

![Скриншот]("img/78.png")


### Секционирование на репликах 

```
# Подключаемся к мастеру
docker exec -it postgresql-01 psql -U postgres

-- Создаем базу для теста
CREATE DATABASE test_db;
\c test_db

-- Создаем секционированную таблицу
CREATE TABLE orders (
    id SERIAL,
    client_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount NUMERIC(10,2)
) PARTITION BY RANGE (order_date);

-- Создаем секции
CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE orders_2024_q3 PARTITION OF orders
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE orders_2024_q4 PARTITION OF orders
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- Вставляем данные
INSERT INTO orders (client_id, order_date, amount) VALUES 
    (1, '2024-02-15', 100.50),
    (2, '2024-05-20', 200.75),
    (3, '2024-08-10', 150.25),
    (4, '2024-11-05', 300.00);

-- Проверяем
SELECT tableoid::regclass AS partition, client_id, order_date, amount FROM orders;
```

![Скриншот]("img/92.png")
```
# Подключаемся к первой реплике
docker exec -it postgresql-02 psql -U postgres -d test_db

-- Проверяем структуру таблицы
\d orders

-- Проверяем данные
SELECT tableoid::regclass AS partition, client_id, order_date, amount FROM orders;
```
![Скриншот]("img/93.png")
![Скриншот]("img/94.png")

- Секционирование есть 

### Секционирование на логической реплике

```

-- Создали секционированную таблицу на мастере
CREATE TABLE orders ( 
    id SERIAL,
    client_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount NUMERIC(10,2)
) PARTITION BY RANGE (order_date);

-- Создали секции
CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Вставили данные
INSERT INTO orders (client_id, order_date, amount) VALUES 
    (1, '2024-02-15', 100.50),
    (2, '2024-05-20', 200.75);

    -- Публикация с publish_via_partition_root = off (по умолчанию)
CREATE PUBLICATION pub_orders_off FOR TABLE orders;

-- Публикация с publish_via_partition_root = on
CREATE PUBLICATION pub_orders_on FOR TABLE orders 
    WITH (publish_via_partition_root = on);
```

Структура на логической реплике
```
-- База postgres (такая же структура для pub_off)
CREATE TABLE orders (
    id SERIAL,
    client_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount NUMERIC(10,2)
) PARTITION BY RANGE (order_date);

CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Обычная таблица для pub_on
CREATE TABLE orders_flat (
    id INT,
    client_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount NUMERIC(10,2)
);
```
Подписки 
```
-- Подписка на pub_orders_off
CREATE SUBSCRIPTION sub_orders_off 
CONNECTION 'host=postgresql-01 port=5432 dbname=postgres user=postgres password=secretpass' 
PUBLICATION pub_orders_off;

-- Подписка на pub_orders_on
CREATE SUBSCRIPTION sub_orders_on 
CONNECTION 'host=postgresql-01 port=5432 dbname=postgres user=postgres password=secretpass' 
PUBLICATION pub_orders_on;
```

Вставка на мастере
```
#  На мастере вставляем данные
docker exec -it postgresql-01 psql -U postgres -d postgres
sql
INSERT INTO orders (client_id, order_date, amount) 
VALUES (4, '2024-06-15', 300.00);

INSERT INTO orders (client_id, order_date, amount) 
VALUES (5, '2024-06-20', 400.00);
```
 На подписчике проверяем
 ```
docker exec -it logical_replica psql -U postgres -d postgres
-- Проверяем в orders_flat (для pub_orders_on)
SELECT * FROM orders_flat;
 ```
![Скриншот]("img/96.png")
 ```
-- Сравниваем с orders (для pub_orders_off)
SELECT tableoid::regclass, * FROM orders;
```

![Скриншот]("img/94.png")

## Шардирование

### Создаем шарды на МАСТЕРЕ (postgresql-01)

```bash
# Подключаемся к мастеру (не к реплике!)
docker exec -it postgresql-01 psql -U postgres
```

```sql
-- Теперь создаем шарды
CREATE DATABASE shard1;
CREATE DATABASE shard2;

-- Проверяем
\l
```

### Создаем таблицы в шардах

```sql
-- Шард 1
\c shard1
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    amount NUMERIC(10,2)
);

INSERT INTO orders (client_id, amount) 
SELECT generate_series(1, 500), random() * 1000;

-- Проверяем
SELECT COUNT(*) FROM orders; -- 500 записей
```

```sql
-- Шард 2
\c shard2
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    amount NUMERIC(10,2)
);

INSERT INTO orders (client_id, amount) 
SELECT generate_series(501, 1000), random() * 1000;

-- Проверяем
SELECT COUNT(*) FROM orders; -- 500 записей
```

### Настраиваем FDW на роутере

```sql
-- Создаем базу роутера
CREATE DATABASE router;
\c router

-- Включаем FDW
CREATE EXTENSION postgres_fdw;

-- Подключаем шарды (они теперь на том же сервере)
CREATE SERVER shard1_server FOREIGN DATA WRAPPER postgres_fdw 
    OPTIONS (host 'localhost', port '5432', dbname 'shard1');

CREATE SERVER shard2_server FOREIGN DATA WRAPPER postgres_fdw 
    OPTIONS (host 'localhost', port '5432', dbname 'shard2');

-- Маппинг
CREATE USER MAPPING FOR postgres SERVER shard1_server OPTIONS (user 'postgres');
CREATE USER MAPPING FOR postgres SERVER shard2_server OPTIONS (user 'postgres');

-- Внешние таблицы
CREATE FOREIGN TABLE ft_shard1 (id INT, client_id INT, amount NUMERIC) 
    SERVER shard1_server OPTIONS (table_name 'orders');

CREATE FOREIGN TABLE ft_shard2 (id INT, client_id INT, amount NUMERIC) 
    SERVER shard2_server OPTIONS (table_name 'orders');
```

### Создаем представление

```sql
CREATE VIEW all_orders AS
    SELECT * FROM ft_shard1
    UNION ALL
    SELECT * FROM ft_shard2;
```

### Смотрим планы запросов

```sql
-- Запрос на все данные
EXPLAIN SELECT COUNT(*) FROM all_orders;
```
![Скриншот]("img/97.png")

```sql
-- Запрос на шард 1
EXPLAIN SELECT * FROM all_orders WHERE client_id = 100;
```
![Скриншот]("img/98.png")
```sql
-- Запрос на шард 2  
EXPLAIN SELECT * FROM all_orders WHERE client_id = 600;
```
![Скриншот]("img/99.png")