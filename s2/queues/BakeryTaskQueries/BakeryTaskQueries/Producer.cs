namespace BakeryTaskQueries;

using Npgsql;
using System.Text.Json;

public class Producer
{
    private readonly Random _random = new Random();
    private readonly string _workerId = "producer-1";

    public async Task RunAsync(int taskCount = 500, int delayMs = 100)
    {
        using var conn = Database.GetConnection();
        await conn.OpenAsync();

        for (int i = 0; i < taskCount; i++)
        {
            // Определяем приоритет: 20% критических (priority=100), 80% обычных (0)
            int priority = _random.NextDouble() < 0.2 ? 100 : 0;
            
            // Формируем полезную нагрузку (пример – задача на выпечку)
            var payload = new
            {
                order_id = _random.Next(1, 101),
                baking_good_id = _random.Next(1, 11),
                quantity = _random.Next(1, 10)
            };
            string jsonPayload = JsonSerializer.Serialize(payload);
            string taskType = "baking_task";

            // Транзакция: вставка задачи + фиктивная бизнес-логика
            using var tx = await conn.BeginTransactionAsync();
            try
            {
                // 1. Вставка задачи в очередь
                const string insertSql = @"
                    INSERT INTO bakery_db.tasks (task_type, payload, priority, status, created_at)
                    VALUES (@task_type, @payload::jsonb, @priority, 0, NOW())
                    RETURNING id;";
                
                long taskId;
                using (var cmd = new NpgsqlCommand(insertSql, conn, tx))
                {
                    cmd.Parameters.AddWithValue("task_type", taskType);
                    cmd.Parameters.AddWithValue("payload", jsonPayload);
                    cmd.Parameters.AddWithValue("priority", priority);
                    taskId = (long)await cmd.ExecuteScalarAsync();
                }
                

                // 2. Фиктивная бизнес-логика (запись в лог заказов, обновление статистики и т.д.)
                const string bizSql = @"
                    INSERT INTO bakery_db.order_log (task_id, order_id, logged_at)
                    VALUES (@task_id, @order_id, NOW())";
                using (var cmd = new NpgsqlCommand(bizSql, conn, tx))
                {
                    cmd.Parameters.AddWithValue("task_id", taskId);
                    cmd.Parameters.AddWithValue("order_id", payload.order_id);
                    await cmd.ExecuteNonQueryAsync();
                }
                using (var cmd = new NpgsqlCommand("NOTIFY tasks_channel, 'new_task'", conn, tx))
                    await cmd.ExecuteNonQueryAsync();
                
                await tx.CommitAsync();
                Console.WriteLine($"[Producer] Создана задача {taskId} (приоритет {priority})");
            }
            catch (Exception ex)
            {
                await tx.RollbackAsync();
                Console.WriteLine($"[Producer] Ошибка при создании задачи: {ex.Message}");
            }

            await Task.Delay(delayMs); // пауза между генерациями
        }
    }
}