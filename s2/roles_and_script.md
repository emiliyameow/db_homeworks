## Роли

### Создание ролей 
```postgresql
    CREATE ROLE readonly LOGIN PASSWORD 'read_pass';
    
    CREATE ROLE deleter LOGIN PASSWORD 'delete_pass';
    
    CREATE ROLE people_changer LOGIN PASSWORD 'change_pass';
```
    

### Право на подключение и использование объектов
```postgresql
    GRANT CONNECT ON DATABASE postgres TO readonly, deleter, people_changer;

    GRANT USAGE ON SCHEMA bakery_db TO deleter, readonly, people_changer;
```

### Выдача прав на изменение/чтение

```postgresql
    GRANT SELECT, INSERT, UPDATE, DELETE ON bakery_db.workers, bakery_db.clients, bakery_db.couriers 
        TO people_changer;
    
    GRANT DELETE ON ALL TABLES IN SCHEMA bakery_db TO deleter;
    
    GRANT SELECT ON ALL TABLES IN SCHEMA bakery_db TO readonly;
```

### Генерация данных

Программа на С# генерирует данные в таблицы workers, bakeries и bakery_goods:
```csharp

public static async Task InsertWorkers(int count)
{
    var connectionString =
        "Host=localhost;Port=5438;Database=postgres;Username=postgres;Password=2004";

    var random = new Random();

    var roles = new[]
    {
        "Пекарь",
        "Кондитер",
        "Бариста",
        "Уборщик",
        "Администратор",
        "Кассир"
    };

    var firstNames = new[]
    {
        "Иван", "Мария", "Алексей", "Екатерина", "Дмитрий",
        "Анна", "Сергей", "Ольга", "Павел", "Татьяна"
    };

    var lastNames = new[]
    {
        "Иванов", "Петров", "Сидоров", "Кузнецов", "Смирнов",
        "Васильев", "Новиков", "Фёдоров", "Соловьёв", "Морозов"
    };

    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();

    var bakeryIds = new List<int>();
    const string getBakeriesSql = "SELECT bakery_id FROM bakery_db.bakeries;";
    await using (var getCmd = new NpgsqlCommand(getBakeriesSql, conn))
    await using (var reader = await getCmd.ExecuteReaderAsync())
    {
        while (await reader.ReadAsync())
            bakeryIds.Add(reader.GetInt32(0));
    }

    if (bakeryIds.Count == 0)
    {
        Console.WriteLine("В таблице bakery_db.bakeries нет записей. Сначала заполни пекарни.");
        return;
    }

    await using var tx = await conn.BeginTransactionAsync();

    const string insertSql = @"
        INSERT INTO bakery_db.workers
            (phone_number, first_name, second_name, date_of_birth, role, bakery_id)
        VALUES
            (@phone_number, @first_name, @second_name, @date_of_birth, @role, @bakery_id);";

    await using var cmd = new NpgsqlCommand(insertSql, conn, tx);

    var pPhone      = cmd.Parameters.Add("phone_number", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pFirstName  = cmd.Parameters.Add("first_name", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pSecondName = cmd.Parameters.Add("second_name", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pDob        = cmd.Parameters.Add("date_of_birth", NpgsqlTypes.NpgsqlDbType.Date);
    var pRole       = cmd.Parameters.Add("role", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pBakeryId   = cmd.Parameters.Add("bakery_id", NpgsqlTypes.NpgsqlDbType.Integer);

    for (int i = 0; i < count; i++)
    {
        var phone = GenerateRussianPhone(random);
        pPhone.Value = phone;

        pFirstName.Value  = firstNames[random.Next(firstNames.Length)];
        pSecondName.Value = lastNames[random.Next(lastNames.Length)];

        pDob.Value = GenerateBirthDate(random, minAge: 18, maxAge: 60);

        pRole.Value = roles[random.Next(roles.Length)];

        pBakeryId.Value = bakeryIds[random.Next(bakeryIds.Count)];

        await cmd.ExecuteNonQueryAsync();
    }

    await tx.CommitAsync();

    Console.WriteLine($"Готово, вставлено {count} работников.");
}


static string GenerateRussianPhone(Random random)
{
    int secondDigit = random.Next(0, 10);
    int thirdDigit  = random.Next(0, 10);

    int block1 = random.Next(100, 1000); 
    int block2 = random.Next(10, 100);  
    int block3 = random.Next(10, 100);

    return $"79{secondDigit}{thirdDigit} {block1:D3}{block2:D2}{block3:D2}";
}

static DateTime GenerateBirthDate(Random random, int minAge, int maxAge)
{
    var today = DateTime.UtcNow.Date;
    var maxDate = today.AddYears(-minAge); 
    var minDate = today.AddYears(-maxAge); 

    var range = (maxDate - minDate).Days;
    var offset = random.Next(range + 1);

    return minDate.AddDays(offset);
}


public static async Task InsertBakeries(int count)
{
    var connectionString =
        "Host=localhost;Port=5438;Database=postgres;Username=postgres;Password=2004";

    var random = new Random();

    var streets = new[]
    {
        "улица Ленина",
        "ул. Пушкина",
        "ул. Гагарина",
        "ул. Советская",
        "ул. Молодёжная",
        "ул. Центральная",
        "ул. Школьная",
        "ул. Зеленая",
        "ул. Садовая",
        "ул. Набережная"
    };

    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();

    await using var tx = await conn.BeginTransactionAsync();

    const string sql = @"
        INSERT INTO bakery_db.bakeries
            (name, address, opening_time, closing_time, description)
        VALUES
            (@name, @address, @opening_time, @closing_time, @description);";

    await using var cmd = new NpgsqlCommand(sql, conn, tx);

    var pName        = cmd.Parameters.Add("name", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pAddress     = cmd.Parameters.Add("address", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pOpeningTime = cmd.Parameters.Add("opening_time", NpgsqlTypes.NpgsqlDbType.Time);
    var pClosingTime = cmd.Parameters.Add("closing_time", NpgsqlTypes.NpgsqlDbType.Time);
    var pDescription = cmd.Parameters.Add("description", NpgsqlTypes.NpgsqlDbType.Text);

    for (int i = 1; i <= count; i++)
    {
        pName.Value = $"Пекарня номер № {i}";

        var street = streets[random.Next(streets.Length)];
        var houseNumber = random.Next(1, 201);
        pAddress.Value = $"{street}, дом {houseNumber}";

        var openHour = random.Next(8, 11);   // 8–10
        pOpeningTime.Value = new TimeSpan(openHour, 0, 0);

        var closeHour = random.Next(20, 23); // 20–22
        pClosingTime.Value = new TimeSpan(closeHour, 0, 0);

        var needDescription = random.NextDouble() < 0.7;
        pDescription.Value = needDescription
            ? $"Уютная пекарня №{i} с свежей выпечкой и кофе."
            : DBNull.Value;

        await cmd.ExecuteNonQueryAsync();
    }

    await tx.CommitAsync();

    Console.WriteLine($"Готово, асинхронно вставлено {count} записей.");
}

public static async Task InsertBakeryGoods(int count)
{
    var connectionString =
        "Host=localhost;Port=5438;Database=postgres;Username=postgres;Password=2004";

    var random = new Random();

    var products = new[]
    {
        new { Name = "Хлеб пшеничный", RecipeId = 1 },
        new { Name = "Булочка сдобная", RecipeId = 2 },
        new { Name = "Торт шоколадный", RecipeId = 3 },
        new { Name = "Пирожок с капустой", RecipeId = 4 },
        new { Name = "Печенье овсяное", RecipeId = 5 },
        new { Name = "Кекс изюмный", RecipeId = 6 },
        new { Name = "Пирог яблочный", RecipeId = 7 },
        new { Name = "Батон нарезной", RecipeId = 8 },
        new { Name = "Рогалик слоеный", RecipeId = 9 },
        new { Name = "Пончик", RecipeId = 10 }
    };

    var unitIds = new[] { 1, 3, 4 }; // g, pcs, kg

    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();
    
    
    await using var tx = await conn.BeginTransactionAsync();

    const string insertSql = @"
        INSERT INTO bakery_db.baking_goods
            (name, size, unit_id, recipe_id, price)
        VALUES
            (@name, @size, @unit_id, @recipe_id, @price);";

    await using var cmd = new NpgsqlCommand(insertSql, conn, tx);

    var pName     = cmd.Parameters.Add("name", NpgsqlTypes.NpgsqlDbType.Varchar);
    var pSize     = cmd.Parameters.Add("size", NpgsqlTypes.NpgsqlDbType.Numeric);
    var pUnitId   = cmd.Parameters.Add("unit_id", NpgsqlTypes.NpgsqlDbType.Integer);
    var pRecipeId = cmd.Parameters.Add("recipe_id", NpgsqlTypes.NpgsqlDbType.Integer);
    var pPrice    = cmd.Parameters.Add("price", NpgsqlTypes.NpgsqlDbType.Numeric);

    var nameCounters = new Dictionary<string, int>();
    foreach (var product in products)
        nameCounters[product.Name] = 0;

    for (int i = 0; i < count; i++)
    {
        var product = products[random.Next(products.Length)];
        
        nameCounters[product.Name]++;
        pName.Value = $"{product.Name} #{nameCounters[product.Name]}";
        
        pRecipeId.Value = product.RecipeId; 

        var unitId = unitIds[random.Next(unitIds.Length)];
        pUnitId.Value = unitId;

        decimal size;
        switch (unitId)
        {
            case 1: // g - варьируем 50-1200г
                size = random.Next(50, 1201);
                break;
            case 4: // kg - 0.5-3кг
                size = (decimal)(0.5 + random.NextDouble() * 2.5);
                break;
            case 3: // pcs - 1-20шт
            default:
                size = random.Next(1, 21);
                break;
        }
        pSize.Value = size;

        decimal price;
        if (unitId == 3) // штуки
            price = random.Next(25, 151); // 25-150 руб
        else if (unitId == 4) // кг
            price = random.Next(200, 801); // 200-800 руб/кг
        else // граммы
            price = random.Next(20, 151); // 20-150 руб
        pPrice.Value = price;

        await cmd.ExecuteNonQueryAsync();
    }

    await tx.CommitAsync();

    Console.WriteLine($"Готово! Вставлено {count} товаров выпечки.");
}
```