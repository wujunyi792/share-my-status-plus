using ShareMyStatusClient.Interop;
using ShareMyStatusClient.Models.Domain;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Collects battery, CPU and memory metrics via Win32. CPU is differential between
/// consecutive <see cref="Collect"/> calls (so call it on a steady cadence). All
/// percentages are returned as 0..1, matching the wire format.
/// </summary>
public sealed class SystemMonitorService
{
    private readonly AppLogger _logger = AppLogger.System;
    private (ulong idle, ulong kernel, ulong user)? _previousCpu;

    /// <summary>Reset the CPU baseline so the next sample starts a fresh interval.</summary>
    public void Reset() => _previousCpu = null;

    public SystemSnapshot Collect()
    {
        var (battery, charging) = GetBatteryInfo();
        var cpu = GetCpuUsage();
        var memory = GetMemoryUsage();

        return new SystemSnapshot(battery, charging, cpu, memory, DateTimeOffset.Now);
    }

    private (double? level, bool? charging) GetBatteryInfo()
    {
        if (!NativeMethods.GetSystemPowerStatus(out var status))
            return (null, null);

        const byte noBatteryFlag = 128;
        const byte unknown = 255;

        // Desktops report "no system battery" — leave both fields null like macOS.
        if ((status.BatteryFlag & noBatteryFlag) != 0)
            return (null, null);

        double? level = status.BatteryLifePercent == unknown
            ? null
            : Math.Clamp(status.BatteryLifePercent / 100.0, 0.0, 1.0);

        bool? charging = status.ACLineStatus == unknown
            ? null
            : status.ACLineStatus == 1; // plugged into AC

        return (level, charging);
    }

    private double? GetCpuUsage()
    {
        if (!NativeMethods.GetSystemTimes(out var idle, out var kernel, out var user))
            return null;

        var idleT = idle.ToUInt64();
        var kernelT = kernel.ToUInt64(); // kernel time already includes idle
        var userT = user.ToUInt64();

        var current = (idleT, kernelT, userT);
        if (_previousCpu is not { } prev)
        {
            _previousCpu = current;
            return null; // need two samples for a differential reading
        }

        _previousCpu = current;

        var dIdle = idleT - prev.idle;
        var dKernel = kernelT - prev.kernel;
        var dUser = userT - prev.user;

        var total = dKernel + dUser; // total busy+idle ticks in the interval
        if (total == 0)
            return null;

        var used = total - dIdle;
        return Math.Clamp((double)used / total, 0.0, 1.0);
    }

    private double? GetMemoryUsage()
    {
        var status = new NativeMethods.MEMORYSTATUSEX();
        if (!NativeMethods.GlobalMemoryStatusEx(status))
            return null;

        // dwMemoryLoad is the percentage of physical memory in use (0..100).
        return Math.Clamp(status.dwMemoryLoad / 100.0, 0.0, 1.0);
    }
}
