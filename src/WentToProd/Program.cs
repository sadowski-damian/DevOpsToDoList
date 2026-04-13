// Import Npgsql library
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Grab connection string from app.settings.json or environment var ConnectionStrings__Postgres
var connectionString = builder.Configuration.GetConnectionString("Postgres");

// If table doest exist create it, ! means that we know connecitonString is not null
await InitDb(connectionString!);

// Endpoint / 
app.MapGet("/", async () =>
{
    // Empty list for db rows
    var rows = new List<Deploy>();
    // Db conn
    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();
    // Get 20 last deploys
    await using var cmd = new NpgsqlCommand(
        "SELECT commit_sha, author, message, committed_at, deployed_at FROM deploys ORDER BY deployed_at DESC LIMIT 20", conn);
    // Execute query and return object for reading 
    await using var reader = await cmd.ExecuteReaderAsync();
    // Reading rows one by one
    while (await reader.ReadAsync())
        rows.Add(new Deploy(
            reader.GetString(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetDateTime(3).ToString("dd.MM.yyyy HH:mm"),
            reader.GetDateTime(4).ToString("dd.MM.yyyy HH:mm")
        ));
    // Obejct list -> Html string with table rows 
    var tableRows = string.Join("", rows.Select(d => $"""
        <tr>
            <td><code>{System.Net.WebUtility.HtmlEncode(d.CommitSha[..7])}</code></td>
            <td>{System.Net.WebUtility.HtmlEncode(d.Author)}</td>
            <td>{System.Net.WebUtility.HtmlEncode(d.Message)}</td>
            <td>{d.CommittedAt}</td>
            <td>{d.DeployedAt}</td>
        </tr>
    """));

    // Whole html document 
    var html = $"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <title>WentToProd</title>
            <style>
                body {{ font-family: Arial, sans-serif; background: #1e1e2e; color: #cdd6f4; margin: 0; padding: 40px; }}
                h1 {{ color: #a6e3a1; }}
                table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
                th {{ background: #313244; padding: 12px; text-align: left; color: #89b4fa; }}
                td {{ padding: 10px 12px; border-bottom: 1px solid #313244; }}
                tr:hover td {{ background: #252535; }}
                code {{ background: #313244; padding: 2px 6px; border-radius: 4px; color: #f38ba8; }}
            </style>
        </head>
        <body>
            <h1>WentToProd - historia deployów</h1>
            <table>
                <thead>
                    <tr>
                        <th>Commit</th>
                        <th>Autor</th>
                        <th>Opis</th>
                        <th>Data commita</th>
                        <th>Deploy</th>
                    </tr>
                </thead>
                <tbody>
                    {tableRows}
                </tbody>
            </table>
        </body>
        </html>
    """;

    // Return HTML document 
    return Results.Content(html, "text/html");
});

// Endpoint /deploys
app.MapPost("/deploys", async (HttpContext ctx, DeployRequest req) =>
{
    // Download API key (userData script from SSM) 
    var expectedKey = builder.Configuration["ApiKey"];
    // Check if request X-API-Key matches our expectedKey 
    if (ctx.Request.Headers["X-Api-Key"] != expectedKey)
        return Results.Unauthorized();

    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();
    await using var cmd = new NpgsqlCommand(@"
        INSERT INTO deploys (commit_sha, author, message, committed_at)
        VALUES (@sha, @author, @message, @committed_at)", conn);
    cmd.Parameters.AddWithValue("sha", req.CommitSha);
    cmd.Parameters.AddWithValue("author", req.Author);
    cmd.Parameters.AddWithValue("message", req.Message);
    cmd.Parameters.AddWithValue("committed_at", req.CommittedAt);
    await cmd.ExecuteNonQueryAsync();
    return Results.Created("/", null);
});

app.MapGet("/health", () => Results.Ok());

app.Run();

// Run at startup - creates db schema
async Task InitDb(string connStr)
{
    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();
    await using var cmd = new NpgsqlCommand(@"
        CREATE TABLE IF NOT EXISTS deploys (
            id           SERIAL PRIMARY KEY,
            commit_sha   TEXT NOT NULL,
            author       TEXT NOT NULL,
            message      TEXT NOT NULL,
            committed_at TIMESTAMPTZ NOT NULL,
            deployed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )", conn);
    await cmd.ExecuteNonQueryAsync();
}

record Deploy(string CommitSha, string Author, string Message, string CommittedAt, string DeployedAt);
record DeployRequest(string CommitSha, string Author, string Message, DateTime CommittedAt);