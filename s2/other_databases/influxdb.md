
Token: apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q
HTTP Requests Header: Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q

# InfluxDb
```
docker-compose up -d
```
## Вставить несколько записей
```
curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  --data-raw "temperature,location=room1 value=23.5"

curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  --data-raw "temperature,location=room2 value=21.8"

curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  --data-raw "temperature,location=room1 value=24.1"

curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  --data-raw "temperature,location=room2 value=22.3"


curl -X POST "http://localhost:8181/api/v3/query_sql" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  -H "Content-Type: application/json" \
  -d '{
    "db": "mydb",
    "q": "SELECT * FROM temperature WHERE time >= now() - interval '\''5 minutes'\'' ORDER BY time DESC"
  }'
```
![Скриншот](../img/134.png)

```
curl -X POST "http://localhost:8181/api/v3/query_sql" \
  -H "Authorization: Bearer apiv3_Be_pkeRQZkwB-ChhEbrlrRNzSigJMKqI1X9agJqDV84T79F4tpiitSWwXozSibG2OzVqDrIdjYkOacpwkKz47Q" \
  -H "Content-Type: application/json" \
  -d '{
    "db": "mydb",
    "q": "SELECT location, AVG(value) AS avg_temp, COUNT(*) AS readings FROM temperature WHERE time >= now() - interval '\''1 hour'\'' GROUP BY location ORDER BY avg_temp DESC"
  }'
```
![Скриншот](../img/135.png)