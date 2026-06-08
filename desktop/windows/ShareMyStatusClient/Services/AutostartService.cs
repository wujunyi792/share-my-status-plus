using System.Diagnostics;
using Microsoft.Win32;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>Manages launch-at-sign-in via the per-user Run registry key.</summary>
public static class AutostartService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "ShareMyStatus";

    public static bool IsEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
            return key?.GetValue(ValueName) != null;
        }
        catch
        {
            return false;
        }
    }

    public static void SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
                            ?? Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (key == null)
                return;

            if (enabled)
            {
                var exePath = ExecutablePath();
                if (exePath != null)
                    key.SetValue(ValueName, $"\"{exePath}\" --autostart");
            }
            else
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
        }
        catch (Exception ex)
        {
            AppLogger.App.Error("Failed to update autostart setting", ex);
        }
    }

    private static string? ExecutablePath()
    {
        var path = Environment.ProcessPath;
        if (!string.IsNullOrEmpty(path))
            return path;
        try
        {
            return Process.GetCurrentProcess().MainModule?.FileName;
        }
        catch
        {
            return null;
        }
    }
}
