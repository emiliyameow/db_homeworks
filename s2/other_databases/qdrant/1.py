import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

from qdrant_client import QdrantClient
from qdrant_client.http import models
from sentence_transformers import SentenceTransformer
from datetime import datetime

# Инициализация
client = QdrantClient("localhost", port=6333)
model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
collection_name = "articles"

# 1. Создание коллекции
client.recreate_collection(
    collection_name=collection_name,
    vectors_config=models.VectorParams(size=384, distance=models.Distance.COSINE),
)

# Данные для вставки
articles = [
    {"title": "Тренды AI 2026", "content": "Искусственный интеллект захватывает мир технологий.", "author": "Иванов", "category": "tech", "published_at": "2026-01-10T10:00:00Z", "views": 1500, "rating": 4.8},
    {"title": "Марафон в Париже", "content": "Бег и спорт помогают сохранять здоровье и бодрость.", "author": "Петров", "category": "sport", "published_at": "2025-05-20T08:00:00Z", "views": 800, "rating": 4.2},
    {"title": "Новости экономики", "content": "Мировые рынки показывают стабильный рост в этом квартале.", "author": "Сидоров", "category": "news", "published_at": "2024-12-01T12:00:00Z", "views": 3000, "rating": 3.5},
    {"title": "Гаджеты будущего", "content": "Новые смартфоны и носимые устройства в категории tech.", "author": "Смирнова", "category": "tech", "published_at": "2026-03-15T15:00:00Z", "views": 2500, "rating": 4.9},
    {"title": "Основы йоги", "content": "Спортивные упражнения и растяжка для начинающих.", "author": "Ли", "category": "sport", "published_at": "2023-10-10T09:00:00Z", "views": 1200, "rating": 3.9},
    {"title": "Квантовые компьютеры", "content": "Прорыв в области вычислений и высоких технологий.", "author": "Кюри", "category": "tech", "published_at": "2024-02-14T11:00:00Z", "views": 450, "rating": 3.2},
]

# Кодирование и вставка
points = []
for i, art in enumerate(articles):
    vector = model.encode(art['content']).tolist()
    points.append(models.PointStruct(id=i, vector=vector, payload=art))

client.upsert(collection_name=collection_name, points=points)
print("Коллекция создана, данные загружены.")

# А. Простой поиск (бег и спорт)
search_query = "бег и спорт"
query_vector = model.encode(search_query).tolist()

res_a = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    limit=3
)

# Б. Фильтр по категории (tech) и рейтингу (>= 4.0)
res_b = client.search(
    collection_name=collection_name,
    query_vector=query_vector, # Вектор все равно нужен для поиска
    query_filter=models.Filter(
        must=[
            models.FieldCondition(key="category", match=models.MatchValue(value="tech")),
            models.FieldCondition(key="rating", range=models.Range(gte=4.0))
        ]
    ),
    limit=3
)

# В. Диапазон дат (> 2024-01-01) и просмотры (> 1000)
res_c = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    query_filter=models.Filter(
        must=[
            models.FieldCondition(key="published_at", range=models.Range(gt="2024-01-01T00:00:00Z")),
            models.FieldCondition(key="views", range=models.Range(gt=1000))
        ]
    ),
    limit=3
)

# Г. Сложный фильтр (OR, Range, Score)
res_d = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    query_filter=models.Filter(
        must=[
            models.Filter(
                should=[
                    models.FieldCondition(key="category", match=models.MatchValue(value="sport")),
                    models.FieldCondition(key="category", match=models.MatchValue(value="tech")),
                ]
            ),
            models.FieldCondition(key="rating", range=models.Range(gte=3.5)),
            models.FieldCondition(key="views", range=models.Range(gte=500, lte=5000)),
        ]
    ),
    limit=5
)

# А. Простой поиск (бег и спорт)
search_query = "бег и спорт"
query_vector = model.encode(search_query).tolist()

res_a = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    limit=3
)

# Б. Фильтр по категории (tech) и рейтингу (>= 4.0)
res_b = client.search(
    collection_name=collection_name,
    query_vector=query_vector, # Вектор все равно нужен для поиска
    query_filter=models.Filter(
        must=[
            models.FieldCondition(key="category", match=models.MatchValue(value="tech")),
            models.FieldCondition(key="rating", range=models.Range(gte=4.0))
        ]
    ),
    limit=3
)

# В. Диапазон дат (> 2024-01-01) и просмотры (> 1000)
res_c = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    query_filter=models.Filter(
        must=[
            models.FieldCondition(key="published_at", range=models.Range(gt="2024-01-01T00:00:00Z")),
            models.FieldCondition(key="views", range=models.Range(gt=1000))
        ]
    ),
    limit=3
)

# Г. Сложный фильтр (OR, Range, Score)
res_d = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    query_filter=models.Filter(
        must=[
            models.Filter(
                should=[
                    models.FieldCondition(key="category", match=models.MatchValue(value="sport")),
                    models.FieldCondition(key="category", match=models.MatchValue(value="tech")),
                ]
            ),
            models.FieldCondition(key="rating", range=models.Range(gte=3.5)),
            models.FieldCondition(key="views", range=models.Range(gte=500, lte=5000)),
        ]
    ),
    limit=5
)

# Создание индексов
index_fields = [
    ("category", models.PayloadSchemaType.KEYWORD),
    ("rating", models.PayloadSchemaType.FLOAT),
    ("published_at", models.PayloadSchemaType.DATETIME),
    ("views", models.PayloadSchemaType.INTEGER),
]

for field_name, field_type in index_fields:
    client.create_payload_index(
        collection_name=collection_name,
        field_name=field_name,
        field_schema=field_type,
    )

print("Индексы созданы.")


def get_paged_results(page_number, page_size=2):
    offset = (page_number - 1) * page_size
    return client.search(
        collection_name=collection_name,
        query_vector=query_vector,
        limit=page_size,
        offset=offset
    )

# Пример: получаем "вторую страницу" (статьи 3 и 4)
page_2 = get_paged_results(page_number=2, page_size=2)
print(f"Найдено на 2-й странице: {len(page_2)}")
for hit in page_2:
    print(f"ID: {hit.id}, Title: {hit.payload['title']}")