namespace BakeryTaskQueries;

using Npgsql;
using System.Text.Json;

public class Consumer
{
    private readonly string _workerId;
    private readonly Random _random = new Random();
    private bool _isRunning = true;
    private static long _totalCompleted = 0;

    public Consumer(string workerId)
    {
        _workerId = workerId;
    }

    // метод с polling
    public async Task RunAsync(CancellationToken token)
    {
        Console.WriteLine($"[Consumer {_workerId}] Запущен (polling mode)");
        using var conn = Database.GetConnection();
        await conn.OpenAsync();
        
        long taskId = 0;
        int attempts = 0;

        while (!token.IsCancellationRequested && _isRunning)
        {
            NpgsqlTransaction? tx = null;
            try
            {
                tx = await conn.BeginTransactionAsync();

                const string selectSql = @"
                    SELECT id, task_type, payload, priority, attempts
                    FROM bakery_db.tasks
                    WHERE status = 0 
                      AND scheduled_at <= NOW()
                    ORDER BY priority DESC, created_at
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED";

                using (var cmd = new NpgsqlCommand(selectSql, conn, tx))
                using (var reader = await cmd.ExecuteReaderAsync())
                {
                    if (!await reader.ReadAsync())
                    {
                        await tx.RollbackAsync();
                        await Task.Delay(500, token);
                        continue;
                    }
                    taskId = reader.GetInt64(0);
                    var taskType = reader.GetString(1);
                    var payloadJson = reader.GetString(2);
                    var priority = reader.GetInt32(3);
                    attempts = reader.GetInt32(4);
                }

                // Обновляем статус на Running
                const string updateSql = @"
                    UPDATE bakery_db.tasks
                    SET status = 1, worker_id = @worker_id, updated_at = NOW()
                    WHERE id = @id";
                using (var cmd = new NpgsqlCommand(updateSql, conn, tx))
                {
                    cmd.Parameters.AddWithValue("worker_id", _workerId);
                    cmd.Parameters.AddWithValue("id", taskId);
                    await cmd.ExecuteNonQueryAsync();
                }
                await tx.CommitAsync();
                tx = null;

                // Имитация обработки
                Console.WriteLine($"[{_workerId}] Задача {taskId} начата (попытка {attempts + 1})");
                await Task.Delay(_random.Next(1000, 3000), token);

                bool success = _random.NextDouble() < 0.8;
                if (success)
                {
                    await CompleteTaskAsync(taskId);
                    Console.WriteLine($"[{_workerId}] Задача {taskId} УСПЕШНО выполнена");
                }
                else
                {
                    await RetryOrDLQAsync(taskId, attempts, "Simulated processing error");
                    Console.WriteLine($"[{_workerId}] Задача {taskId} ошибка (попытка {attempts + 1})");
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                Console.WriteLine($"[{_workerId}] Критическая ошибка: {ex.Message}");
                if (tx != null) await tx.RollbackAsync();
                
                // Если задача была захвачена (taskId > 0), отправляем на повтор
                if (taskId > 0)
                {
                    await RetryOrDLQAsync(taskId, attempts, ex.Message);
                }
                else
                {
                    await Task.Delay(1000, token);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    // метод с LISTEN/NOTIFY
    public async Task RunWithNotifyAsync(CancellationToken token)
    {
        Console.WriteLine($"[Consumer {_workerId}] Запущен (notify mode)");
        using var conn = Database.GetConnection();
        await conn.OpenAsync();

        // Подписываемся на канал уведомлений
        using (var cmd = new NpgsqlCommand("LISTEN tasks_channel", conn))
            await cmd.ExecuteNonQueryAsync();

        // Обработчик уведомлений (устанавливает флаг)
        bool hasNotification = false;
        conn.Notification += (sender, e) =>
        {
            Console.WriteLine($"[{_workerId}] Получено уведомление: {e.Payload}");
            hasNotification = true;
        };

        long taskId = 0;
        int attempts = 0;

        while (!token.IsCancellationRequested && _isRunning)
        {
            NpgsqlTransaction? tx = null;
            try
            {
                // Пытаемся взять задачу (без ожидания, если нет - сразу вернём false)
                bool hasTask = false;
                tx = await conn.BeginTransactionAsync();

                const string selectSql = @"
                    SELECT id, task_type, payload, priority, attempts
                    FROM bakery_db.tasks
                    WHERE status = 0 
                      AND scheduled_at <= NOW()
                    ORDER BY priority DESC, created_at
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED";

                using (var cmd = new NpgsqlCommand(selectSql, conn, tx))
                using (var reader = await cmd.ExecuteReaderAsync())
                {
                    if (await reader.ReadAsync())
                    {
                        hasTask = true;
                        taskId = reader.GetInt64(0);
                        var taskType = reader.GetString(1);
                        var payloadJson = reader.GetString(2);
                        var priority = reader.GetInt32(3);
                        attempts = reader.GetInt32(4);
                    }
                }

                if (!hasTask)
                {
                    await tx.RollbackAsync();
                    // Нет задач – ждём уведомления (таймаут 10 сек, чтобы не зависнуть)
                    hasNotification = false;
                    await conn.WaitAsync(TimeSpan.FromSeconds(10), token);
                    continue;
                }

                // Обновляем статус на Running
                const string updateSql = @"
                    UPDATE bakery_db.tasks
                    SET status = 1, worker_id = @worker_id, updated_at = NOW()
                    WHERE id = @id";
                using (var cmd = new NpgsqlCommand(updateSql, conn, tx))
                {
                    cmd.Parameters.AddWithValue("worker_id", _workerId);
                    cmd.Parameters.AddWithValue("id", taskId);
                    await cmd.ExecuteNonQueryAsync();
                }
                await tx.CommitAsync();
                tx = null;

                // Обработка задачи
                Console.WriteLine($"[{_workerId}] Задача {taskId} начата (попытка {attempts + 1})");
                await Task.Delay(_random.Next(1000, 3000), token);

                bool success = _random.NextDouble() < 0.8;
                if (success)
                {
                    await CompleteTaskAsync(taskId);
                    Console.WriteLine($"[{_workerId}] Задача {taskId} УСПЕШНО выполнена");
                }
                else
                {
                    await RetryOrDLQAsync(taskId, attempts, "Simulated processing error");
                    Console.WriteLine($"[{_workerId}] Задача {taskId} ошибка (попытка {attempts + 1})");
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                Console.WriteLine($"[{_workerId}] Критическая ошибка: {ex.Message}");
                if (tx != null) await tx.RollbackAsync();
                if (taskId > 0)
                    await RetryOrDLQAsync(taskId, attempts, ex.Message);
                else
                    await Task.Delay(1000, token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task CompleteTaskAsync(long taskId)
    {
        using var conn = Database.GetConnection();
        await conn.OpenAsync();
        const string sql = @"
            UPDATE bakery_db.tasks 
            SET status = 2, updated_at = NOW(), worker_id = NULL 
            WHERE id = @id";
        using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("id", taskId);
        await cmd.ExecuteNonQueryAsync();
        Interlocked.Increment(ref _totalCompleted);
    }

    /// <summary>
    /// Отправляет задачу на повтор (exponential backoff) или в DLQ.
    /// </summary>
    private async Task RetryOrDLQAsync(long taskId, int currentAttempts, string errorMsg)
    {
        int newAttempts = currentAttempts + 1;
        int maxAttempts = 3;

        using var conn = Database.GetConnection();
        await conn.OpenAsync();

        if (newAttempts >= maxAttempts)
        {
            // Отправляем в Dead Letter Queue (статус 3)
            const string sql = @"
                UPDATE bakery_db.tasks
                SET status = 3,
                    attempts = @attempts,
                    last_error = @error,
                    worker_id = NULL
                WHERE id = @id";
            using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("id", taskId);
            cmd.Parameters.AddWithValue("attempts", newAttempts);
            cmd.Parameters.AddWithValue("error", errorMsg);
            await cmd.ExecuteNonQueryAsync();
            Console.WriteLine($"[{_workerId}] Задача {taskId} перемещена в DLQ (превышено {maxAttempts} попыток)");
        }
        else
        {
            // Экспоненциальная задержка: 5 мин * 2^(newAttempts)
            int delaySeconds = (int)Math.Pow(2, newAttempts) * 300;
            const string sql = @"
                UPDATE bakery_db.tasks
                SET status = 0,
                    attempts = @attempts,
                    scheduled_at = NOW() + (@delay || ' seconds')::interval,
                    last_error = @error,
                    worker_id = NULL
                WHERE id = @id";
            using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("id", taskId);
            cmd.Parameters.AddWithValue("attempts", newAttempts);
            cmd.Parameters.AddWithValue("delay", delaySeconds);
            cmd.Parameters.AddWithValue("error", errorMsg);
            await cmd.ExecuteNonQueryAsync();
            Console.WriteLine($"[{_workerId}] Задача {taskId} повтор через {delaySeconds / 60} мин (попытка {newAttempts})");
        }
    }

    public static long GetAndResetCompleted()
    {
        return Interlocked.Exchange(ref _totalCompleted, 0);
    }

    public void Stop() => _isRunning = false;
}