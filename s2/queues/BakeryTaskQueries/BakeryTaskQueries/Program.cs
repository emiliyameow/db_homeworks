using Npgsql;

namespace BakeryTaskQueries;

using Microsoft.Extensions.Configuration;
using System.Threading;

class Program
{
    static async Task Main(string[] args)
    {
        var config = new ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build();
        Database.Initialize(config);

        Console.WriteLine("Выберите режим: producer (p) / consumer (c)");
        var key = Console.ReadKey().KeyChar;
        Console.WriteLine();

        if (key == 'p')
        {
            var producer = new Producer();
            await producer.RunAsync(taskCount: 500, delayMs: 200);
        }
        else if (key == 'c')
        {
            
            var cts = new CancellationTokenSource();
            Console.CancelKeyPress += (sender, e) => {
                e.Cancel = true;
                cts.Cancel();
                Console.WriteLine("Остановка воркеров...");
            };
            
            var consumer1 = new Consumer("worker-1");
            var consumer2 = new Consumer("worker-2");
            var task1 = consumer1.RunWithNotifyAsync(cts.Token);
            var task2 = consumer2.RunWithNotifyAsync(cts.Token);
            Task.Run(async () => {
                while (!cts.Token.IsCancellationRequested)
                {
                    await Task.Delay(5000);
                    long completed = Consumer.GetAndResetCompleted();
                    double throughput = completed / 5.0; // задач в секунду
                    Console.WriteLine($"[Throughput] {throughput:F2} tasks/sec (last 5 sec)");
                }
            });
            
            // Фоновая задача для мониторинга лага
            _ = Task.Run(async () => {
                using var conn = Database.GetConnection();
                await conn.OpenAsync();
    
                // Создаём CSV-файл с заголовками
                using var writer = new StreamWriter("lag_metrics.csv");
                await writer.WriteLineAsync("timestamp_iso,unix_seconds,lag_seconds,ready_tasks_count");
    
                while (!cts.Token.IsCancellationRequested)
                {
                    // Запрос: время самой старой задачи + количество готовых задач
                    const string sql = @"
            SELECT 
                COALESCE(EXTRACT(EPOCH FROM (NOW() - MIN(created_at))), 0) AS lag_seconds,
                COUNT(*) AS ready_count
            FROM bakery_db.tasks
            WHERE status = 0 AND scheduled_at <= NOW()";
        
                    using var cmd = new NpgsqlCommand(sql, conn);
                    using var reader = await cmd.ExecuteReaderAsync();
                    await reader.ReadAsync();
        
                    double lag = reader.GetDouble(0);
                    long readyCount = reader.GetInt64(1);
                    long unixNow = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                    string isoNow = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss");
        
                    // Запись в файл
                    await writer.WriteLineAsync($"{isoNow},{unixNow},{lag:F2},{readyCount}");
                    await writer.FlushAsync();  // сразу сохраняем на диск
        
                    Console.WriteLine($"[LAG] {isoNow} | lag={lag:F2} сек | ready={readyCount}");
        
                    await Task.Delay(5000, cts.Token);  // каждые 5 секунд
                }
            });
            await Task.WhenAll(task1, task2);
        }
    }
}