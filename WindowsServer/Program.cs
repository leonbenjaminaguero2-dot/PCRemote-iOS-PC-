using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
var port = builder.Configuration.GetValue<int>("PCRemote:Port", 8765);
var pin = builder.Configuration["PCRemote:Pin"] ?? "4826";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
var app = builder.Build();

bool Authorized(HttpRequest req) => req.Headers.TryGetValue("X-PCRemote-Pin", out var supplied) && supplied.ToString() == pin;
app.Use(async (ctx, next) => {
    if (ctx.Request.Path.StartsWithSegments("/api") && !Authorized(ctx.Request)) {
        ctx.Response.StatusCode = 401; await ctx.Response.WriteAsync("PIN incorrecto"); return;
    }
    await next();
});
app.MapGet("/api/status", () => Results.Ok(new { online = true, machine = Environment.MachineName }));
app.MapGet("/api/screen", () => {
    try {
        var bounds = System.Windows.Forms.Screen.PrimaryScreen!.Bounds;
        using var bmp = new Bitmap(bounds.Width, bounds.Height);
        using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);
        using var ms = new MemoryStream(); bmp.Save(ms, ImageFormat.Png);
        return Results.File(ms.ToArray(), "image/png");
    } catch (Exception ex) { return Results.Problem(ex.Message); }
});
app.MapGet("/api/apps", ([FromQuery] string? search) => {
    var result = new List<object>();
    var roots = new[] { Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
        Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory) };
    foreach (var root in roots.Where(Directory.Exists)) {
        try { foreach (var file in Directory.EnumerateFiles(root, "*.lnk", SearchOption.AllDirectories).Take(500)) {
            var name = Path.GetFileNameWithoutExtension(file);
            if (!string.IsNullOrWhiteSpace(search) && !name.Contains(search, StringComparison.OrdinalIgnoreCase)) continue;
            if (!result.Any(x => ((dynamic)x).name == name)) result.Add(new { id=file, name, path=file });
        }} catch {}
    }
    return Results.Ok(result.OrderBy(x => ((dynamic)x).name).Take(150));
});
app.MapPost("/api/apps/open", ([FromBody] OpenAppRequest req) => {
    if (string.IsNullOrWhiteSpace(req.Path)) return Results.BadRequest();
    try {
        var roots = new[] { Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory) }.Where(Directory.Exists);
        var full = Path.GetFullPath(req.Path);
        if (!full.EndsWith(".lnk", StringComparison.OrdinalIgnoreCase) ||
            !roots.Any(r => full.StartsWith(Path.GetFullPath(r), StringComparison.OrdinalIgnoreCase)) || !File.Exists(full))
            return Results.BadRequest(new { error="Acceso no permitido" });
        Process.Start(new ProcessStartInfo(full) { UseShellExecute=true });
        return Results.Ok(new { opened=true });
    } catch (Exception ex) { return Results.Problem(ex.Message); }
});
app.MapPost("/api/input/key", ([FromBody] KeyRequest req) => {
    var map = new Dictionary<string, byte> { ["ENTER"]=0x0D, ["ESC"]=0x1B, ["BACKSPACE"]=0x08, ["SPACE"]=0x20,
        ["UP"]=0x26, ["DOWN"]=0x28, ["LEFT"]=0x25, ["RIGHT"]=0x27, ["TAB"]=0x09 };
    var key = (req.Key ?? "").ToUpperInvariant();
    if (!map.TryGetValue(key, out var code)) {
        if (key.Length != 1) return Results.BadRequest(new { error="Tecla no compatible" });
        code = (byte)key[0];
    }
    Native.keybd_event(code, 0, 0, UIntPtr.Zero); Native.keybd_event(code, 0, 2, UIntPtr.Zero);
    return Results.Ok(new { ok=true });
});
app.MapPost("/api/input/mouse", ([FromBody] MouseRequest req) => {
    Native.SetCursorPos(req.X, req.Y);
    if (req.Click) { Native.mouse_event(2,0,0,0,UIntPtr.Zero); Native.mouse_event(4,0,0,0,UIntPtr.Zero); }
    if (req.Scroll != 0) Native.mouse_event(0x0800,0,0,unchecked((uint)(req.Scroll*120)),UIntPtr.Zero);
    return Results.Ok(new { ok=true });
});
app.MapPost("/api/input/text", ([FromBody] TextRequest req) => {
    foreach (var c in (req.Text ?? "").Take(1000)) {
        Native.keybd_event(0, (byte)c, 4, UIntPtr.Zero); Native.keybd_event(0, (byte)c, 6, UIntPtr.Zero);
    }
    return Results.Ok(new { ok=true });
});
app.Run();
record OpenAppRequest(string Path);
record KeyRequest(string Key);
record MouseRequest(int X, int Y, bool Click=false, int Scroll=0);
record TextRequest(string Text);
static class Native {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte k,byte s,uint f,UIntPtr e);
}
