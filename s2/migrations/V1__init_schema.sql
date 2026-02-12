
CREATE SCHEMA IF NOT EXISTS bakery_db;

-- 1. Базовые сущности
CREATE TABLE bakery_db.bakeries (
                                    bakery_id SERIAL PRIMARY KEY,
                                    name VARCHAR(100) NOT NULL,
                                    address VARCHAR(100) NOT NULL
);

CREATE TABLE bakery_db.workers (
                                   worker_id SERIAL PRIMARY KEY,
                                   role VARCHAR(100) NOT NULL,
                                   phone_number VARCHAR(15),
                                   first_name VARCHAR(50),
                                   second_name VARCHAR(50),
                                   date_of_birth DATE,
                                   bakery_id INT,
                                   CONSTRAINT fk_workers_bakery
                                       FOREIGN KEY (bakery_id)
                                           REFERENCES bakery_db.bakeries(bakery_id)
                                           ON DELETE CASCADE
);

CREATE TABLE bakery_db.appliances (
                                      appliance_id SERIAL PRIMARY KEY,
                                      bakery_id INT NOT NULL,
                                      name VARCHAR(50) NOT NULL,
                                      document VARCHAR(50),
                                      CONSTRAINT fk_appliances_bakery
                                          FOREIGN KEY (bakery_id)
                                              REFERENCES bakery_db.bakeries(bakery_id)
                                              ON DELETE CASCADE
);

-- 2. Таблицы рецептов и ингредиентов
CREATE TABLE bakery_db.recipes (
                                   recipe_id SERIAL PRIMARY KEY,
                                   description VARCHAR(200)
);

CREATE TABLE bakery_db.ingredients (
                                       ingredient_id SERIAL PRIMARY KEY,
                                       name VARCHAR(50),
                                       calories NUMERIC(10,2),
                                       proteins NUMERIC(10,2),
                                       fats NUMERIC(10,2),
                                       carbohydrates NUMERIC(10,2)
);

-- 3. Единицы измерения
CREATE TABLE bakery_db.units (
                                 unit_id SERIAL PRIMARY KEY,
                                 unit_name VARCHAR(20) NOT NULL UNIQUE,
                                 description VARCHAR(100)
);

INSERT INTO bakery_db.units (unit_name, description) VALUES
                                                         ('g', 'граммы'),
                                                         ('ml', 'миллилитры'),
                                                         ('pcs', 'штуки');

-- 4. Связь рецептов с ингредиентами
CREATE TABLE bakery_db.recipes_ingredients (
                                               recipe_id INT NOT NULL,
                                               ingredient_id INT NOT NULL,
                                               quantity NUMERIC(10,2) NOT NULL,
                                               unit_id INT NOT NULL,
                                               PRIMARY KEY (recipe_id, ingredient_id),
                                               CONSTRAINT fk_recipes_ingredients_recipe
                                                   FOREIGN KEY (recipe_id)
                                                       REFERENCES bakery_db.recipes(recipe_id)
                                                       ON DELETE CASCADE,
                                               CONSTRAINT fk_recipes_ingredients_ingredient
                                                   FOREIGN KEY (ingredient_id)
                                                       REFERENCES bakery_db.ingredients(ingredient_id)
                                                       ON DELETE CASCADE,
                                               CONSTRAINT fk_recipes_ingredients_unit
                                                   FOREIGN KEY (unit_id)
                                                       REFERENCES bakery_db.units(unit_id)
                                                       ON DELETE RESTRICT
);

-- 5. Рецепты и оборудование
CREATE TABLE bakery_db.recipes_appliances (
                                              recipe_id INT NOT NULL,
                                              appliance_id INT NOT NULL,
                                              PRIMARY KEY (recipe_id, appliance_id),
                                              CONSTRAINT fk_recipes_appliances_recipe
                                                  FOREIGN KEY (recipe_id)
                                                      REFERENCES bakery_db.recipes(recipe_id)
                                                      ON DELETE CASCADE,
                                              CONSTRAINT fk_recipes_appliances_appliance
                                                  FOREIGN KEY (appliance_id)
                                                      REFERENCES bakery_db.appliances(appliance_id)
                                                      ON DELETE CASCADE
);

-- 6. Клиенты 
CREATE TABLE bakery_db.clients (
                                   client_id SERIAL PRIMARY KEY,
                                   phone_number VARCHAR(11),
                                   last_name VARCHAR(80),
                                   first_name VARCHAR(80),
                                   middle_name VARCHAR(80),
                                   birth_date DATE
);

-- 7. Курьеры 
CREATE TABLE bakery_db.couriers (
                                    courier_id SERIAL PRIMARY KEY,
                                    phone_number VARCHAR(11),
                                    last_name VARCHAR(80),
                                    first_name VARCHAR(80),
                                    middle_name VARCHAR(80)
);

-- 8. Заказы
CREATE TABLE bakery_db.orders (
                                  order_id SERIAL PRIMARY KEY,
                                  client_id INT NOT NULL,
                                  bakery_id INT NOT NULL,
                                  type_of_order VARCHAR(50),
                                  CONSTRAINT fk_orders_client
                                      FOREIGN KEY (client_id)
                                          REFERENCES bakery_db.clients(client_id)
                                          ON DELETE CASCADE,
                                  CONSTRAINT fk_orders_bakery
                                      FOREIGN KEY (bakery_id)
                                          REFERENCES bakery_db.bakeries(bakery_id)
                                          ON DELETE CASCADE
);

-- 9. Выпечка
CREATE TABLE bakery_db.baking_goods (
                                        baking_id SERIAL PRIMARY KEY,
                                        name VARCHAR(100) NOT NULL,
                                        size NUMERIC(10,2) NOT NULL,
                                        unit_id INT NOT NULL,
                                        recipe_id INT NOT NULL,
                                        CONSTRAINT fk_baking_goods_recipe
                                            FOREIGN KEY (recipe_id)
                                                REFERENCES bakery_db.recipes(recipe_id)
                                                ON DELETE CASCADE,
                                        CONSTRAINT fk_baking_goods_unit
                                            FOREIGN KEY (unit_id)
                                                REFERENCES bakery_db.units(unit_id)
                                                ON DELETE RESTRICT
);

-- 10. Состав заказов
CREATE TABLE bakery_db.order_baking_goods (
                                              order_id INT NOT NULL,
                                              baking_id INT NOT NULL,
                                              quantity NUMERIC(10,2) NOT NULL,
                                              unit_id INT NOT NULL,
                                              PRIMARY KEY (order_id, baking_id),
                                              CONSTRAINT fk_order_baking_goods_order
                                                  FOREIGN KEY (order_id)
                                                      REFERENCES bakery_db.orders(order_id)
                                                      ON DELETE CASCADE,
                                              CONSTRAINT fk_order_baking_goods_baking
                                                  FOREIGN KEY (baking_id)
                                                      REFERENCES bakery_db.baking_goods(baking_id)
                                                      ON DELETE CASCADE,
                                              CONSTRAINT fk_order_baking_goods_unit
                                                  FOREIGN KEY (unit_id)
                                                      REFERENCES bakery_db.units(unit_id)
                                                      ON DELETE RESTRICT
);

-- 11. Доставка
CREATE TABLE bakery_db.delivery_orders (
                                           delivery_id SERIAL PRIMARY KEY,
                                           order_id INT NOT NULL,
                                           courier_id INT NOT NULL,
                                           address VARCHAR(150),
                                           CONSTRAINT fk_delivery_orders_order
                                               FOREIGN KEY (order_id)
                                                   REFERENCES bakery_db.orders(order_id)
                                                   ON DELETE CASCADE,
                                           CONSTRAINT fk_delivery_orders_courier
                                               FOREIGN KEY (courier_id)
                                                   REFERENCES bakery_db.couriers(courier_id)
                                                   ON DELETE CASCADE
);
