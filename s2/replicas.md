
## Настройка потоковой репликации

Создаем сеть
docker network create pg-network

Запускаем мастер ( порт 54320)

docker run -d \
  --name postgresql-01 \
  --network pg-network \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=postgres \
  -p 54320:5432 \
  postgres:16 \
  -c 'wal_level=replica' \
  -c 'max_wal_senders=10' \
  -c 'max_replication_slots=10' \
  -c 'listen_addresses=*'

Запускаем реплику 1

docker run -d \
  --name postgresql-02 \
  --network pg-network \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=postgres \
  -p 54321:5432 \
  postgres:16

Запускаем реплику 2

docker run -d \
  --name postgresql-03 \
  --network pg-network \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=postgres \
  -p 54322:5432 \
  postgres:16

3 контейнера:
| Контейнер | Внутренний IP | Внешний порт |
|-----------|---------------|--------------|
| postgresql-01 | 172.x.x.2 | 54320 |
| postgresql-02 | 172.x.x.3 | 54321 |
| postgresql-03 | 172.x.x.4 | 54322 |

![Скриншот](img/61.png)
---
### Настройка physical streaming replication
docker exec -it postgresql-01 psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass';"


Настройка мастер
```bash
docker exec -it postgresql-01 bash

echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

tail -2 /var/lib/postgresql/data/pg_hba.conf

su - postgres
/usr/lib/postgresql/16/bin/pg_ctl reload -D /var/lib/postgresql/data

exit
exit

# Создаем слоты для обеих реплик
docker exec -it postgresql-01 psql -U postgres -c "SELECT pg_create_physical_replication_slot('replica1_slot');"
docker exec -it postgresql-01 psql -U postgres -c "SELECT pg_create_physical_replication_slot('replica2_slot');"

# Проверяем, что слоты созданы
docker exec -it postgresql-01 psql -U postgres -c "SELECT slot_name, active, restart_lsn FROM pg_replication_slots;"
```

Настройка реплики 1
```bash
docker exec -it postgresql-02 bash

rm -rf /var/lib/postgresql/data/*

/usr/lib/postgresql/16/bin/pg_basebackup -h postgresql-01 -D /var/lib/postgresql/data -U replicator -P -R

```
Настройка реплики 2
```bash
docker exec -it postgresql-03 bash

rm -rf /var/lib/postgresql/data/*

/usr/lib/postgresql/16/bin/pg_basebackup -h postgresql-01 -D /var/lib/postgresql/data -U replicator -P -R
```

![Скриншот](img/63.png)

### Проверка репликации данных 

docker exec -it postgresql-01 psql -U postgres -c "CREATE DATABASE testdb;"
docker exec -it postgresql-01 psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT);"
docker exec -it postgresql-01 psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');"

### Проверяем на реплике 1
docker exec -it postgresql-02 psql -U postgres -d testdb -c "SELECT * FROM users;"
 id |  name   
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
(3 rows)

### Проверяем на реплике 2
docker exec -it postgresql-03 psql -U postgres -d testdb -c "SELECT * FROM users;"

 id |  name   
----+---------
  1 | Alice
  2 | Bob
  3 | Charlie
(3 rows)

### Проверка вставки данных на реплику
docker exec -it postgresql-02 psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Emi');" 

> ERROR:  cannot execute INSERT in a read-only transaction


### Проверка lag

docker exec -it postgresql-01 psql -U postgres -c "CREATE DATABASE lag_test;"


while true; do
  docker exec -it postgresql-01 psql -U postgres -d lag_test -c "INSERT INTO test_data (data) VALUES (md5(random()::text));"
  sleep 0.1
done

![Скриншот](img/64.png")