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
            var task1 = consumer1.RunAsync(cts.Token);
            var task2 = consumer2.RunAsync(cts.Token);
            Task.Run(async () => {
                while (!cts.Token.IsCancellationRequested)
                {
                    await Task.Delay(5000);
                    long completed = Consumer.GetAndResetCompleted();
                    double throughput = completed / 5.0; // задач в секунду
                    Console.WriteLine($"[Throughput] {throughput:F2} tasks/sec (last 5 sec)");
                }
            });
            
            await Task.WhenAll(task1, task2);
        }
    }
}