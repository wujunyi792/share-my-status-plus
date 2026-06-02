using System.Diagnostics;

namespace ShareMyStatusClient.Utilities;

/// <summary>A user-facing running application: its exe name plus a friendly display name.</summary>
public sealed record RunningApp(string ProcessName, string DisplayName, bool IsMedia = false);

public static class ProcessHelper
{
    /// <summary>
    /// Enumerates processes that currently own a visible main window, de-duplicated by
    /// executable name. Used to let users pick apps without typing exe names by hand.
    /// </summary>
    public static List<RunningApp> GetWindowedProcesses()
    {
        var result = new Dictionary<string, RunningApp>(StringComparer.OrdinalIgnoreCase);

        foreach (var process in Process.GetProcesses())
        {
            try
            {
                if (process.MainWindowHandle == IntPtr.Zero)
                    continue;
                if (string.IsNullOrEmpty(process.MainWindowTitle))
                    continue;

                string exe;
                try { exe = process.MainModule?.ModuleName ?? process.ProcessName + ".exe"; }
                catch { exe = process.ProcessName + ".exe"; }
                exe = exe.ToLowerInvariant();

                if (result.ContainsKey(exe))
                    continue;

                var display = process.ProcessName;
                try
                {
                    var fileName = process.MainModule?.FileName;
                    if (fileName != null)
                    {
                        var info = FileVersionInfo.GetVersionInfo(fileName);
                        if (!string.IsNullOrWhiteSpace(info.FileDescription))
                            display = info.FileDescription!;
                    }
                }
                catch
                {
                    // Keep the process name as the display.
                }

                result[exe] = new RunningApp(exe, display);
            }
            catch
            {
                // Ignore processes we can't inspect.
            }
            finally
            {
                process.Dispose();
            }
        }

        return result.Values.OrderBy(a => a.DisplayName, StringComparer.CurrentCultureIgnoreCase).ToList();
    }
}
