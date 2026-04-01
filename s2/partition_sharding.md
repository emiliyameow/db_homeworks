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