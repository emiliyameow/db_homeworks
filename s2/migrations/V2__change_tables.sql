ALTER TABLE bakery_db.recipes
    DROP COLUMN IF EXISTS calories,
    DROP COLUMN IF EXISTS proteins,
    DROP COLUMN IF EXISTS fats,
    DROP COLUMN IF EXISTS carbohydrates;


