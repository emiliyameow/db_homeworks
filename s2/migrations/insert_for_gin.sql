
-- для сохранения лежит в миграциях --
-- Обновляем recipes с тегами, nutrition_info и search_vector
WITH recipe_data AS (
    SELECT 
        recipe_id,
        description,
        -- Генерируем теги на основе описания
        CASE 
            WHEN description ILIKE '%хлеб%' THEN ARRAY['хлеб', 'выпечка']
            WHEN description ILIKE '%торт%' THEN ARRAY['десерт', 'торт', 'сладкое']
            WHEN description ILIKE '%пирож%' THEN ARRAY['пирожки', 'выпечка', 'с выпечкой']
            WHEN description ILIKE '%печенье%' THEN ARRAY['печенье', 'десерт', 'сладкое']
            WHEN description ILIKE '%кекс%' THEN ARRAY['кекс', 'десерт', 'сладкое']
            WHEN description ILIKE '%пирог%' THEN ARRAY['пирог', 'выпечка', 'фруктовый']
            WHEN description ILIKE '%батон%' THEN ARRAY['хлеб', 'батон', 'выпечка']
            WHEN description ILIKE '%рогалик%' THEN ARRAY['рогалик', 'выпечка', 'слоеное']
            WHEN description ILIKE '%пончик%' THEN ARRAY['пончик', 'десерт', 'жареное']
            ELSE ARRAY['выпечка', 'домашняя']
        END AS new_tags,
        -- Создаем nutrition_info JSONB
        jsonb_build_object(
            'calories_per_100g', (random() * 300 + 150)::int,
            'is_vegan', random() < 0.3,
            'is_gluten_free', random() < 0.1,
            'allergens', 
            CASE 
                WHEN random() < 0.3 THEN jsonb_build_array('gluten')
                WHEN random() < 0.6 THEN jsonb_build_array('gluten', 'eggs')
                WHEN random() < 0.8 THEN jsonb_build_array('gluten', 'milk')
                ELSE jsonb_build_array('gluten', 'eggs', 'milk', 'nuts')
            END,
            'dietary_labels',
            CASE 
                WHEN random() < 0.2 THEN jsonb_build_array('vegetarian')
                WHEN random() < 0.3 THEN jsonb_build_array('vegan')
                WHEN random() < 0.5 THEN jsonb_build_array('low_fat')
                ELSE jsonb_build_array()
            END
        ) AS new_nutrition_info
    FROM bakery_db.recipes
)
UPDATE bakery_db.recipes r
SET 
    tags = rd.new_tags,
    nutrition_info = rd.new_nutrition_info,
    search_vector = to_tsvector('russian', COALESCE(r.description, ''))
FROM recipe_data rd
WHERE r.recipe_id = rd.recipe_id;

-- Для рецептов без описания добавляем базовые значения
UPDATE bakery_db.recipes 
SET 
    tags = ARRAY['рецепт', 'выпечка'],
    nutrition_info = '{"calories_per_100g": 250, "is_vegan": false, "allergens": ["gluten"]}',
    search_vector = to_tsvector('russian', COALESCE(description, 'рецепт выпечки'))
WHERE tags IS NULL;

-- Обновляем ingredients с properties JSONB
WITH ingredient_data AS (
    SELECT 
        ingredient_id,
        name,
        jsonb_build_object(
            'category',
            CASE 
                WHEN name ILIKE '%мука%' OR name ILIKE '%сахар%' OR name ILIKE '%соль%' THEN 'сухие'
                WHEN name ILIKE '%молоко%' OR name ILIKE '%масло%' OR name ILIKE '%яйцо%' THEN 'жидкие/молочные'
                WHEN name ILIKE '%дрожжи%' OR name ILIKE '%разрыхлитель%' THEN 'разрыхлители'
                WHEN name ILIKE '%фрукт%' OR name ILIKE '%ягод%' OR name ILIKE '%орех%' THEN 'наполнители'
                ELSE 'прочее'
            END,
            'storage_conditions',
            CASE 
                WHEN random() < 0.3 THEN 'room_temperature'
                WHEN random() < 0.7 THEN 'refrigerated'
                ELSE 'frozen'
            END,
            'shelf_life_days', (random() * 300 + 30)::int,
            'is_organic', random() < 0.2,
            'supplier',
            CASE floor(random() * 5)
                WHEN 0 THEN 'ООО "АгроПродукт"'
                WHEN 1 THEN 'ИП Иванов'
                WHEN 2 THEN 'АО "Зерновой союз"'
                WHEN 3 THEN 'ООО "Молочная ферма"'
                ELSE 'Импортные поставки'
            END,
            'certifications',
            CASE 
                WHEN random() < 0.3 THEN jsonb_build_array('ISO 22000', 'HALAL')
                WHEN random() < 0.6 THEN jsonb_build_array('ГОСТ', 'Эко')
                WHEN random() < 0.8 THEN jsonb_build_array('ISO 9001')
                ELSE jsonb_build_array()
            END
        ) AS new_properties
    FROM bakery_db.ingredients
)
UPDATE bakery_db.ingredients i
SET properties = id.new_properties
FROM ingredient_data id
WHERE i.ingredient_id = id.ingredient_id;

-- Обновляем baking_goods с dietary_tags
WITH baking_data AS (
    SELECT 
        baking_id,
        name,
        -- Генерируем диетические теги на основе названия
        ARRAY(
            SELECT DISTINCT unnest(
                CASE 
                    WHEN name ILIKE '%овсян%' THEN ARRAY['овсяное', 'полезное']
                    WHEN name ILIKE '%ржаной%' OR name ILIKE '%ржано%' THEN ARRAY['ржаное', 'цельнозерновое']
                    WHEN name ILIKE '%сдобн%' THEN ARRAY['сдобное', 'масляное']
                    WHEN name ILIKE '%шоколад%' THEN ARRAY['шоколадное', 'десерт']
                    WHEN name ILIKE '%фрукт%' OR name ILIKE '%яблоч%' THEN ARRAY['фруктовое', 'натуральное']
                    WHEN name ILIKE '%без сахар%' THEN ARRAY['без сахара', 'диетическое']
                    ELSE ARRAY['обычное']
                END || 
                CASE 
                    WHEN random() < 0.15 THEN ARRAY['безглютеновый']
                    ELSE ARRAY[]::text[]
                END ||
                CASE 
                    WHEN random() < 0.2 THEN ARRAY['веганский']
                    ELSE ARRAY[]::text[]
                END ||
                CASE 
                    WHEN random() < 0.1 THEN ARRAY['низкокалорийный']
                    ELSE ARRAY[]::text[]
                END
            )
        ) AS new_dietary_tags
    FROM bakery_db.baking_goods
)
UPDATE bakery_db.baking_goods bg
SET dietary_tags = bd.new_dietary_tags
FROM baking_data bd
WHERE bg.baking_id = bd.baking_id;

-- Обновляем bakeries с delivery_area и coordinates
UPDATE bakery_db.bakeries 
SET 
    -- Случайные координаты в пределах Казани
    coordinates = point(
        55.7 + (random() * 0.2),  -- широта ~55.7-55.9
        49.0 + (random() * 0.3)    -- долгота ~49.0-49.3
    ),
    -- Диапазоны доставки с гарантией lower <= upper
    delivery_area = daterange(
        (CURRENT_DATE + (random() * 15)::int)::date,  -- от 0 до 15 дней вперед
        (CURRENT_DATE + 30 + (random() * 60)::int)::date,  -- минимум +30 дней, максимум +90
        '[)'
    )
WHERE bakery_id IS NOT NULL;

-- Для конкретных пекарен устанавливаем осмысленные значения
UPDATE bakery_db.bakeries 
SET 
    coordinates = point(55.7887, 49.1221),  -- Центр Казани
    delivery_area = daterange('2026-03-01', '2026-06-01')
WHERE bakery_id = 1;

UPDATE bakery_db.bakeries 
SET 
    coordinates = point(55.8304, 49.0666),  -- Север Казани
    delivery_area = daterange('2026-03-15', '2026-05-15')
WHERE bakery_id = 2;

UPDATE bakery_db.bakeries 
SET 
    coordinates = point(55.7465, 49.1855),  -- Восток Казани
    delivery_area = daterange('2026-04-01', '2026-07-01')
WHERE bakery_id = 3;

-- Обновляем orders с delivery_time_range
WITH order_delivery AS (
    SELECT 
        order_id,
        -- Базовая дата: от сегодня до +7 дней
        (CURRENT_TIMESTAMP + (random() * interval '7 days'))::timestamptz as base_time,
        -- Генерируем случайные значения один раз для каждого order_id
        floor(random() * 12)::int as hour_offset,  -- 0-11 для добавления к 8 (получится 8-19)
        (floor(random() * 3) + 1)::int as duration_hours  -- 1-4 часа длительность
    FROM bakery_db.orders
    WHERE delivery_time_range IS NULL
)
UPDATE bakery_db.orders o
SET delivery_time_range = tstzrange(
    -- Нижняя граница: base_time + случайные часы (8-20)
    date_trunc('hour', od.base_time) + (od.hour_offset + 8) * interval '1 hour',
    -- Верхняя граница: нижняя граница + длительность (1-4 часа)
    date_trunc('hour', od.base_time) + (od.hour_offset + 8) * interval '1 hour' 
        + od.duration_hours * interval '1 hour',
    '[)'
)
FROM order_delivery od
WHERE o.order_id = od.order_id;

-- Обновляем workers с work_schedule (график работы)
WITH worker_schedule AS (
    SELECT 
        worker_id,
        -- Создаем рабочий график с гарантией lower <= upper
        daterange(
            -- Начало: от 3 месяцев назад до сегодня
            LEAST(
                CURRENT_DATE - interval '3 months' + (random() * 90)::int * interval '1 day',
                CURRENT_DATE + (random() * 180)::int * interval '1 day'
            )::date,
            -- Конец: от сегодня до +6 месяцев вперед (но не меньше начала)
            GREATEST(
                CURRENT_DATE - interval '3 months' + (random() * 90)::int * interval '1 day',
                CURRENT_DATE + (random() * 180)::int * interval '1 day'
            )::date,
            '[)'
        ) AS new_schedule
    FROM bakery_db.workers
    WHERE work_schedule IS NULL
)
UPDATE bakery_db.workers w
SET work_schedule = ws.new_schedule
FROM worker_schedule ws
WHERE w.worker_id = ws.worker_id;

-- Для некоторых сотрудников устанавливаем конкретные графики
UPDATE bakery_db.workers 
SET work_schedule = daterange('2026-01-01', '2026-12-31')  -- весь год
WHERE worker_id IN (1, 2, 3) AND work_schedule IS NULL;

UPDATE bakery_db.workers 
SET work_schedule = daterange('2026-03-01', '2026-05-31')  -- весенний сезон
WHERE worker_id IN (4, 5, 6) AND work_schedule IS NULL;

UPDATE bakery_db.workers 
SET work_schedule = daterange('2026-04-01', '2026-09-30')  -- летний сезон
WHERE worker_id IN (7, 8, 9) AND work_schedule IS NULL;

