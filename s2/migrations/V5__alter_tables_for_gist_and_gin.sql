-- Добавляем колонки для GIN (jsonb, массивы, tsvector)
ALTER TABLE bakery_db.recipes ADD COLUMN tags TEXT[];
ALTER TABLE bakery_db.recipes ADD COLUMN nutrition_info JSONB;
ALTER TABLE bakery_db.recipes ADD COLUMN search_vector TSVECTOR;

ALTER TABLE bakery_db.ingredients ADD COLUMN properties JSONB;
ALTER TABLE bakery_db.baking_goods ADD COLUMN dietary_tags TEXT[];

-- Добавляем колонки для GiST (диапазоны, геометрия)
ALTER TABLE bakery_db.bakeries ADD COLUMN delivery_area daterange;
ALTER TABLE bakery_db.bakeries ADD COLUMN coordinates point;
ALTER TABLE bakery_db.orders ADD COLUMN delivery_time_range tstzrange;
ALTER TABLE bakery_db.workers ADD COLUMN work_schedule daterange;