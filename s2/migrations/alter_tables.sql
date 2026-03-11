alter table postgres.bakery_db.bakeries add column opening_time time;

alter table postgres.bakery_db.bakeries add column closing_time time;

alter table postgres.bakery_db.bakeries add column description text;


alter table postgres.bakery_db.baking_goods alter column recipe_id drop not null;