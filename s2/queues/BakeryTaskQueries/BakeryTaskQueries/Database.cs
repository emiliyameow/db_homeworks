using Microsoft.Extensions.Configuration;

namespace BakeryTaskQueries;

using Npgsql;

public static class Database
{
    private static string _connectionString;

    public static void Initialize(IConfiguration config)
    {
        _connectionString = config.GetConnectionString("PostgreSQL");
    }

    public static NpgsqlConnection GetConnection() => new NpgsqlConnection(_connectionString);
}