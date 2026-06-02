using System.IO;

namespace ShareMyStatusClient.Utilities;

/// <summary>
/// Minimal thread-safe file logger. Writes to %APPDATA%\ShareMyStatus\logs\app.log
/// and mirrors to the debugger. Rotates when the file exceeds ~2 MB.
/// </summary>
public sealed class AppLogger
{
    private static readonly object Gate = new();
    private static readonly string LogDirectory =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ShareMyStatus", "logs");
    private static readonly string LogPath = Path.Combine(LogDirectory, "app.log");
    private const long MaxBytes = 2 * 1024 * 1024;

    private readonly string _category;

    private AppLogger(string category) => _category = category;

    public static AppLogger For(string category) => new(category);

    public static readonly AppLogger Reporter = For("reporter");
    public static readonly AppLogger Network = For("network");
    public static readonly AppLogger Cover = For("cover");
    public static readonly AppLogger System = For("system");
    public static readonly AppLogger Activity = For("activity");
    public static readonly AppLogger Media = For("media");
    public static readonly AppLogger App = For("app");

    public void Info(string message) => Write("INFO", message);
    public void Warning(string message) => Write("WARN", message);
    public void Error(string message) => Write("ERROR", message);
    public void Debug(string message) => Write("DEBUG", message);

    public void Error(string message, Exception ex) => Write("ERROR", $"{message}: {ex}");

    private void Write(string level, string message)
    {
        var line = $"{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] [{_category}] {message}";
        System.Diagnostics.Debug.WriteLine(line);
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(LogDirectory);
                if (File.Exists(LogPath) && new FileInfo(LogPath).Length > MaxBytes)
                {
                    var archived = LogPath + ".1";
                    File.Delete(archived);
                    File.Move(LogPath, archived);
                }
                File.AppendAllText(LogPath, line + Environment.NewLine);
            }
        }
        catch
        {
            // Never let logging crash the app.
        }
    }
}
