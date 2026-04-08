var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () =>
{
    var teraz = DateTime.Now;
    var data = teraz.ToString("dd.MM.yyyy");
    var godzina = teraz.ToString("HH:mm:ss");
    
    var html = string.Format(@"
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <title>Data i godzina</title>
        </head>
        <body style='background-color: #2ecc71; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; font-family: Arial, sans-serif;'>
            <div style='background-color: white; padding: 40px 60px; border-radius: 10px; text-align: center;'>
                <div style='font-size: 64px; font-weight: bold; color: #2ecc71;'>{0}</div>
                <div style='font-size: 28px; color: #555; margin-top: 10px;'>{1}</div>
            </div>
        </body>
        </html>
    ", godzina, data);
    
    return Results.Content(html, "text/html");
});

app.MapGet("/health", () => Results.Ok());
app.Run();