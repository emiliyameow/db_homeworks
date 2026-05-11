# Qdrant
curl -X PUT "http://localhost:6333/collections/articles" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }' | jq

VEC=$(python3 -c "print([0.1]*384)" | tr -d ' \n')
curl -X PUT "http://localhost:6333/collections/articles/points?wait=true" \
  -H "Content-Type: application/json" \
  -d "{
    \"points\": [
      {
        \"id\": 1,
        \"vector\": $VEC,
        \"payload\": {
          \"title\": \"Искусство приготовления пасты\",
          \"content\": \"Рецепты домашней пасты, соусы и секреты итальянской кухни.\",
          \"author\": \"Marco Rossi\",
          \"category\": \"cooking\",
          \"published_at\": \"2024-03-10T10:00:00Z\",
          \"views\": 3200,
          \"rating\": 4.7
        }
      },
      {
        \"id\": 2,
        \"vector\": $VEC,
        \"payload\": {
          \"title\": \"Путешествие по Норвегии: фьорды и северное сияние\",
          \"content\": \"Маршруты, советы и лучшие места для наблюдения за aurora borealis.\",
          \"author\": \"Elena Berg\",
          \"category\": \"travel\",
          \"published_at\": \"2024-02-15T12:00:00Z\",
          \"views\": 4500,
          \"rating\": 4.3
        }
      },
      {
        \"id\": 3,
        \"vector\": $VEC,
        \"payload\": {
          \"title\": \"Основы Python для анализа данных\",
          \"content\": \"Pandas, NumPy, визуализация и практические примеры.\",
          \"author\": \"Alex Volkov\",
          \"category\": \"programming\",
          \"published_at\": \"2024-05-20T09:30:00Z\",
          \"views\": 2800,
          \"rating\": 4.8
        }
      },
      {
        \"id\": 4,
        \"vector\": $VEC,
        \"payload\": {
          \"title\": \"Genshin Impact\",
          \"content\": \"Все для начинающих.\",
          \"author\": \"Alex Vyaznikov\",
          \"category\": \"gaming\",
          \"published_at\": \"2024-05-20T09:30:00Z\",
          \"views\": 5000,
          \"rating\": 4.3
        }
      },
      {
        \"id\": 5,
        \"vector\": $VEC,
        \"payload\": {
          \"title\": \"Рецепты тортов\",
          \"content\": \"Шоколадная девочка, наполеон, медовик.\",
          \"author\": \"Emilia Zagitova\",
          \"category\": \"cooking\",
          \"published_at\": \"2024-05-20T09:30:00Z\",
          \"views\": 10000,
          \"rating\": 4.9
        }
      }
    ]
  }"
  ![Скриншот](../img/139.png)