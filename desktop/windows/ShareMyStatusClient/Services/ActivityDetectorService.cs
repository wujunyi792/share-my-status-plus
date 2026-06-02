using System.Diagnostics;
using ShareMyStatusClient.Interop;
using ShareMyStatusClient.Models.Domain;
using ShareMyStatusClient.Models.Settings;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Detects the foreground application and maps it to an activity label. On Windows the
/// app is identified by its process executable name (e.g. "chrome.exe"). The raw window
/// title is collected locally for display only and is never reported.
/// </summary>
public sealed class ActivityDetectorService
{
    private readonly AppLogger _logger = AppLogger.Activity;

    public ActivitySnapshot? Collect(IReadOnlyList<ActivityGroup> groups)
    {
        var hwnd = NativeMethods.GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
            return null;

        var (processName, appName) = GetForegroundProcess(hwnd);
        if (processName == null)
            return null;

        var windowTitle = GetWindowTitle(hwnd);
        var idle = GetIdleSeconds();
        var tag = MapActivityTag(processName, groups);

        return new ActivitySnapshot(
            ActiveApplication: appName ?? processName,
            ProcessName: processName,
            WindowTitle: windowTitle,
            IdleTimeSeconds: idle,
            ActivityTag: tag,
            Timestamp: DateTimeOffset.Now);
    }

    private (string? processName, string? appName) GetForegroundProcess(IntPtr hwnd)
    {
        try
        {
            NativeMethods.GetWindowThreadProcessId(hwnd, out var pid);
            if (pid == 0)
                return (null, null);

            using var process = Process.GetProcessById((int)pid);

            string? exeName = null;
            try
            {
                // ModuleName gives "chrome.exe"; can throw for protected/elevated processes.
                exeName = process.MainModule?.ModuleName;
            }
            catch
            {
                // Fall back to the process name without extension.
            }

            exeName ??= process.ProcessName + ".exe";
            return (exeName.ToLowerInvariant(), process.ProcessName);
        }
        catch (Exception ex)
        {
            _logger.Debug($"Failed to resolve foreground process: {ex.Message}");
            return (null, null);
        }
    }

    private static string? GetWindowTitle(IntPtr hwnd)
    {
        var length = NativeMethods.GetWindowTextLength(hwnd);
        if (length <= 0)
            return null;

        var buffer = new char[length + 1];
        var copied = NativeMethods.GetWindowText(hwnd, buffer, buffer.Length);
        if (copied <= 0)
            return null;

        var title = new string(buffer, 0, copied);
        return string.IsNullOrWhiteSpace(title) ? null : title;
    }

    private static double GetIdleSeconds()
    {
        var info = new NativeMethods.LASTINPUTINFO
        {
            cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.LASTINPUTINFO>(),
        };
        if (!NativeMethods.GetLastInputInfo(ref info))
            return 0;

        var idleMs = unchecked(NativeMethods.GetTickCount() - info.dwTime);
        return idleMs / 1000.0;
    }

    private static string MapActivityTag(string processName, IReadOnlyList<ActivityGroup> groups)
    {
        foreach (var group in groups)
        {
            if (!group.IsEnabled)
                continue;
            if (group.ProcessNames.Contains(processName))
                return group.Name;
        }
        return DefaultSettings.DefaultActivityTag;
    }
}
